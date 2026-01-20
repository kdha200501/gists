#!/bin/bash

build_and_install_with_make() {
  local project="$1"
  make -C "$CWD/$project/build/" -j"$(nproc)" >>"$CWD/build.$project.log" 2>&1 || return 1
  sudo make -C "$CWD/$project/build/" install DESTDIR="$CWD/dist/" >>"$CWD/build.$project.log" 2>&1 || return 1
}

build_and_install_with_ninja() {
  local project="$1"
  ninja -C "$CWD/$project/build/" -j"$(nproc)" >>"$CWD/build.$project.log" 2>&1 || return 1
  sudo env DESTDIR="$CWD/dist/" ninja -C "$CWD/$project/build/" install >>"$CWD/build.$project.log" 2>&1 || return 1
}

build_and_bundle_with_rpm() {
  local project="$1"
  local spec_filename="$2"

  # scaffold a RPM working directory
  local tmp_dir="$CWD/$project/rpmdev-tmp"
  [ -d "$tmp_dir" ] && rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir"
  env HOME="$tmp_dir" rpmdev-setuptree >>"$CWD/build.$project.log" 2>&1 || return 1

  # copy spec to the RPM working directory
  local spec_file="$CWD/$project/$spec_filename"
  cp "$spec_file" "$tmp_dir/rpmbuild/SPECS/" >>"$CWD/build.$project.log" 2>&1 || return 1

  # copy patch and source to the RPM working directory
  spectool -C "$tmp_dir/rpmbuild/SOURCES/" -g "$spec_file" >>"$CWD/build.$project.log" 2>&1 || return 1
  spectool --list-files --all "$spec_file" | awk '{print $2}' | while read -r file; do
    [[ "$file" != http* && -f "$CWD/$project/$file" ]] && cp "$CWD/$project/$file" "$tmp_dir/rpmbuild/SOURCES/" >>"$CWD/build.$project.log" 2>&1
  done

  # apply patch, compile source and bundle rpm
  env HOME="$tmp_dir" rpmbuild -bb "$spec_file" >>"$CWD/build.$project.log" 2>&1 || return 1
}


