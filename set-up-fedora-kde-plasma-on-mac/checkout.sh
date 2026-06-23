#!/bin/bash

# Parse command-line options
projects_dir_input=""
fedora_version_input=""

while getopts "hC:f:" opt; do
  case $opt in
    h)
      cat <<EOF
Usage: $(basename "$0") -C <projects_dir> [-f <fedora_version>]

A script to branching off Fedora packages' upstream tags corresponding to their
latest version on dnf.

Options:
  -h    Show this help message and exit
  -C    Path to the directory where project repositories will be cloned
  -f    Fedora version to target (defaults to the host's current version: $(rpm -E %fedora))

Description:
  This script clones package forks from GitHub, fetches upstream tags, creates
  build branches to match the packages' latest versions on dnf, and marks them as
  build source. For each fork, customization commits from the chronologically
  nearest build branch are listed.

  Supported packages:
    - libinput
    - kio (kf6-kio)
    - dolphin
    - aurorae
    - kscreenlocker
    - kwin
    - kdeplasma-addons
    - plasma-workspace
    - plasma-desktop
    - milou (plasma-milou)
    - plasma-login-manager
EOF
      exit 0
      ;;
    C)
      if [[ -z "$OPTARG" || "$OPTARG" == -* ]]; then
        echo "❌ Invalid projects directory." >&2
        exit 1
      fi
      projects_dir_input="$OPTARG"
      ;;
    f)
      if [[ -z "$OPTARG" || "$OPTARG" == -* ]]; then
        echo "❌ Invalid Fedora version." >&2
        exit 1
      fi
      fedora_version_input="$OPTARG"
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

  local branch="$2"
  local upstream_tag="$3"


  git -C "$project_dir" fetch origin --prune &>/dev/null || {
    echo "Error: failed to fetch from origin for $project" >&2
    return 1
  }

  git -C "$project_dir" reset --hard HEAD &>/dev/null

  # if the branch already exists in remote
  if git -C "$project_dir" ls-remote --exit-code --heads origin "$branch" &>/dev/null; then
    # then use the existing branch
    git -C "$project_dir" checkout "$branch" &>/dev/null
    git -C "$project_dir" reset --hard "origin/$branch" &>/dev/null
    echo "✅ Checked out existing branch $branch from origin for $project"
    return 0
  fi

  # if the branch does not exist in remote,
  # then create and push the new branch
  if git -C "$project_dir" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$project_dir" branch -D "$branch" &>/dev/null
  fi

  git -C "$project_dir" checkout "$upstream_tag" -b "$branch" &>/dev/null || {
    echo "Error: failed to create branch $branch from upstream tag $upstream_tag for $project" >&2
    return 1
  }

  git -C "$project_dir" push origin "$branch" &>/dev/null || {
    echo "Error: failed to push branch $branch to origin for $project" >&2
    return 1
  }

  echo "✨ Created branch $branch from $upstream_tag for $project"
  return 0
}

# Function to branch off of upstream branch (for repos without tags)
branch_off_upstream_branch() {
  local project_dir="$1"
  local project=$(basename "$project_dir")

  local branch="$2"
  local upstream_branch="$3"
  local package_latest_version="$4"

  git -C "$project_dir" fetch origin --prune &>/dev/null || {
    echo "Error: failed to fetch from origin for $project" >&2
    return 1
  }

  git -C "$project_dir" reset --hard HEAD &>/dev/null

  # Checkout the spec file from upstream branch to validate version
  local tmp_dir=$(mktemp -d)
  git -C "$project_dir" show "${upstream_branch}:${project}.spec" > "$tmp_dir/${project}.spec" 2>/dev/null || {
    echo "Error: failed to checkout ${project}.spec from $upstream_branch for $project" >&2
    rm -rf "$tmp_dir"
    return 1
  }

  local upstream_version=$(rpmspec --query --queryformat='%{VERSION}' --srpm "$tmp_dir/${project}.spec" 2>/dev/null)
  rm -rf "$tmp_dir"

  if [ "$upstream_version" != "$package_latest_version" ]; then
    echo "Error: upstream version $upstream_version does not match latest package version $package_latest_version for $project" >&2
    return 1
  fi

  # if the branch already exists in remote
  if git -C "$project_dir" ls-remote --exit-code --heads origin "$branch" &>/dev/null; then
    # then use the existing branch
    git -C "$project_dir" checkout "$branch" &>/dev/null
    git -C "$project_dir" reset --hard "origin/$branch" &>/dev/null
    echo "✅ Checked out existing branch $branch from origin for $project"
    return 0
  fi

  # if the branch does not exist in remote,
  # then create and push the new branch
  if git -C "$project_dir" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$project_dir" branch -D "$branch" &>/dev/null
  fi

  git -C "$project_dir" checkout "$upstream_branch" -b "$branch" &>/dev/null || {
    echo "Error: failed to create branch $branch from upstream branch $upstream_branch for $project" >&2
    return 1
  }

  git -C "$project_dir" push origin "$branch" &>/dev/null || {
    echo "Error: failed to push branch $branch to origin for $project" >&2
    return 1
  }

  echo "✨ Created branch $branch from $upstream_branch for $project"
  return 0
}

