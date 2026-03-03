#!/bin/bash

# Parse command-line options
dry_run=false
list=false
package_option=""
projects_dir=""

while getopts "hnlp:C:" opt; do
  case $opt in
    h)
      cat <<EOF
Usage: $0 [OPTIONS] [REPO]

Build and bundle KDE packages from forked repository.

Options:
  -h, --help          Show this help message
  -n, --dry-run       Perform a dry run (no actual building/bundling)
  -l, --list          List all available forked repositories to compare version with upstream
  -p, --package NAME  Specify a single package to build (e.g., kwin) and skip the bundling step
  -C, --cwd PATH      Specify the projects' parent directory (default: current directory)

Forked repositories:
  libinput, kf6-kio, dolphin, aurorae, kscreenlocker, kwin,
  plasma-workspace, plasma-desktop, sddm

Examples:
  $0 -l                            # List all forked repositories
  $0 -p kwin                       # Build only kwin
  $0 -n -p dolphin                 # Dry run for dolphin
  $0 -C /path/to/projects          # Use custom projects directory
EOF
      exit 0
      ;;
    n)
      dry_run=true
      ;;
    l)
      list=true
      ;;
    p)
      package_option="$OPTARG"
      ;;
    C)
      projects_dir="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))

# Function to validate the package option
validate_package_option() {
  for package in $(jq -c '.[]' <<< "$PACKAGE_JSON"); do
    [ "$(jq -r '.name' <<< "$package")" = "$package_option" ] && return 0
  done

  return 1
}

