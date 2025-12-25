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

# Check if an argument was provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

TRACKS_JSON=<path to tracks.json>

# Check if the file exists
if [ ! -f "$TRACKS_JSON" ]; then
    echo "Error: File '$TRACKS_JSON' not found."
    exit 1
fi

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

> [!TIP]
>
> - `-vf scale=300:300` scale the album art to 300x300 pixels
>
> - `-c:v png` use PNG codec for album art
>
> - `-map 0:a` drop the original album art
>
> - `-map 1` bring in a new album art
>
> - `-disposition:v:0 attached_pic` set the first video stream as an album art
>
> - `-map_metadata -1` drop the original metadata
>
> - `-metadata` set new metadata
>

> [!NOTE]
>
> ```shell
> $ ./replace-meta-data.sh /path/to/tracks.json
> ```






# Save video stream

##### sample `m3u8_list.txt`

```
https://some.domain.com/path/to/index.m3u8
```


##### batch process

```shell
#!/bin/bash

# Check if an argument was provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

INPUT_FILE="$1"

# Check if the file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found."
    exit 1
fi

# Determine the directory of the input file
INPUT_DIR="$(cd "$(dirname "$INPUT_FILE")" && pwd)"

# Hardcode output directory to the input file's directory
OUTPUT_DIR="$INPUT_DIR/downloads"
mkdir -p "$OUTPUT_DIR"

count=0

while IFS= read -r url; do
    [ -z "$url" ] && continue

    count=$((count + 1))

    # Format as two digits: 01, 02, 03...
    filename="$(printf "%02d" "$count").mp4"
    filepath="$OUTPUT_DIR/$filename"

    # Skip if file already exists
    if [ -f "$filepath" ]; then
        echo "Skipping #$count — already exists: $filename"
        echo "--------------------------------"
        continue
    fi

    echo "Downloading #$count: $url"
    ffmpeg -nostdin -y -i "$url" -c copy "$filepath"

    echo "Saved as: $filepath"
    echo "--------------------------------"
done < "$INPUT_FILE"

```

> [!NOTE]
>
> ```shell
> $ nohup ./save-video-stream.sh /path/to/m3u8_list.txt > output.log 2>&1 &
> ```