#!/bin/bash

dry_run=false
list=false
repo=""

# Repository URLs
REPOS_JSON='["https://github.com/kdha200501/libinput.git","https://github.com/kdha200501/kio.git","https://github.com/kdha200501/dolphin.git","https://github.com/kdha200501/aurorae.git","https://github.com/kdha200501/kscreenlocker.git","https://github.com/kdha200501/kwin.git","https://github.com/kdha200501/plasma-workspace.git","https://github.com/kdha200501/plasma-desktop.git","https://github.com/kdha200501/sddm.git"]'

# Parse command-line options
while getopts "nlr:" opt; do
  case $opt in
    n)
      dry_run=true
      ;;
    l)
      list=true
      ;;
    r)
      repo="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))

# Validate repo option
validate_repo() {
  for url in $(jq -r '.[]' <<< "$REPOS_JSON"); do
    if [ "$url" = "$repo" ]; then
      return 0
    fi
  done
  return 1
}

get_project_directory() {
  local input_dir

  if [ -z "$1" ]; then
    read -rp "Enter the path to the projects' parent directory [default: $(pwd)]: " input_dir
  else
    input_dir="$1"
  fi

  if [ -n "$input_dir" ] && [ ! -d "$input_dir" ]; then
    echo "❌ Directory '$input_dir' does not exist" >&2
    return 1
  fi

  input_dir=$([[ "$input_dir" = /* ]] && echo "$input_dir" || echo "$(pwd)/$input_dir")
  readlink -f "$input_dir"
}

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

# List repositories and exit
if [ "$list" = true ]; then
  jq -r '.[]' <<< "$REPOS_JSON"
  exit 0
fi

if [[ -n "$repo" && ! $(validate_repo) ]]; then
  echo "❌ Repository '$repo' is not in REPOS_JSON" >&2
  exit 1
fi

# The projects directory path
CWD=$(get_project_directory "$1") || exit 1
CWD="${CWD%/}"

# Clean up previous build artifacts
[ -d "$CWD/dist" ] && sudo rm -rf "$CWD/dist"
[ -f "$CWD/dist.tar" ] && rm "$CWD/dist.tar"
[ -f "$CWD/sddm.rpm" ] && rm "$CWD/sddm.rpm"

# Projects to build
for url in $(jq -r '.[]' <<< "$REPOS_JSON"); do
  if [ -n "$repo" ] && [ "$url" != "$repo" ]; then
    continue
  fi

  project=$(basename "$url" .git)
  printf "\n%s\n" "$project"

  # Clone project (if not found)
  if [ ! -d "$CWD/$project" ]; then
    git clone "$url" "$CWD/$project" 2>&1 | while read -r line; do
      printf "\r\e[K📥 %s" "${line:0:(($COLUMNS - 3))}"
    done

    GIT_EXIT_STATUS=${PIPESTATUS[0]}

    [[ $GIT_EXIT_STATUS -ne 0 ]] && { printf "\r\e[K❌ Failed to clone $project (Exit code: $GIT_EXIT_STATUS)\n"; exit 1; } || printf "\r\e[K"
  fi

  # Validate project
  if [ ! -d "$CWD/$project/.git" ]; then
    echo "❌ $CWD/$project is not a git repository"
    exit 1
  fi

  if [ "$(git -C "$CWD/$project" remote get-url origin 2>/dev/null)" != "$url" ]; then
    echo "❌ Remote URL mismatch, expecting: $url"
    exit 1
  fi

  # Clean up previous logs (if found)
  [ -f "$CWD/build.$project.log" ] && rm "$CWD/build.$project.log"


  # Get branch
  (
    # Fetch notes
    git -C "$CWD/$project" fetch origin refs/notes/commits:refs/notes/commits >>"$CWD/build.$project.log" 2>&1 || {
      echo "❌ Failed to fetch notes for $project, see log at $CWD/build.$project.log"
      exit 1
    }

    # Fetch branches
    git -C "$CWD/$project" fetch --prune >>"$CWD/build.$project.log" 2>&1 || {
      echo "❌ Failed to fetch branches for $project, see log at $CWD/build.$project.log"
      exit 1
    }

    # Determine branch from notes
    root_commit=$(git -C "$CWD/$project" rev-list --max-parents=0 origin/master 2>>"$CWD/build.$project.log")
    if [ -z "$root_commit" ]; then
      echo "❌ Could not find root commit for $project"
      exit 1
    fi

    branch=$(git -C "$CWD/$project" notes show "$root_commit" 2>>"$CWD/build.$project.log")
    if [ -z "$branch" ]; then
      echo "❌ Cannot find branch info for $project"
      exit 1
    fi

    # Checkout branch
    git -C "$CWD/$project" checkout "$branch" >>"$CWD/build.$project.log" 2>&1 || {
      echo "❌ Failed to checkout branch for $project"
      exit 1
    }

    git -C "$CWD/$project" reset --hard "origin/$branch" >>"$CWD/build.$project.log" 2>&1 || {
      echo "❌ Failed to reset branch for $project"
      exit 1
    }
  ) &

  JOB_PID=$!

  tail -f --pid=$JOB_PID -n 1 "$CWD/build.$project.log" 2>/dev/null | while read -r line; do
    printf "\r\e[K📥 %s" "${line:0:(($COLUMNS - 3))}"
  done

  wait $JOB_PID

  if [ $? -ne 0 ]; then
    printf "\r\e[K%s\n" "❌ build log: $CWD/build.$project.log"
    exit 1
  fi

  printf "\r\e[K🏷 %s\n" $(git -C "$CWD/$project" branch --show-current 2>/dev/null)

  # The build process
  (
    # Build project from source, install build artifacts into dist folder
    case "$project" in
      aurorae|dolphin|kio|kwin|plasma-workspace|plasma-desktop)
        cmake -DCMAKE_INSTALL_PREFIX="/usr" -DBUILD_TESTING=OFF -B "$CWD/$project/build/" -S "$CWD/$project/" >>"$CWD/build.$project.log" 2>&1 || {
          echo "❌ cmake error, see log at $CWD/build.$project.log"
          exit 1
        }

        if [ "$dry_run" = false ]; then
          build_and_install_with_make "$project" || {
            echo "❌ make error, see log at $CWD/build.$project.log"
            exit 1
          }
        fi
        ;;
      kscreenlocker)
        cmake -DCMAKE_INSTALL_PREFIX="/usr" -DBUILD_TESTING=OFF -DKDE_INSTALL_LIBEXECDIR=libexec -B "$CWD/$project/build/" -S "$CWD/$project/" >>"$CWD/build.$project.log" 2>&1 || {
          echo "❌ cmake error, see log at $CWD/build.$project.log"
          exit 1
        }

        if [ "$dry_run" = false ]; then
          build_and_install_with_make "$project" || {
            echo "❌ make error, see log at $CWD/build.$project.log"
            exit 1
          }
        fi
        ;;
      libinput)
        meson setup --prefix="/usr" -Dversion="$branch" "$CWD/$project/build/" "$CWD/$project/" >>"$CWD/build.$project.log" 2>&1 || {
          echo "❌ meson error, see log at $CWD/build.$project.log"
          exit 1
        }

        if [ "$dry_run" = false ]; then
          build_and_install_with_ninja "$project" || {
            echo "❌ ninja error, see log at $CWD/build.$project.log"
            exit 1
          }
        fi
        ;;
      sddm)
        if [[ ! -f "$CWD/$project/sddm.spec" ]]; then
          echo "❌ Spec file not found: $CWD/$project/sddm.spec"
          exit 1
        fi

        if [ "$dry_run" = false ]; then
          build_and_bundle_with_rpm "$project" "sddm.spec" || exit 1
        fi
        ;;
      *)
        echo "❌ No build instructions for $project"
        exit 1
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
    # Ensure the build is atomic
    exit 1
  fi

  if [ "$dry_run" = true ]; then
    printf "\r\e[K%s\n" "🔍 Dry run is successful, build log: $CWD/build.$project.log"
    continue
  fi

  printf "\r\e[K%s\n" "✅ Build is successful, build log: $CWD/build.$project.log"
done

[ -n "$repo" ] || [ "$dry_run" = true ] && exit

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