# Function to get the projects' directory
get_projects_directory_option() {
  local input_dir="$projects_dir"

  if [ -z "$input_dir" ]; then
    read -rp "Enter the path to the projects' parent directory [default: $(pwd)]: " input_dir
  fi

  if [ -z "$input_dir" ]; then
    input_dir="$(pwd)"
  fi

  [ ! -d "$input_dir" ] && return 1

  input_dir=$([[ "$input_dir" = /* ]] && echo "$input_dir" || echo "$(pwd)/$input_dir")
  readlink -f "$input_dir"
}

# Function to build and install with make
build_and_install_with_make() {
  local project="$1"
  make -C "$CWD/$project/build/" -j"$(nproc)" >>"$CWD/build.$project.log" 2>&1 || return 1
  sudo make -C "$CWD/$project/build/" install DESTDIR="$CWD/dist/" >>"$CWD/build.$project.log" 2>&1 || return 1
}

# Function to build and install with ninja
build_and_install_with_ninja() {
  local project="$1"
  ninja -C "$CWD/$project/build/" -j"$(nproc)" >>"$CWD/build.$project.log" 2>&1 || return 1
  sudo env DESTDIR="$CWD/dist/" ninja -C "$CWD/$project/build/" install >>"$CWD/build.$project.log" 2>&1 || return 1
}

# Function to build and bundle with rpm
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

# Vet the projects directory option
projects_dir=$(get_projects_directory_option)
[[ ! $? ]] && { echo "❌ Invalid projects directory" >&2; exit 1; }
CWD="${projects_dir%/}"

# Vet the package option
PACKAGE_JSON=$(cat <<"EOF"
[
  { "name": "libinput",          "fork": "https://github.com/kdha200501/libinput.git"         },
  { "name": "kf6-kio",           "fork": "https://github.com/kdha200501/kio.git"              },
  { "name": "dolphin",           "fork": "https://github.com/kdha200501/dolphin.git"          },
  { "name": "aurorae",           "fork": "https://github.com/kdha200501/aurorae.git"          },
  { "name": "kscreenlocker",     "fork": "https://github.com/kdha200501/kscreenlocker.git"    },
  { "name": "kwin",              "fork": "https://github.com/kdha200501/kwin.git"             },
  { "name": "plasma-workspace",  "fork": "https://github.com/kdha200501/plasma-workspace.git" },
  { "name": "plasma-desktop",    "fork": "https://github.com/kdha200501/plasma-desktop.git"   },
  { "name": "sddm",              "fork": "https://github.com/kdha200501/sddm.git"             }
]
EOF
)
if [ -n "$package_option" ]; then
  validate_package_option
  [ $? -ne 0 ] && { echo "❌ Unknown repository '$package_option'" >&2; exit 1; }
fi

# Clean up previous build artifacts
FEDORA_VERSION=$(rpm -E %fedora)
TARBALL_NAME="dist-f$FEDORA_VERSION.tar.gz"
if [ "$list" = false ]; then
  [ -d "$CWD/dist" ] && sudo rm -rf "$CWD/dist"
  [ -f "$CWD/$TARBALL_NAME" ] && rm "$CWD/$TARBALL_NAME"
  [ -f "$CWD/sddm.rpm" ] && rm "$CWD/sddm.rpm"
fi

# Go through packages' fork
for package in $(jq -c '.[]' <<< "$PACKAGE_JSON"); do
  package_name=$(jq -r '.name' <<< "$package")

  if [ "$list" = false ] && [ -n "$package_option" ] && [ "$package_name" != "$package_option" ]; then
    continue
  fi

  printf "\n%s\n" "$package_name"

  package_fork=$(jq -r '.fork' <<< "$package")

  project=$(basename "$package_fork" .git)
  project_dir="$CWD/$project"

  # Clean up previous logs (if found)
  log_file="$CWD/build.$project.log"
  [ -f "$log_file" ] && rm "$log_file"

  # Get fork
  (
    # Clone the package's repository (if not found)
    if [ ! -d "$project_dir" ]; then
      git clone "$package_fork" "$project_dir" >>"$log_file" 2>&1 || {
        echo "❌ Failed to clone $project" >>"$log_file" 2>&1
        exit 1
      }
    fi

    # Validate the package's repository
    if [ ! -d "$project_dir/.git" ]; then
      echo "❌ $project_dir is not a git repository" >>"$log_file" 2>&1
      exit 1
    fi

    if [ "$(git -C "$project_dir" remote get-url --no-push origin 2>/dev/null)" != "$package_fork" ]; then
      echo "❌ Remote URL mismatch, expecting: $package_fork" >>"$log_file" 2>&1
      exit 1
    fi
  ) &

  get_fork_pid=$!

  tail -f --pid=$get_fork_pid -n 1 "$log_file" 2>/dev/null | while read -r line; do
    printf "\r\e[K📥 %s" "${line:0:(($COLUMNS - 3))}"
  done

  wait $get_fork_pid

  if [ $? -ne 0 ]; then
    printf "\r\e[K❌ Failed to get fork for $project, see log: $log_file\n"
    exit 1
  fi

  # Get fork version
  (
    # Fetch notes
    git -C "$project_dir" fetch origin "refs/notes/f$FEDORA_VERSION:refs/notes/f$FEDORA_VERSION" >>"$log_file" 2>&1 || {
      echo "❌ Failed to fetch notes for $project, see log at $log_file" >>"$log_file" 2>&1
      exit 1
    }

    # Fetch branches
    git -C "$project_dir" fetch --prune >>"$log_file" 2>&1 || {
      echo "❌ Failed to fetch branches for $project, see log at $log_file" >>"$log_file" 2>&1
      exit 1
    }

    # Determine branch from notes
    root_commit=$(git -C "$project_dir" rev-list --max-parents=0 origin/master 2>>"$log_file")
    if [ -z "$root_commit" ]; then
      echo "❌ Could not find root commit for $project" >>"$log_file" 2>&1
      exit 1
    fi

    branch=$(git -C "$project_dir" notes --ref "f$FEDORA_VERSION" show "$root_commit" 2>>"$log_file")
    if [ -z "$branch" ]; then
      echo "❌ Cannot find branch info for $project" >>"$log_file" 2>&1
      exit 1
    fi

    # Checkout branch
    git -C "$project_dir" checkout "$branch" >>"$log_file" 2>&1 || {
      echo "❌ Failed to checkout branch for $project" >>"$log_file" 2>&1
      exit 1
    }

    git -C "$project_dir" reset --hard "origin/$branch" >>"$log_file" 2>&1 || {
      echo "❌ Failed to reset branch for $project" >>"$log_file" 2>&1
      exit 1
    }
  ) &

  get_fork_version_pid=$!

  tail -f --pid=$get_fork_version_pid -n 1 "$log_file" 2>/dev/null | while read -r line; do
    printf "\r\e[K📥 %s" "${line:0:(($COLUMNS - 3))}"
  done

  wait $get_fork_version_pid

  if [ $? -ne 0 ]; then
    printf "\r\e[K❌ Failed to get fork version for $project, see log: $log_file\n"
    exit 1
  else
    printf "\r\e[K🏷 %s\n" $(git -C "$project_dir" branch --show-current 2>/dev/null)
  fi

  if [ "$list" = true ]; then
    package_tag=$(dnf --releasever=$FEDORA_VERSION repoquery --queryformat="%{VERSION}" --latest-limit=1 "$package_name" 2>/dev/null)
    echo "📦 $package_tag"
    continue
  fi

  # The build process
  (
    # Build project from source, install build artifacts into dist folder
    case "$project" in
      aurorae|dolphin|kio|kwin|plasma-workspace|plasma-desktop)
        dnf --refresh builddep -y "$package_name" >>"$log_file" 2>&1 || {
          echo "❌ dnf builddep error, see log at $log_file" >>"$log_file" 2>&1
          exit 1
        }

        cmake -DCMAKE_INSTALL_PREFIX="/usr" -DBUILD_TESTING=OFF -B "$project_dir/build/" -S "$project_dir/" >>"$log_file" 2>&1 || {
          echo "❌ cmake error, see log at $log_file" >>"$log_file" 2>&1
          exit 1
        }

        if [ "$dry_run" = false ]; then
          build_and_install_with_make "$project" || {
            echo "❌ make error, see log at $log_file" >>"$log_file" 2>&1
            exit 1
          }
        fi
        ;;
      kscreenlocker)
        dnf --refresh builddep -y "$package_name" >>"$log_file" 2>&1 || {
          echo "❌ dnf builddep error, see log at $log_file" >>"$log_file" 2>&1
          exit 1
        }

        cmake -DCMAKE_INSTALL_PREFIX="/usr" -DBUILD_TESTING=OFF -DKDE_INSTALL_LIBEXECDIR=libexec -B "$project_dir/build/" -S "$project_dir/" >>"$log_file" 2>&1 || {
          echo "❌ cmake error, see log at $log_file" >>"$log_file" 2>&1
          exit 1
        }

        if [ "$dry_run" = false ]; then
          build_and_install_with_make "$project" || {
            echo "❌ make error, see log at $log_file" >>"$log_file" 2>&1
            exit 1
          }
        fi
        ;;
      libinput)
        dnf --refresh builddep -y "$package_name" >>"$log_file" 2>&1 || {
          echo "❌ dnf builddep error, see log at $log_file" >>"$log_file" 2>&1
          exit 1
        }

        meson setup --prefix="/usr" -Dversion="$branch" "$project_dir/build/" "$project_dir/" >>"$log_file" 2>&1 || {
          echo "❌ meson error, see log at $log_file" >>"$log_file" 2>&1
          exit 1
        }

        if [ "$dry_run" = false ]; then
          build_and_install_with_ninja "$project" || {
            echo "❌ ninja error, see log at $log_file" >>"$log_file" 2>&1
            exit 1
          }
        fi
        ;;
      sddm)
        dnf --refresh builddep -y "$package_name" >>"$log_file" 2>&1 || {
          echo "❌ dnf builddep error, see log at $log_file" >>"$log_file" 2>&1
          exit 1
        }

        if [[ ! -f "$project_dir/sddm.spec" ]]; then
          echo "❌ Spec file not found: $project_dir/sddm.spec" >>"$log_file" 2>&1
          exit 1
        fi

        if [ "$dry_run" = false ]; then
          build_and_bundle_with_rpm "$project" "sddm.spec" || exit 1
        fi
        ;;
      *)
        echo "❌ No build instructions for $project" >>"$log_file" 2>&1
        exit 1
        ;;
    esac
  ) &

  build_pid=$!

  tail -f --pid=$build_pid -n 1 "$log_file" 2>/dev/null | while read -r line; do
    printf "\r\e[K🚀 %s" "${line:0:(($COLUMNS - 3))}"
  done

  wait $build_pid

  if [ $? -ne 0 ]; then
    printf "\r\e[K%s\n" "❌ build log: $log_file"
    # Ensure the build is atomic
    exit 1
  fi

  if [ "$dry_run" = true ]; then
    printf "\r\e[K%s\n" "🔍 Dry run is successful, build log: $log_file"
    continue
  fi

  printf "\r\e[K%s\n" "✅ Build is successful, build log: $log_file"
done

[ "$list" = true ] || [ -n "$package_option" ] || [ "$dry_run" = true ] && exit

# Bundle up the dist directory into a tarball
if [[ -d "$CWD/dist/" ]]; then
  echo "Bundling up installation files"
  tar -cvzf "$CWD/$TARBALL_NAME" -C "$CWD/dist/" . 2>&1 | while read -r line; do
    printf "\r\e[K📦 %s" "${line:0:(($COLUMNS - 3))}"
  done

  TAR_EXIT_STATUS=${PIPESTATUS[0]}

  [[ $TAR_EXIT_STATUS -eq 0 ]] && printf "\r\e[K💾 $CWD/$TARBALL_NAME\n" || printf "\r\e[K❌ (Exit code: $TAR_EXIT_STATUS)\n"
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
