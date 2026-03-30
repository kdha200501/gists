#!/bin/bash

# Parse command-line options
dry_run=false
list=false
package_option=""
projects_dir=""

while getopts "hn:lp:C:" opt; do
  case $opt in
    h)
      cat <<EOF
Usage: $0 [OPTIONS] [REPO]

Build and bundle KDE packages from forked repository.

Options:
  -h, --help          Show this help message
  -n, --dry-run MODE  Perform a dry run
                       'no-compile': skips compilation, skips preparation for bundling
                       'no-bundle': compiles, skips preparation for bundling
  -l, --list          List all available forked repositories to compare version with upstream
  -p, --package NAME  Specify a single package to build
  -C, --cwd PATH      Specify the projects' parent directory (default: current directory)

Forked repositories:
  libinput, kf6-kio, dolphin, aurorae, kscreenlocker, kwin, kdeplasma-addons,
  plasma-workspace, plasma-desktop, plasma-login-manager

Examples:
  $0 -l                            # List all forked repositories
  $0 -p kwin                       # Build only kwin
  $0 -n no-compile -p dolphin      # Dry run for dolphin (cmake, skip make, skip make install)
  $0 -n no-bundle -p dolphin       # Dry run for dolphin (cmake, make, skip make install)
  $0 -C /path/to/projects          # Use custom projects directory
EOF
      exit 0
      ;;
    n)
      if [[ ! "$OPTARG" =~ ^(no-compile|no-bundle)$ ]]; then
        echo "❌ Invalid dry-run option. Must be 'no-compile' or 'no-bundle'." >&2
        exit 1
      fi
      dry_run="$OPTARG"
      ;;
    l)
      list=true
      ;;
    p)
      if [[ -z "$OPTARG" || "$OPTARG" == -* ]]; then
        echo "❌ Invalid project." >&2
        exit 1
      fi
      package_option="$OPTARG"
      ;;
    C)
      if [[ -z "$OPTARG" || "$OPTARG" == -* ]]; then
        echo "❌ Invalid projects directory." >&2
        exit 1
      fi
      projects_dir="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Function to validate the package option
validate_package_option() {
  local package_option="$1"

  # if the package option is not specified
  if [ -z "$package_option" ]; then
    # then consider it a valid use case
    return 0
  fi

  # if the package option is specified, and
  # if the package option matches to a fork,
  # then consider it a valid use case
  for package in $(jq -c '.[]' <<< "$PACKAGE_JSON"); do
    [ "$(jq -r '.name' <<< "$package")" = "$package_option" ] && return 0
  done

  # if the package option is specified, and
  # if the package option does not match to a fork,
  # then consider it an invalid use case
  return 1
}