# Function to mark a branch as the build source
mark_build_branch() {
  local project_dir="$1"
  local project=$(basename "$project_dir")

  local branch="$2"
  local fedora_version="$3"

  # Get the root commit on the origin master branch
  local root_commit=$(git -C "$project_dir" rev-list --max-parents=0 origin/master 2>/dev/null)

  # Reset local git note to remote (may not exist yet for a new Fedora version)
  git -C "$project_dir" fetch origin "refs/notes/f$fedora_version:refs/notes/f$fedora_version" --quiet &>/dev/null

  local existing_note=$(git -C "$project_dir" notes --ref "f$fedora_version" show "$root_commit" 2>/dev/null)

  # if the branch is already marked as the build source
  if [ "$existing_note" = "$branch" ]; then
    # then no-op
    echo "📝 Branch $branch is already marked as the build source for $project (Fedora $fedora_version)"
    return 0
  fi

  if git -C "$project_dir" notes --ref "f$fedora_version" show "$root_commit" &>/dev/null; then
    git -C "$project_dir" notes --ref "f$fedora_version" remove "$root_commit" &>/dev/null
  fi

  # if the branch is not marked as the build source,
  # then mark the branch as the build source
  git -C "$project_dir" notes --ref "f$fedora_version" add -m "$branch" "$root_commit" &>/dev/null || {
    echo "Error: failed to mark branch $branch as build source for $project" >&2
    return 1
  }

  git -C "$project_dir" push origin "refs/notes/f$fedora_version" --force &>/dev/null || {
    echo "Error: failed to push notes for $project" >&2
    return 1
  }

  echo "📝 Branch $branch marked as the build source for $project (Fedora $fedora_version)"
  return 0
}

# Function to display customization commits from the nearest branch
display_cherry_pick_commits() {
  local project_dir="$1"
  local project=$(basename "$project_dir")

  local branch="$2"
  local tag_commit="$3"

  # if the branch already contains customization commit(s)
  if [ "$(git -C "$project_dir" rev-parse "$branch" 2>/dev/null)" != "$tag_commit" ]; then
    # then no-op
    echo "✅ No cherry-pick commits needed"
    return 0
  fi

  # if the branch does not contain customization commit(s),
  # then list customization commits from the nearest branch
  local youngest_branch=""
  local youngest_tag=""
  local youngest_time=0

  while IFS= read -r remote_branch; do
    local common_ancestor_commit=$(git -C "$project_dir" merge-base "$remote_branch" "$tag_commit" 2>/dev/null)
    [ -z "$common_ancestor_commit" ] && continue

    local tag=$(git -C "$project_dir" for-each-ref --contains "$common_ancestor_commit" --sort=creatordate --format='%(refname:short)' refs/upstream/ 2>/dev/null | head -1)
    [ -z "$tag" ] && continue

    if [ "$(git -C "$project_dir" rev-parse "$remote_branch" 2>/dev/null)" = "$(git -C "$project_dir" rev-parse "$tag^{}" 2>/dev/null)" ]; then
      continue
    fi

    local tag_time_in_sec=$(git -C "$project_dir" log -1 --format=%at "$tag" 2>/dev/null)
    [ -z "$tag_time_in_sec" ] && continue

    [ "$tag_time_in_sec" -lt "$youngest_time" ] && continue

    youngest_time="$tag_time_in_sec"
    youngest_branch="$remote_branch"
    youngest_tag="$tag"
  done < <(git -C "$project_dir" branch -r 2>/dev/null | grep 'origin/customize/' | sed 's/^ *//')

  if [ -n "$youngest_branch" ] && [ -n "$youngest_tag" ]; then
    echo "🍒 Cherry pick the following commits from $youngest_branch (based on $youngest_tag) for $project:"
    git -C "$project_dir" log --oneline --no-decorate "$youngest_tag..$youngest_branch"
    return 0
  fi

  echo "Error: No existing customization branch found to cherry-pick from for $project"
  return 1
}

