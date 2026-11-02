---
name: tvb-download
description: >-
  Download a single TVB Anywhere (tvbanywherena.com) episode as an mp4 using
  ffmpeg under nohup. Use when the user says "download a TVB episode", "grab a
  TVBAnywhere show", gives a tvbanywherena.com watch/series URL, or asks to
  save a TVB episode as mp4.
---

# TVB Episode Download

Downloads **one** episode from TVB Anywhere (tvbanywherena.com) to mp4 using
`ffmpeg` launched under `nohup`, logs to a file next to the video, and prints a
`tail -f <log>` command.

Two scripts live alongside this file (locate them next to `SKILL.md`, e.g.
`~/.agents/skills/tvb-download/<script>` or the project's
`.agents/skills/tvb-download/<script>`):

- `build-m3u8.js <watch-url | videoId>` — prints a fresh signed `master.m3u8` URL.
- `parse-page.js <html-file>` — parse a saved page; prints JSON describing a
  show page (`type: "show"`, with an `episodes` list) or an episode page
  (`type: "episode"`, with `showName`, `episodeNo`, `videoId`).

Brightcove constants (embedded in the scripts, do not change): account
`5324042807001`, player key `t3oBfbU6IW_default`.

## Step 1 — Get a URL

If no TVB URL is present in the conversation, ask the user for it:

```
"Please paste a tvbanywherena.com watch or series URL (e.g. https://tvbanywherena.com/watch/3737-.../1880035607381933147)."
```

Save the page and classify it:

```bash
TMP_HTML=$(mktemp); curl -fsSL "URL" -o "$TMP_HTML"; node parse-page.js "$TMP_HTML"
```

- `type: "show"` → go to **Step 2** (ask which episode).
- `type: "episode"` → go to **Step 3**.

## Step 2 — Choose the episode

Present the `episodes` list (index + `episodeNo` + `name`). Ask the user which
one, defaulting to the first:

```
"Which episode of <showName>? (default: 1)"
```

Select that episode's `url` and `videoId`, then go to **Step 3**.

## Step 3 — Ask for the destination

The output is mp4. The default save path is
`~/Downloads/<show-name>/Episode-<NN>.mp4`, where `<show-name>` is the **Chinese
title** and `<NN>` is the two-digit episode number (from `episodeNo`, padded).
Ask with the default filled in, and allow typing a custom path:

```
"Where should I save <showName> Episode <NN>? (default: /home/<user>/Downloads/<showName>/Episode-<NN>.mp4)"
```

Use the typed path if given, otherwise the default. Strip a trailing `/` if the
user entered a folder. Create the parent directory. If the target file already
exists, it is overwritten (ffmpeg runs with `-y`).

## Step 4 — Build the m3u8 URL

```bash
M3U8=$(node build-m3u8.js "EPISODE_URL")
```

If this fails, stop and report the error.

## Step 5 — Launch the download

Resolve the absolute video and log paths. Log file lives in the same directory
as the video, named after the full video filename including its extension:
`<dir>/<video>.log` (e.g. `Episode-01.mp4.log`). Then:

```bash
DIR=$(dirname "VIDEO"); mkdir -p "$DIR"
LOG="$DIR/$(basename "VIDEO").log"
nohup setsid ffmpeg -y -loglevel info -protocol_whitelist file,http,https,tcp,tls,crypto \
  -i "$M3U8" -c copy "$VIDEO" > "$LOG" 2>&1 < /dev/null &
echo "started"
```

This command returns immediately. Once it prints `started`, go straight to
**Step 6**. Do **not** `sleep`, `tail`, or otherwise wait for the download to
progress or finish — that blocks the shell and risks killing ffmpeg when the
session ends.

## Step 6 — Report

Print the log path (note: the log is `<video>.log`, e.g. `Episode-01.mp4.log`)
and a command to follow it, e.g.:

```
tail -f /home/<user>/Downloads/<showName>/Episode-<NN>.mp4.log
```

Tell the user the download is running in the background via `nohup` and they can
check progress with the command above. Then stop — do not poll the log.

## Notes

- The Brightcove `fastly_token` URL expires in minutes; build it right before
  launching ffmpeg in the same shell.
- Keep the ffmpeg command on one logical invocation so `nohup` backgrounds a
  single `ffmpeg` process.
