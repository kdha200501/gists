#!/bin/bash

# Parse command-line options
projects_dir=""

while getopts "hC:" opt; do
  case $opt in
    h)
      cat <<EOF
Usage: $(basename "$0") -C <projects_dir>

A script to branching off Fedora packages' upstream tags corresponding to their
latest version on dnf.

Options:
  -h    Show this help message and exit
  -C    Path to the directory where project repositories will be cloned

Description:
  This script clones package forks from GitHub, fetches upstream tags, creates
  build branches to match the packages' latest versions on dnf, and marks them as
  build source. For each fork, customization commits from the chronologically
  nearest build branch are listed.

  Supported packages:
    - libinput
    - kf6-kio
    - dolphin
    - aurorae
    - kscreenlocker
    - kwin
    - kdeplasma-addons
    - plasma-workspace
    - plasma-desktop
EOF
      exit 0
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

# Function to get the projects' directory
get_projects_directory_option() {
  local input_dir="$1"

  [ -z "$input_dir" ] && return 1

  [ ! -d "$input_dir" ] && return 1

  input_dir=$([[ "$input_dir" = /* ]] && echo "$input_dir" || echo "$(pwd)/$input_dir")
  readlink -f "$input_dir"
}

# Function to branch off of upstream tag
branch_off_upstream_tag() {
  local project_dir="$1"
  local project=$(basename "$project_dir")

  local BRANCH="$2"
  local UPSTREAM_TAG="$3"


  git -C "$project_dir" fetch --prune &>/dev/null || {
    echo "Error: failed to fetch from upstream for $project" >&2
    return 1
  }

  git -C "$project_dir" reset --hard HEAD &>/dev/null

  # if the branch already exists in remote
  if git -C "$project_dir" ls-remote --exit-code --heads origin "$BRANCH" &>/dev/null; then
    # then use the existing branch
    git -C "$project_dir" checkout "$BRANCH" &>/dev/null
    git -C "$project_dir" reset --hard "origin/$BRANCH" &>/dev/null
    echo "✅ Branch $BRANCH exists and is up to date for $project"
    return 0
  fi

  # if the branch does not exist in remote,
  # then create and push the new branch
  git -C "$project_dir" checkout "$UPSTREAM_TAG" -b "$BRANCH" &>/dev/null || {
    echo "Error: failed to checkout $UPSTREAM_TAG and create branch $BRANCH for $project" >&2
    return 1
  }

  git -C "$project_dir" push origin "$BRANCH" &>/dev/null || {
    echo "Error: failed to push branch $BRANCH to origin for $project" >&2
    return 1
  }

  echo "✨ Created branch $BRANCH from $UPSTREAM_TAG for $project"
  return 0
}

# Function to mark a branch as the build source
mark_build_branch() {
  local project_dir="$1"
  local project=$(basename "$project_dir")

  local BRANCH="$2"
  local FEDORA_VERSION="$3"

  # Clear git note on the root commit
  ROOT_COMMIT=$(git -C "$project_dir" rev-list --max-parents=0 origin/master 2>/dev/null)

  if git -C "$project_dir" notes --ref "f$FEDORA_VERSION" show "$ROOT_COMMIT" &>/dev/null; then
    git -C "$project_dir" notes --ref "f$FEDORA_VERSION" remove "$ROOT_COMMIT" &>/dev/null
  fi

  # Mark branch as the build source using git note
  git -C "$project_dir" notes --ref "f$FEDORA_VERSION" add -m "$BRANCH" "$ROOT_COMMIT" &>/dev/null || {
    echo "Error: failed to mark branch $BRANCH as build source for $project" >&2
    return 1
  }

  git -C "$project_dir" push origin "refs/notes/f$FEDORA_VERSION" --force &>/dev/null || {
    echo "Error: failed to push notes for $project" >&2
    return 1
  }

  echo "📝 Marked $BRANCH as build source for $project (Fedora $FEDORA_VERSION)"
  return 0
}

# Function to display customization commits from the nearest branch
display_cherry_pick_commits() {
  local project_dir="$1"
  local project=$(basename "$project_dir")

  local BRANCH="$2"
  local TAG_COMMIT="$3"

  # if the branch already contains customization commit(s)
  if [ "$(git -C "$project_dir" rev-parse "$BRANCH" 2>/dev/null)" != "$TAG_COMMIT" ]; then
    # then no-op
    echo "✅ No cherry-pick commits needed"
    return 0
  fi

  # if the branch does not contain customization commit(s),
  # then list customization commits from the nearest branch
  YOUNGEST_BRANCH=""
  YOUNGEST_TAG=""
  YOUNGEST_TIME=0

  while IFS= read -r remote_branch; do
    common_ancestor_commit=$(git -C "$project_dir" merge-base "$remote_branch" "$TAG_COMMIT" 2>/dev/null)
    [ -z "$common_ancestor_commit" ] && continue

    tag=$(git -C "$project_dir" for-each-ref --contains "$common_ancestor_commit" --sort=creatordate --format='%(refname:short)' refs/upstream/ 2>/dev/null | head -1)
    [ -z "$tag" ] && continue

    if [ "$(git -C "$project_dir" rev-parse "$remote_branch" 2>/dev/null)" = "$(git -C "$project_dir" rev-parse "$tag^{}" 2>/dev/null)" ]; then
      continue
    fi

    tag_time_in_sec=$(git -C "$project_dir" log -1 --format=%at "$tag" 2>/dev/null)
    [ -z "$tag_time_in_sec" ] && continue

    [ "$tag_time_in_sec" -lt "$YOUNGEST_TIME" ] && continue

    YOUNGEST_TIME="$tag_time_in_sec"
    YOUNGEST_BRANCH="$remote_branch"
    YOUNGEST_TAG="$tag"
  done < <(git -C "$project_dir" branch -r 2>/dev/null | grep 'origin/customize/' | sed 's/^ *//')

  if [ -n "$YOUNGEST_BRANCH" ] && [ -n "$YOUNGEST_TAG" ]; then
    echo "🍒 Cherry pick the following commits from $YOUNGEST_BRANCH (based on $YOUNGEST_TAG) for $project:"
    git -C "$project_dir" log --oneline --no-decorate "$YOUNGEST_TAG..$YOUNGEST_BRANCH"
    return 0
  fi

  echo "Error: No existing customize branches found to cherry-pick from for $project"
  return 1
}

# Function to get and setup fork
get_fork() {
  local package="$1"
  local package_upstream=$(jq -r '.upstream' <<< "$package")
  local package_fork=$(jq -r '.fork' <<< "$package")
  local project=$(basename "$package_fork" .git)

  local CWD="$2"
  local project_dir="$CWD/$project"

  # Clone the package's repository (if not found)
  if [ ! -d "$project_dir" ]; then
    git clone --quiet "$package_fork" "$project_dir" || {
      echo "Error: failed to clone $project" >&2
      return 1
    }

    echo "📥 $project cloned successfully"
  fi

  # Validate the package's repository
  if [ ! -d "$project_dir/.git" ]; then
    echo "Error: $project_dir is not a git repository" >&2
    return 1
  fi

  if [ "$(git -C "$project_dir" remote get-url origin 2>/dev/null)" != "$package_fork" ] || [ "$(git -C "$project_dir" remote get-url --push origin 2>/dev/null)" != "$package_fork" ]; then
    echo "Error: remote URL mismatch for $project, expecting: $package_fork" >&2
    return 1
  fi

  # Set upstream remote
  if [ -z "$(git -C "$project_dir" remote get-url upstream 2>/dev/null)" ]; then
    git -C "$project_dir" remote add upstream "$package_upstream" &>/dev/null
    echo "⬆️  Upstream remote added for $project"
    return 0
  fi

  git -C "$project_dir" remote set-url upstream "$package_upstream" &>/dev/null
  echo "⬆️  Upstream remote updated for $project"
  return 0
}

# Function to set fork version
set_fork_version() {
  local package="$1"
  local package_name=$(jq -r '.name' <<< "$package")
  local package_fork=$(jq -r '.fork' <<< "$package")
  local project=$(basename "$package_fork" .git)

  local CWD="$2"
  local project_dir="$CWD/$project"

  local FEDORA_VERSION="$3"

  # Find the latest version for the package
  TMP_OUTPUT=$(mktemp)
  dnf --releasever="$FEDORA_VERSION" repoquery --queryformat="%{VERSION}" --latest-limit=1 "$package_name" >> "$TMP_OUTPUT" 2>&1 || {
    echo "Error: unable to query the latest version for package $package_name" >&2
    rm -f "$TMP_OUTPUT"
    return 1
  }

  PACKAGE_LATEST_VERSION=$(tail -n 1 "$TMP_OUTPUT")
  rm -f "$TMP_OUTPUT"

  if [ -z "$PACKAGE_LATEST_VERSION" ]; then
    echo "Error: invalid version for package $package_name" >&2
    return 1
  fi

  # Branch off of the corresponding tag from upstream
  case "$project" in
    libinput)
      TAG="$PACKAGE_LATEST_VERSION"
      git -C "$project_dir" fetch --no-tags upstream "refs/tags/$TAG:refs/upstream/v$TAG" &>/dev/null || {
        echo "Error: unable to fetch tag $TAG from upstream for $project" >&2
        return 1
      }

      BRANCH="customize/v$TAG"
      UPSTREAM_TAG="refs/upstream/v$TAG"
      branch_off_upstream_tag "$project_dir" "$BRANCH" "$UPSTREAM_TAG" || return 1
      mark_build_branch "$project_dir" "$BRANCH" "$FEDORA_VERSION" || return 1

      TAG_COMMIT=$(git -C "$project_dir" rev-parse "${UPSTREAM_TAG}^{}" 2>/dev/null)
      display_cherry_pick_commits "$project_dir" "$BRANCH" "$TAG_COMMIT" || return 1

      return 0
      ;;
    aurorae|dolphin|kio|kwin|kdeplasma-addons|plasma-workspace|plasma-desktop|kscreenlocker)
      TAG="v$PACKAGE_LATEST_VERSION"
      git -C "$project_dir" fetch --no-tags upstream "refs/tags/$TAG:refs/upstream/$TAG" &>/dev/null || {
        echo "Error: unable to fetch tag $TAG from upstream for $project" >&2
        return 1
      }

      BRANCH="customize/$TAG"
      UPSTREAM_TAG="refs/upstream/$TAG"
      branch_off_upstream_tag "$project_dir" "$BRANCH" "$UPSTREAM_TAG" || return 1
      mark_build_branch "$project_dir" "$BRANCH" "$FEDORA_VERSION" || return 1

      TAG_COMMIT=$(git -C "$project_dir" rev-parse "${UPSTREAM_TAG}^{}" 2>/dev/null)
      display_cherry_pick_commits "$project_dir" "$BRANCH" "$TAG_COMMIT" || return 1

      return 0
      ;;
    *)
      echo "Error: unknown project $project" >&2
      return 1
      ;;
  esac
}

