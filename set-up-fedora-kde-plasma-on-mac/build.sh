#!/bin/bash

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

# List of projects to build
projects=(libinput kio dolphin aurorae kwin plasma-desktop)

for project in "${projects[@]}"; do
  header="= $project ="
  border=$(printf '=%.0s' $(seq 1 ${#header}))
  echo ""
  echo "$border"
  echo "$header"
  echo "$border"

  # Clean up previous logs
  [ -f "$CWD/build.$project.log" ] && rm "$CWD/build.$project.log"

  # Fetch notes and branches
  git -C "$CWD/$project" fetch origin refs/notes/commits:refs/notes/commits >>"$CWD/build.$project.log" 2>&1
  git -C "$CWD/$project" fetch --prune >>"$CWD/build.$project.log" 2>&1

  # Determine branch from notes
  root_commit=$(git -C "$CWD/$project" rev-list --max-parents=0 origin/master 2>>"$CWD/build.$project.log")
  if [ -z "$root_commit" ]; then
    echo "Skipping $project: could not find root commit."
    continue
  fi

  branch=$(git -C "$CWD/$project" notes show "$root_commit" 2>>"$CWD/build.$project.log")
  if [ -z "$branch" ]; then
    echo "Skipping $project: no branch info in notes."
    continue
  fi

  # Checkout branch
  git -C "$CWD/$project" checkout "$branch" >>"$CWD/build.$project.log" 2>&1 || {
    echo "Skipping $project: failed to checkout branch '$branch'."
    continue
  }

  git -C "$CWD/$project" reset --hard "origin/$branch" >>"$CWD/build.$project.log" 2>&1

  # Build project from source, install build artifacts into dist folder
  case "$project" in
    aurorae|dolphin|kio|kwin|plasma-desktop)
      cmake -DCMAKE_INSTALL_PREFIX="/usr" -B "$CWD/$project/build/" -S "$CWD/$project/" 2>>"$CWD/build.$project.log" || continue
      make -C "$CWD/$project/build/" -j"$(nproc)" 2>>"$CWD/build.$project.log" || continue
      sudo make -C "$CWD/$project/build/" install DESTDIR="$CWD/dist/" 2>>"$CWD/build.$project.log" || continue
      ;;
    libinput)
      meson setup --prefix="/usr" -Dversion="$branch" "$CWD/$project/build/" "$CWD/$project/" 2>>"$CWD/build.$project.log" || continue
      ninja -C "$CWD/$project/build/" -j"$(nproc)" 2>>"$CWD/build.$project.log" || continue
      sudo env DESTDIR="$CWD/dist/" ninja -C "$CWD/$project/build/" install 2>>"$CWD/build.$project.log" || continue
      ;;
    *)
      echo "No build instructions for $project. Skipping."
      ;;
  esac

  echo "build log: $CWD/build.$project.log"
done

# Bundle up the dist folder
echo "Bundling up installation files into $CWD/dist.tar.gz"
tar czf "$CWD/dist.tar.gz" -C "$CWD/dist/" .
