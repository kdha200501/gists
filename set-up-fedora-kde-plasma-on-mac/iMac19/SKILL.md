---
name: imac-driver-update
description: >-
  Update the iMac driver forks to match the latest kernel version available through dnf.
  Use this skill when the user mentions "iMac driver updates", or wants to sync their
  iMac driver fork with the latest kernel version.
---

# iMac Driver Fork Update

## Overview

This skill automates updating the iMac driver forks to match the latest Linux kernel
version available through `dnf`. It uses `checkout.sh` — bundled in this skill's directory
alongside this `SKILL.md` — to branch off upstream branch, mark build sources, and
identify which forks require cherry-picking of customization commits.

Supported drivers: imac-cs8409-audio-driver

---

## Step 1 — Determine the target Fedora version

Detect the host machine's current Fedora version:

```bash
rpm -E %fedora
```

Ask the user which Fedora version to target, presenting the detected version as
the default:

```bash
read -p "Which Fedora version should I target? (default: $(rpm -E %fedora)): " fedora_version
fedora_version="${fedora_version:-$(rpm -E %fedora)}"
```

Use the value of `fedora_version` for the rest of the skill.

---

## Step 2 — Run `checkout.sh`

Locate `checkout.sh` in this skill's directory:

- **Claude Code**: the path is `${CLAUDE_SKILL_DIR}/checkout.sh`
- **Copilot CLI and other tools**: find `checkout.sh` alongside this `SKILL.md`
  file (e.g. `~/.copilot/skills/imac-driver-update/checkout.sh`,
  `~/.claude/skills/imac-driver-update/checkout.sh`, or
  `~/.agents/skills/imac-driver-update/checkout.sh`)

Determine the **current working directory** at the time the prompt was received.

Run the script, passing the current working directory with the `-C` option and
the target Fedora version with the `-f` option:

```bash
<path_to_checkout_sh> -C <current_working_directory> -f <fedora_version>
```

Capture the **complete stdout output** of the script for use in the next step.

---

## Step 3 — Parse the script output

Scan the captured output for the iMac driver fork that requires cherry-picking. The output is
structured as one log block per fork:

```
⑂ Fork: <fork_directory>
📋 Checkout log:
━━━━━━━━━━━━━━━━━━━━ Log begin ━━━━━━━━━━━━━━━━━━━━
...
🍒 Cherry pick the following commits from <source_branch> (based on <upstream_ref>) for imac-cs8409-audio-driver:
<short_hash_1> <commit_subject_1>
<short_hash_2> <commit_subject_2>
...
━━━━━━━━━━━━━━━━━━━━  Log end  ━━━━━━━━━━━━━━━━━━━━
```

A fork **requires cherry-picking** when its log block contains a line that starts
with the 🍒 emoji.

For each such fork, extract:

1. **Fork directory** — the absolute path from the `⑂ Fork: <path>` line in the
   same log block
2. **Source branch** — from the 🍒 line:
   `🍒 Cherry pick the following commits from <source_branch> ...`
3. **Commit list** — every `git log --oneline` entry after the 🍒 line up to (but
   not including) the `━━━...  Log end  ━━━` separator; each entry has the form
   `<short_hash> <subject>`

> **Note:** The commit list is ordered newest-first (output of
> `git log <tag>..<branch>`). **Reverse the list** before cherry-picking so that
> commits are applied in chronological order (oldest first).

---

## Step 4 — Ask for confirmation

Present the parsed results to the user:

- For each fork that requires cherry-picking, list the fork directory and the
  commits to be applied.
- If **no forks** require cherry-picking, inform the user that all iMac driver forks
  are already up to date and stop.

Then ask: **"Would you like to proceed with cherry-picking the above commits?"**

Stop if the user does not confirm.

---

## Step 5 — Spawn one sub-agent per fork

For **each** fork that requires cherry-picking, **spawn a separate sub-agent**,
providing it with the per-fork context and the sub-agent instructions below.
Sub-agents for different forks may run in parallel.

### Per-fork context to pass to each sub-agent

```
Fork directory : <fork_directory>
Source branch  : <source_branch>
Commits to cherry-pick (oldest-first after reversing the list):
<oldest_hash> <oldest_subject>
...
<newest_hash> <newest_subject>
```

### Sub-agent instructions

1. **Navigate to the fork directory**

   ```bash
   cd <fork_directory>
   ```

   Verify the directory exists and is a Git repository (`git status`). If not,
   report an error and stop.

2. **Reset the working tree to a clean state**

   ```bash
   git reset --hard HEAD
   ```

   This ensures no leftover changes pollute the cherry-pick work.

3. **Cherry-pick each commit sequentially** (oldest first)

   For each commit hash in the list:

   ```bash
   git cherry-pick <commit_hash>
   ```

4. **Resolve conflicts, if any**

   If `git cherry-pick` exits with a non-zero status due to conflicts:

   a. Run `git status` to identify conflicting files.

   b. For each conflicting file, attempt to resolve:
      - Accept the **incoming (cherry-picked) changes** where the conflict is in
        customization lines that are not present in the base.
      - For overlapping changes, apply judgment to merge both sets of changes
        while preserving the intent of both the upstream update and the
        customization.

   c. Stage all resolved files:
      ```bash
      git add <resolved_file> ...
      ```

   d. Continue the cherry-pick:
      ```bash
      git cherry-pick --continue --no-edit
      ```

   e. **Record** this commit hash in a conflicts list to include in the final report.

5. **Abort on unresolvable conflicts**

   If a conflict cannot be resolved, abort the cherry-pick:

   ```bash
   git cherry-pick --abort
   ```

   Stop processing further commits for this fork and report:
   - The commit hash that caused the abort
   - The conflicting files
   - The reason the conflict could not be resolved

6. **Push to origin** once all commits have been applied successfully:

   ```bash
   git push origin HEAD
   ```

7. **Report results** back to the parent agent:

   - ✅ Successfully cherry-picked commits (hash + subject)
   - ⚠️ Commits where conflicts were encountered and how they were resolved
   - ❌ Any commit that caused an aborted cherry-pick (requires manual intervention)

---

## Step 6 — Summarize results

After all sub-agents complete, present a summary to the user:

- For each fork processed: the new branch name, the number of commits
  cherry-picked, and any conflicts encountered.
- Prominently highlight any fork whose cherry-pick was **aborted** — manual
  intervention is required for those.
- If all forks were updated cleanly, confirm with a success message.
