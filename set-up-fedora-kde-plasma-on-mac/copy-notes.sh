#!/bin/bash

FROM_VERSION=""
TO_VERSION=""
projects_dir=""

while getopts "C:f:t:h" opt; do
  case $opt in
    f) FROM_VERSION="$OPTARG" ;;
    t) TO_VERSION="$OPTARG" ;;
    C) projects_dir="$OPTARG" ;;
    h)
      cat <<EOF
Copy git notes from one Fedora namespace to another across all forks.

Usage: $0 [-C projects_dir] [-f from_version] [-t to_version]
  -f  Source Fedora version (required)
  -t  Target Fedora version (required)
  -C  Projects' parent directory (required)
  -h  Show this help message

Forks:
  libinput, kio, dolphin, aurorae, kscreenlocker, kwin,
  plasma-workspace, plasma-desktop, sddm

Examples:
  $0 -C /path/to/projects -f 42 -t 43
EOF
      exit 0
      ;;
    *) echo "Usage: $0 [-C projects_dir] [-f from_version] [-t to_version]" >&2; exit 1 ;;
  esac
done

[ -z "$FROM_VERSION" ] && { echo "❌ Source Fedora version not specified, use -f" >&2; exit 1; }
[ -z "$TO_VERSION" ]   && { echo "❌ Target Fedora version not specified, use -t" >&2; exit 1; }
[ -z "$projects_dir" ] && { echo "❌ Projects directory not specified, use -C" >&2; exit 1; }
[ ! -d "$projects_dir" ] && { echo "❌ Projects directory not found: $projects_dir" >&2; exit 1; }

projects_dir=$([[ "$projects_dir" = /* ]] && echo "$projects_dir" || echo "$(pwd)/$projects_dir")
CWD=$(readlink -f "$projects_dir")
CWD="${CWD%/}"

PROJECTS=(libinput kio dolphin aurorae kscreenlocker kwin plasma-workspace plasma-desktop sddm)

for project in "${PROJECTS[@]}"; do
  project_dir="$CWD/$project"
  printf "\n%s\n" "$project"

  if [ ! -d "$project_dir/.git" ]; then
    printf "⏭  Skipping (not found)\n"
    continue
  fi

  # Fetch notes from source namespace
  if ! git -C "$project_dir" fetch origin "refs/notes/f$FROM_VERSION:refs/notes/f$FROM_VERSION" 2>/dev/null; then
    printf "❌ Failed to fetch refs/notes/f%s\n" "$FROM_VERSION"
    continue
  fi

  # Get root commit
  root_commit=$(git -C "$project_dir" rev-list --max-parents=0 origin/master 2>/dev/null)
  if [ -z "$root_commit" ]; then
    printf "❌ Could not find root commit\n"
    continue
  fi

  # Read note from source namespace
  note=$(git -C "$project_dir" notes --ref "f$FROM_VERSION" show "$root_commit" 2>/dev/null)
  if [ -z "$note" ]; then
    printf "❌ No note found in refs/notes/f%s\n" "$FROM_VERSION"
    continue
  fi

  printf "📋 %s\n" "$note"

  # Write note to target namespace
  git -C "$project_dir" notes --ref "f$TO_VERSION" remove "$root_commit" 2>/dev/null
  if ! git -C "$project_dir" notes --ref "f$TO_VERSION" add -m "$note" "$root_commit"; then
    printf "❌ Failed to write note to refs/notes/f%s\n" "$TO_VERSION"
    continue
  fi

  # Push target namespace
  if git -C "$project_dir" push origin "refs/notes/f$TO_VERSION" --force 2>/dev/null; then
    printf "✅ refs/notes/f%s pushed\n" "$TO_VERSION"
  else
    printf "❌ Failed to push refs/notes/f%s\n" "$TO_VERSION"
  fi
done