# Accept projects directory path as first argument
if [ -n "$1" ]; then
  # Check if it's an absolute path
  if [[ "$1" = /* ]]; then
    CWD="$1"
  else
    CWD="$(pwd)/$1"
  fi
else
  read -rp "Enter the path to the projects' directory [default: $(pwd)]: " input_dir
  CWD="${input_dir:-$(pwd)}"
fi

# The projects directory path
CWD="${CWD%/}"

# Validate input
if [ ! -d "$CWD" ]; then
  echo "Error: Directory '$CWD' does not exist."
  exit 1
fi

# Clean up previous artifacts
[ -d "$CWD/dist" ] && sudo rm -rf "$CWD/dist"
[ -f "$CWD/dist.tar" ] && rm "$CWD/dist.tar"
[ -f "$CWD/sddm.rpm" ] && rm "$CWD/sddm.rpm"

# List of projects to build
projects=(libinput kio dolphin aurorae kscreenlocker kwin plasma-workspace plasma-desktop sddm)

for project in "${projects[@]}"; do
  echo "$project"

  # Clean up previous logs
  [ -f "$CWD/build.$project.log" ] && rm "$CWD/build.$project.log"

  (
    if [[ ! -d "$CWD/$project" ]]; then
      echo "❌ Project directory not found: $CWD/$project"
      exit 1
    fi

    # Fetch notes and branches
    git -C "$CWD/$project" fetch origin refs/notes/commits:refs/notes/commits >>"$CWD/build.$project.log" 2>&1
    git -C "$CWD/$project" fetch --prune >>"$CWD/build.$project.log" 2>&1

    # Determine branch from notes
    root_commit=$(git -C "$CWD/$project" rev-list --max-parents=0 origin/master 2>>"$CWD/build.$project.log")
    if [ -z "$root_commit" ]; then
      echo "❌ Skipping $project: could not find root commit."
      exit 1
    fi

    branch=$(git -C "$CWD/$project" notes show "$root_commit" 2>>"$CWD/build.$project.log")
    if [ -z "$branch" ]; then
      echo "❌ Skipping $project: no branch info in notes."
      exit 1
    fi

    # Checkout branch
    git -C "$CWD/$project" checkout "$branch" >>"$CWD/build.$project.log" 2>&1 || {
      echo "❌ Skipping $project: failed to checkout branch '$branch'."
      exit 1
    }

    git -C "$CWD/$project" reset --hard "origin/$branch" >>"$CWD/build.$project.log" 2>&1

    # Build project from source, install build artifacts into dist folder
    case "$project" in
      aurorae|dolphin|kio|kwin|plasma-workspace|plasma-desktop)
        cmake -DCMAKE_INSTALL_PREFIX="/usr" -DBUILD_TESTING=OFF -B "$CWD/$project/build/" -S "$CWD/$project/" >>"$CWD/build.$project.log" 2>&1 || {
          echo "❌ cmake error, see log at $CWD/build.$project.log"
          exit 1
        }
        build_and_install_with_make "$project" || {
          echo "❌ make error, see log at $CWD/build.$project.log"
          exit 1
        }
        ;;
      kscreenlocker)
        cmake -DCMAKE_INSTALL_PREFIX="/usr" -DBUILD_TESTING=OFF -DKDE_INSTALL_LIBEXECDIR=libexec -B "$CWD/$project/build/" -S "$CWD/$project/" >>"$CWD/build.$project.log" 2>&1 || {
          echo "❌ cmake error, see log at $CWD/build.$project.log"
          exit 1
        }
        build_and_install_with_make "$project" || {
          echo "❌ make error, see log at $CWD/build.$project.log"
          exit 1
        }
        ;;
      libinput)
        meson setup --prefix="/usr" -Dversion="$branch" "$CWD/$project/build/" "$CWD/$project/" >>"$CWD/build.$project.log" 2>&1 || {
          echo "❌ meson error, see log at $CWD/build.$project.log"
          exit 1
        }
        build_and_install_with_ninja "$project" || {
          echo "❌ ninja error, see log at $CWD/build.$project.log"
          exit 1
        }
        ;;
      sddm)
        if [[ ! -f "$CWD/$project/sddm.spec" ]]; then
          echo "❌ Spec file not found: $CWD/$project/sddm.spec"
          exit 1
        fi

        build_and_bundle_with_rpm "$project" "sddm.spec" || exit 1
        ;;
      *)
        echo "❌ No build instructions for $project. Skipping."
        ;;
    esac
  ) &

  JOB_PID=$!

  tail -f --pid=$JOB_PID -n 1 "$CWD/build.$project.log" 2>/dev/null | while read -r line; do
    printf "\r\e[K🚀 %s" "${line:0:(($COLUMNS - 3))}"
  done

  wait $JOB_PID

  if [ $? -ne 0 ]; then
    printf "\r\e[K%s\n" "❌ build log: $CWD/build.$project.log"
    continue
  fi

  printf "\r\e[K%s\n" "✅ build log: $CWD/build.$project.log"
done

# Bundle up the dist directory into a tarball
if [[ -d "$CWD/dist/" ]]; then
  echo "Bundling up installation files"
  tar -cvzf "$CWD/dist.tar.gz" -C "$CWD/dist/" . 2>&1 | while read -r line; do
    printf "\r\e[K📦 %s" "${line:0:(($COLUMNS - 3))}"
  done

  TAR_EXIT_STATUS=${PIPESTATUS[0]}

  [[ $TAR_EXIT_STATUS -eq 0 ]] && printf "\r\e[K💾 $CWD/dist.tar.gz\n" || printf "\r\e[K❌ (Exit code: $TAR_EXIT_STATUS)\n"
else
  echo "❌ dist folder not found: $CWD/dist/"
fi

# Move rpm files to the CWD
sddm_project="$CWD/sddm"
sddm_x86_64_rpm="$(find "$sddm_project" -type f -name '*x86_64.rpm' | head -n 1)"
if [[ -n "$sddm_x86_64_rpm" && -f "$sddm_x86_64_rpm" ]]; then
  echo "Moving $sddm_x86_64_rpm"
  mv "$sddm_x86_64_rpm" "$sddm_project".rpm

  MV_EXIT_STATUS=$?

  [[ $MV_EXIT_STATUS -eq 0 ]] && echo "💾 $sddm_project.rpm" || echo "❌ (Exit code: $MV_EXIT_STATUS)"
else
  echo "❌ RPM not found under $sddm_project"
fi
