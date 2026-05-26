#!/bin/bash

# Parse command-line options
projects_dir_input=""
fedora_version_input=""

while getopts "hC:f:" opt; do
  case $opt in
    h)
      cat <<EOF
Usage: $(basename "$0") -C <projects_dir> [-f <fedora_version>]

A script to branch off the iMac audio driver upstream based on the Linux kernel
version corresponding to the target Fedora release.

Options:
  -h    Show this help message and exit
  -C    Path to the directory where the project repository will be cloned
  -f    Fedora version to target (defaults to the host's current version: $(rpm -E %fedora))

Description:
  This script clones the audio driver fork from GitHub, fetches the latest from
  upstream, creates a tag based on the Linux kernel version, creates a customize
  branch from that tag, and marks it as build source. The kernel version is
  determined by querying the latest kernel package available on the target Fedora
  release via dnf.
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


# Function to branch off of upstream branch (for repos without tags)
branch_off_upstream_branch() {
  local project_dir="$1"
  local project=$(basename "$project_dir")

  local branch="$2"
  local upstream_branch="$3"

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

# Function to set fork version based on kernel version
set_fork_version() {
  local package="$1"
  #local package_name=$(jq -r '.name' <<< "$package")
  local package_fork=$(jq -r '.fork' <<< "$package")
  local project=$(basename "$package_fork" .git)

  local cwd="$2"
  local project_dir="$cwd/$project"

  local fedora_version="$3"

  # Find the latest kernel version for the target Fedora
  local tmp_output=$(mktemp)
  dnf --releasever="$fedora_version" repoquery --queryformat="%{VERSION}" --latest-limit=1 kernel >> "$tmp_output" 2>&1 || {
    echo "Error: unable to query the latest kernel version for Fedora $fedora_version" >&2
    rm -f "$tmp_output"
    return 1
  }

  local kernel_version=$(tail -n 1 "$tmp_output")
  rm -f "$tmp_output"

  if [ -z "$kernel_version" ]; then
    echo "Error: invalid kernel version for Fedora $fedora_version" >&2
    return 1
  fi

  # Branch off of the corresponding tag from upstream
  case "$project" in
    imac-cs8409-audio-driver)
      git -C "$project_dir" fetch --no-tags upstream "refs/heads/master:refs/upstream/master" &>/dev/null || {
        echo "Error: unable to fetch from upstream for $project" >&2
        return 1
      }

      local branch="customize/v$kernel_version"
      local upstream_branch="refs/upstream/master"
      branch_off_upstream_branch "$project_dir" "$branch" "$upstream_branch" || return 1
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
  {
    "name": "imac-cs8409-audio-driver",
    "fork": "git@github.com:kdha200501/imac-cs8409-audio-driver.git",
    "upstream": "https://github.com/davidjo/snd_hda_macbookpro.git"
  }
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