# Function to get the projects' directory
get_projects_directory_option() {
  local input_dir="$1"

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

# Function to check if the a package should be skipped
skip_package() {
  local list="$1"
  local package_option="$2"
  local package_name="$3"

  # if the intent is to list package forks
  if [ "$list" = true ]; then
    # then process the fork
    return 0
  fi

  # if the intent is not to list package forks, and
  # if the package option is not used
  if [ -z "$package_option" ]; then
    # then process the fork
    return 0
  fi

  # if the intent is not to list package forks, and
  # if the package option is used,
  # then respect the package option
  [ "$package_name" = "$package_option" ]
}

# Function to check if bundling should be performed
perform_bundle() {
  local dry_run="$1"

  # if the intent is to list forks
  if [ "$list" != false ]; then
    # then do not perform bundling
    return 1
  fi

  # if the intent is not to list forks, and
  # if the intent is to dry-run
  if [ "$dry_run" != false ]; then
    # then do not perform bundling
    return 1
  fi

  # if the intent is not to list forks, and
  # if the intent is not to dry-run, then
  # then perform bundling
  return 0
}

# Function to check if installation should be performed
perform_install() {
  local dry_run="$1"

  # if the intent is to perform a full build
  if perform_bundle "$dry_run"; then
    # then prepare for bundling
    return 0
  fi

  # if the intent is to dry-run, and
  # if the dry-run is to skip preparation for bundling
  if [ "$dry_run" = "no-bundle" ]; then
    # then skip preparation for bundling
    return 1
  fi

  return 1
}

# Function to check if compilation should be performed
perform_compile() {
  local dry_run="$1"

  # if the intent is to perform a full build
  if perform_bundle "$dry_run"; then
    # then perform compile
    return 0
  fi

  # if the intent is to dry-run, and
  # if the dry-run is to skip preparation for bundling
  if [ "$dry_run" = "no-bundle" ]; then
    # then perform compile
    return 0
  fi

  # if the intent is to dry-run, and
  # if the dry-run is to skip compile
  if [ "$dry_run" = "no-compile" ]; then
    # then skip compile
    return 1
  fi

  return 1
}

# Vet the projects directory option
projects_dir=$(get_projects_directory_option "$projects_dir")
[[ $? -ne 0 ]] && { echo "❌ Invalid projects directory" >&2; exit 1; }
CWD="${projects_dir%/}"

# Vet the package option
PACKAGE_JSON=$(cat <<"EOF"
[
  { "name": "plasma-login-manager", "fork": "https://github.com/kdha200501/plasma-login-manager.git", "type": "rpm" },
  { "name": "libinput",             "fork": "https://github.com/kdha200501/libinput.git",             "type": "tarball" },
  { "name": "kf6-kio",              "fork": "https://github.com/kdha200501/kio.git",                  "type": "tarball" },
  { "name": "dolphin",              "fork": "https://github.com/kdha200501/dolphin.git",              "type": "tarball" },
  { "name": "aurorae",              "fork": "https://github.com/kdha200501/aurorae.git",              "type": "tarball" },
  { "name": "kscreenlocker",        "fork": "https://github.com/kdha200501/kscreenlocker.git",        "type": "tarball" },
  { "name": "kwin",                 "fork": "https://github.com/kdha200501/kwin.git",                 "type": "tarball" },
  { "name": "kdeplasma-addons",     "fork": "https://github.com/kdha200501/kdeplasma-addons.git",     "type": "tarball" },
  { "name": "plasma-workspace",     "fork": "https://github.com/kdha200501/plasma-workspace.git",     "type": "tarball" },
  { "name": "plasma-desktop",       "fork": "https://github.com/kdha200501/plasma-desktop.git",       "type": "tarball" }
]
EOF
)
validate_package_option "$package_option" || { echo "❌ Unknown repository '$package_option'" >&2; exit 1; }

# Initialize output
perform_bundle "$dry_run" && find "$CWD" -maxdepth 1 -type f \( -name '*.tar' -o -name '*x86_64.rpm' \) -delete

# Go through package forks
for package in $(jq -c '.[]' <<< "$PACKAGE_JSON"); do
  package_name=$(jq -r '.name' <<< "$package")

  skip_package "$list" "$package_option" "$package_name" || continue

  printf "\n\033[1m%s\033[0m\n" "$package_name"

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

  FEDORA_VERSION=$(rpm -E %fedora)

  # Get fork version
  (
    # Fetch notes
    git -C "$project_dir" fetch origin "+refs/notes/f$FEDORA_VERSION:refs/notes/f$FEDORA_VERSION" >>"$log_file" 2>&1 || {
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
    printf "\r\e[K🏷  %s\n" $(git -C "$project_dir" branch --show-current 2>/dev/null)
  fi

  if [ "$list" = true ]; then
    package_tag=$(sudo dnf --releasever=$FEDORA_VERSION repoquery --queryformat="%{VERSION}" --latest-limit=1 "$package_name" 2>/dev/null)
    echo "📦 $package_tag"
    continue
  fi

  # The build process
  (
    dist_dir="$CWD/dist"

    # Build project from source, install build artifacts into dist folder
    case "$project" in
      libinput)
        sudo dnf --refresh builddep -y "$package_name" >>"$log_file" 2>&1 || {
          echo "❌ dnf builddep error, see log at $log_file" >>"$log_file" 2>&1
          exit 1
        }

        meson setup "$project_dir/build/" "$project_dir/" --prefix=/usr --buildtype=release -Dlibdir=lib64 -Dtests=false -Ddocumentation=false -Ddebug-gui=false >>"$log_file" 2>&1 || {
          echo "❌ meson error, see log at $log_file" >>"$log_file" 2>&1
          exit 1
        }

        perform_compile "$dry_run" && {
          ninja -C "$project_dir/build/" -j"$(nproc)" >>"$log_file" 2>&1 || {
            echo "❌ ninja error, see log at $log_file" >>"$log_file" 2>&1
            exit 1
          }
        }

        perform_install "$dry_run" && {
          [ -d "$dist_dir" ] && sudo rm -rf "$dist_dir"
          sudo env DESTDIR="$dist_dir/" ninja -C "$project_dir/build/" install >>"$log_file" 2>&1 || {
            echo "❌ ninja install error, see log at $log_file" >>"$log_file" 2>&1
            exit 1
          }
        }
        ;;
      aurorae|dolphin|kio|kwin|kdeplasma-addons|plasma-workspace|plasma-desktop|kscreenlocker)
        sudo dnf --refresh builddep -y "$package_name" >>"$log_file" 2>&1 || {
          echo "❌ dnf builddep error, see log at $log_file" >>"$log_file" 2>&1
          exit 1
        }

        cmake -B "$project_dir/build/" -S "$project_dir/" -DCMAKE_INSTALL_PREFIX="/usr" -DCMAKE_BUILD_TYPE="Release" -DBUILD_TESTING=OFF -DKDE_INSTALL_USE_QT_SYS_PATHS=ON -DCMAKE_INSTALL_LIBDIR=lib64 -DQT_MAJOR_VERSION=6 -DKDE_INSTALL_SYSCONFDIR=/etc -DKDE_INSTALL_LOCALSTATEDIR=/var -DKDE_INSTALL_LIBEXECDIR=libexec -DPAM_OS_CONFIGURATION="fedora" >>"$log_file" 2>&1 || {
          echo "❌ cmake error, see log at $log_file" >>"$log_file" 2>&1
          exit 1
        }

        perform_compile "$dry_run" && {
          make -C "$project_dir/build/" -j"$(nproc)" >>"$log_file" 2>&1 || {
            echo "❌ make error, see log at $log_file" >>"$log_file" 2>&1
            exit 1
          }
        }

        perform_install "$dry_run" && {
          [ -d "$dist_dir" ] && sudo rm -rf "$dist_dir"
          sudo make -C "$project_dir/build/" install DESTDIR="$dist_dir/" >>"$log_file" 2>&1 || {
            echo "❌ make install error, see log at $log_file" >>"$log_file" 2>&1
            exit 1
          }
        }
        ;;
      plasma-login-manager)
        sudo dnf --refresh builddep -y "$package_name" >>"$log_file" 2>&1 || {
          echo "❌ dnf builddep error, see log at $log_file" >>"$log_file" 2>&1
          exit 1
        }

        if [[ ! -f "$project_dir/$project.spec" ]]; then
          echo "❌ Spec file not found: $project_dir/$project.spec" >>"$log_file" 2>&1
          exit 1
        fi

        # scaffold a RPM working directory
        [ -d "$dist_dir" ] && sudo rm -rf "$dist_dir"
        mkdir -p "$dist_dir"
        env HOME="$dist_dir" rpmdev-setuptree >>"$log_file" 2>&1 || exit 1

        # copy spec to the RPM working directory
        cp "$project_dir/$project.spec" "$dist_dir/rpmbuild/SPECS/" >>"$log_file" 2>&1 || exit 1

        # copy patch and source to the RPM working directory
        spectool -C "$dist_dir/rpmbuild/SOURCES/" -g "$project_dir/$project.spec" >>"$log_file" 2>&1 || exit 1
        spectool --list-files --all "$project_dir/$project.spec" | awk '{print $2}' | while read -r file; do
          [[ "$file" != http* && -f "$project_dir/$file" ]] && cp "$project_dir/$file" "$dist_dir/rpmbuild/SOURCES/" >>"$log_file" 2>&1
        done

        [ "$dry_run" = "no-bundle" ] && {
          env HOME="$dist_dir" rpmbuild -bc "$project_dir/$project.spec" >>"$log_file" 2>&1 || {
            echo "❌ rpmbuild error, see log at $log_file" >>"$log_file" 2>&1
            exit 1
          }
        }
        ;;
      *)
        echo "❌ No build instructions for $project" >>"$log_file" 2>&1
        exit 1
        ;;
    esac

    # Bundle build artifacts into package
    package_type=$(jq -r '.type' <<< "$package")

    if perform_bundle "$dry_run"; then
      case "$package_type" in
        tarball)
          TARBALL_NAME="dist-f$FEDORA_VERSION.tar"
          [ -f "$CWD/$TARBALL_NAME" ] || tar -cf "$CWD/$TARBALL_NAME" --files-from=/dev/null
          tar -rvf "$CWD/$TARBALL_NAME" -C "$dist_dir/" . >>"$log_file" 2>&1

          [ $? -ne 0 ] && {
            echo "❌ tar error, see log at $log_file" >>"$log_file" 2>&1
            exit 1
          }

          if [[ -n "$package_option" ]]; then
            echo "Renaming to $CWD/$package_option-f$FEDORA_VERSION.tar" >>"$log_file" 2>&1
            mv -v "$CWD/$TARBALL_NAME" "$CWD/$package_option-f$FEDORA_VERSION.tar" >>"$log_file" 2>&1
            printf "\r\e[K%s\n" "💾 $CWD/$package_option-f$FEDORA_VERSION.tar"
          else
            printf "\r\e[K%s\n" "💾 $CWD/$TARBALL_NAME"
          fi
          ;;
        rpm)
          env HOME="$dist_dir" rpmbuild -bb "$project_dir/$project.spec" >>"$log_file" 2>&1 || {
            echo "❌ rpmbuild error, see log at $log_file" >>"$log_file" 2>&1
            exit 1
          }

          # Move rpm files to the CWD
          rpm_files=($(find "$dist_dir" -type f -name '*x86_64.rpm'))

          if [[ ${#rpm_files[@]} -eq 0 ]]; then
            echo "❌ RPM not found under $dist_dir" >>"$log_file" 2>&1
            exit 1
          fi

          for rpm_file in "${rpm_files[@]}"; do
            echo "Moving to $CWD/$(basename "$rpm_file")" >>"$log_file" 2>&1
            mv -v "$rpm_file" "$CWD/" >>"$log_file" 2>&1
            [ $? -ne 0 ] && {
              echo "❌ rpmbuild error, see log at $log_file" >>"$log_file" 2>&1
              exit 1
            }
            printf "\r\e[K%s\n" "💾 $CWD/$(basename "$rpm_file")"
            printf "\r\e[K%s\n" "📌 sudo dnf reinstall \"$CWD/$(basename "$rpm_file")\""
          done
          ;;
      esac
    fi
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

  if ! perform_bundle "$dry_run"; then
    printf "\r\e[K%s\n" "🔍 Dry run is successful, build log: $log_file"
    continue
  fi

  printf "\r\e[K%s\n" "✅ Build is successful, build log: $log_file"
done