# Vet the projects directory option
projects_dir=$(get_projects_directory_option "$projects_dir")
[[ $? -ne 0 ]] && { echo "❌ Invalid projects directory" >&2; exit 1; }
CWD="${projects_dir%/}"

# Go through package forks
PACKAGE_JSON=$(cat <<"EOF"
[
  { "name": "libinput",             "fork": "git@github.com:kdha200501/libinput.git",         "upstream": "https://gitlab.freedesktop.org/libinput/libinput.git" },
  { "name": "kf6-kio",              "fork": "git@github.com:kdha200501/kio.git",              "upstream": "https://github.com/KDE/kio.git" },
  { "name": "dolphin",              "fork": "git@github.com:kdha200501/dolphin.git",          "upstream": "https://github.com/KDE/dolphin.git" },
  { "name": "aurorae",              "fork": "git@github.com:kdha200501/aurorae.git",          "upstream": "https://github.com/KDE/aurorae.git" },
  { "name": "kscreenlocker",        "fork": "git@github.com:kdha200501/kscreenlocker.git",    "upstream": "https://github.com/KDE/kscreenlocker.git" },
  { "name": "kwin",                 "fork": "git@github.com:kdha200501/kwin.git",             "upstream": "https://github.com/KDE/kwin.git" },
  { "name": "kdeplasma-addons",     "fork": "git@github.com:kdha200501/kdeplasma-addons.git", "upstream": "https://github.com/KDE/kdeplasma-addons.git" },
  { "name": "plasma-workspace",     "fork": "git@github.com:kdha200501/plasma-workspace.git", "upstream": "https://github.com/KDE/plasma-workspace.git" },
  { "name": "plasma-desktop",       "fork": "git@github.com:kdha200501/plasma-desktop.git",   "upstream": "https://github.com/KDE/plasma-desktop.git" }
]
EOF
)

FEDORA_VERSION=$(rpm -E %fedora)
for package in $(jq -c '.[]' <<< "$PACKAGE_JSON"); do
  package_fork=$(jq -r '.fork' <<< "$package")
  project=$(basename "$package_fork" .git)
  project_dir="$CWD/$project"

  echo ""
  echo "⑂ Fork: $project_dir"
  echo "📋 Checkout log:"
  echo "━━━━━━━━━━━━━━━━━━━━ Log begin ━━━━━━━━━━━━━━━━━━━━"

  get_fork "$package" "$CWD" || {
    echo "❌ Failed to get fork for $project"
    continue
  }

  set_fork_version "$package" "$CWD" "$FEDORA_VERSION" || {
    echo "❌ Failed to set fork version for $project"
    continue
  }

  echo "━━━━━━━━━━━━━━━━━━━━  Log end  ━━━━━━━━━━━━━━━━━━━━"
done