# Function to get and setup fork
get_fork() {
  local package="$1"
  local package_upstream=$(jq -r '.upstream' <<< "$package")
  local package_fork=$(jq -r '.fork' <<< "$package")
  local project=$(basename "$package_fork" .git)

  local cwd="$2"
  local project_dir="$cwd/$project"

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

  local cwd="$2"
  local project_dir="$cwd/$project"

  local fedora_version="$3"

  # Find the latest version for the package
  local tmp_output=$(mktemp)
  dnf --releasever="$fedora_version" repoquery --queryformat="%{VERSION}" --latest-limit=1 "$package_name" >> "$tmp_output" 2>&1 || {
    echo "Error: unable to query the latest version for package $package_name" >&2
    rm -f "$tmp_output"
    return 1
  }

  local package_latest_version=$(tail -n 1 "$tmp_output")
  rm -f "$tmp_output"

  if [ -z "$package_latest_version" ]; then
    echo "Error: invalid version for package $package_name" >&2
    return 1
  fi

  # Branch off of the corresponding tag from upstream
  case "$project" in
    libinput)
      local tag="$package_latest_version"
      git -C "$project_dir" fetch --no-tags upstream "refs/tags/$tag:refs/upstream/v$tag" &>/dev/null || {
        echo "Error: unable to fetch tag $tag from upstream for $project" >&2
        return 1
      }

      local branch="customize/v$tag"
      local upstream_tag="refs/upstream/v$tag"
      branch_off_upstream_tag "$project_dir" "$branch" "$upstream_tag" || return 1
      mark_build_branch "$project_dir" "$branch" "$fedora_version" || return 1

      local tag_commit=$(git -C "$project_dir" rev-parse "${upstream_tag}^{}" 2>/dev/null)
      display_cherry_pick_commits "$project_dir" "$branch" "$tag_commit" || return 1

      return 0
      ;;
    aurorae|dolphin|kio|kwin|kdeplasma-addons|plasma-workspace|plasma-desktop|kscreenlocker|milou)
      local tag="v$package_latest_version"
      git -C "$project_dir" fetch --no-tags upstream "refs/tags/$tag:refs/upstream/$tag" &>/dev/null || {
        echo "Error: unable to fetch tag $tag from upstream for $project" >&2
        return 1
      }

      local branch="customize/$tag"
      local upstream_tag="refs/upstream/$tag"
      branch_off_upstream_tag "$project_dir" "$branch" "$upstream_tag" || return 1
      mark_build_branch "$project_dir" "$branch" "$fedora_version" || return 1

      local tag_commit=$(git -C "$project_dir" rev-parse "${upstream_tag}^{}" 2>/dev/null)
      display_cherry_pick_commits "$project_dir" "$branch" "$tag_commit" || return 1

      return 0
      ;;
    plasma-login-manager)
      git -C "$project_dir" fetch --no-tags upstream "refs/heads/f$fedora_version:refs/upstream/f$fedora_version" &>/dev/null || {
        echo "Error: unable to fetch branch f$fedora_version from upstream for $project" >&2
        return 1
      }

      local branch="customize/v$package_latest_version"
      local upstream_branch="refs/upstream/f$fedora_version"
      branch_off_upstream_branch "$project_dir" "$branch" "$upstream_branch" "$package_latest_version" || return 1
      mark_build_branch "$project_dir" "$branch" "$fedora_version" || return 1

      local branch_commit=$(git -C "$project_dir" rev-parse "$upstream_branch" 2>/dev/null)
      display_cherry_pick_commits "$project_dir" "$branch" "$branch_commit" || return 1

      return 0
      ;;
    *)
      echo "Error: unknown project $project" >&2
      return 1
      ;;
  esac
}

##################
# Main execution #
##################

# Vet the projects directory option
projects_dir_input=$(get_projects_directory_option "$projects_dir_input")
[[ $? -ne 0 ]] && { echo "❌ Invalid projects directory" >&2; exit 1; }
CWD="${projects_dir_input%/}"

# Vet the Fedora version option
dnf --releasever="$fedora_version_input" repoquery --repo=fedora --latest-limit=1 fedora-release &>/dev/null
[[ $? -ne 0 ]] && { echo "❌ Fedora version $fedora_version_input is not available in dnf" >&2; exit 1; }
FEDORA_VERSION="$fedora_version_input"

PACKAGE_JSON=$(cat <<"EOF"
[
  { "name": "libinput",             "fork": "git@github.com:kdha200501/libinput.git",             "upstream": "https://gitlab.freedesktop.org/libinput/libinput.git" },
  { "name": "kf6-kio",              "fork": "git@github.com:kdha200501/kio.git",                  "upstream": "https://github.com/KDE/kio.git" },
  { "name": "dolphin",              "fork": "git@github.com:kdha200501/dolphin.git",              "upstream": "https://github.com/KDE/dolphin.git" },
  { "name": "aurorae",              "fork": "git@github.com:kdha200501/aurorae.git",              "upstream": "https://github.com/KDE/aurorae.git" },
  { "name": "kscreenlocker",        "fork": "git@github.com:kdha200501/kscreenlocker.git",        "upstream": "https://github.com/KDE/kscreenlocker.git" },
  { "name": "kwin",                 "fork": "git@github.com:kdha200501/kwin.git",                 "upstream": "https://github.com/KDE/kwin.git" },
  { "name": "kdeplasma-addons",     "fork": "git@github.com:kdha200501/kdeplasma-addons.git",     "upstream": "https://github.com/KDE/kdeplasma-addons.git" },
  { "name": "plasma-workspace",     "fork": "git@github.com:kdha200501/plasma-workspace.git",     "upstream": "https://github.com/KDE/plasma-workspace.git" },
  { "name": "plasma-desktop",       "fork": "git@github.com:kdha200501/plasma-desktop.git",       "upstream": "https://github.com/KDE/plasma-desktop.git" },
  { "name": "plasma-milou",         "fork": "git@github.com:kdha200501/milou.git",                "upstream": "https://github.com/KDE/milou.git" },
  { "name": "plasma-login-manager", "fork": "git@github.com:kdha200501/plasma-login-manager.git", "upstream": "https://src.fedoraproject.org/rpms/plasma-login-manager.git" }
]
EOF
)

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
