# Replace meta data in audio file

##### sample `tracks.json`

```json
[
  {
    "trackFilePath": "<file path to the track audio file>",
    "albumArtFilePath": "<file path to the album art file>",
    "album": <album>,
    "discNumber": <disk number>,
    "trackNumber": <track number>,
    "artists": "<track artists>",
    "name": "<track name>"
  }
]
```

##### batch process

```shell
#!/bin/bash

TRACKS_JSON=<path to tracks.json>

jq -c '.[]' "$TRACKS_JSON" | while read -r track; do
    trackFilePath=$(echo "$track" | jq -r '.trackFilePath')
    albumArtFilePath=$(echo "$track" | jq -r '.albumArtFilePath')
    album=$(echo "$track" | jq -r '.album')
    discNumber=$(echo "$track" | jq -r '.discNumber')
    trackNumber=$(echo "$track" | jq -r '.trackNumber')
    artist=$(echo "$track" | jq -r '.artists')
    name=$(echo "$track" | jq -r '.name')
    
    if [ -z "$discNumber" ] || [ -z "$trackNumber" ] || [ -z "$artist" ] || [ -z "$name" ] || [ -z "$trackFilePath" ] || [ -z "$albumArtFilePath" ]; then
        echo "✗ ERROR: Missing required fields for track processing"
        continue
    fi
    
    if [ ! -f "$trackFilePath" ]; then
        echo "✗ MISSING: $trackFilePath"
        continue
    fi
    
    if [ ! -f "$albumArtFilePath" ]; then
        echo "✗ MISSING: $albumArtFilePath"
        continue
    fi
    
    inputDir=$(dirname "$trackFilePath")
    fileExtension="${trackFilePath##*.}"
    outputDir="${inputDir}/output"
    
    mkdir -p "$outputDir"
    
    ffmpeg -i "$trackFilePath" \
           -i "$albumArtFilePath" \
           -vf scale=300:300 \
           -c:v png \
           -map 0:a \
           -map 1 \
           -disposition:v:0 attached_pic \
           -map_metadata -1 \
           -metadata album="$album" \
           -metadata disc="$discNumber" \
           -metadata track="$trackNumber" \
           -metadata artist="$artist" \
           -metadata title="$name" \
           -y "$outputDir/$artist - $name.$fileExtension"
done
```

- `-vf scale=300:300` scale the album art to 300x300 pixels

- `-c:v png` use PNG codec for album art

- `-map 0:a` drop the original album art

- `-map 1` bring in a new album art

- `-disposition:v:0 attached_pic` set the first video stream as an album art

- `-map_metadata -1` drop the original metadata

- `-metadata` set new metadata

  