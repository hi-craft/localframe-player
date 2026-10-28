#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v ffmpeg >/dev/null 2>&1 || brew install ffmpeg
mkdir -p Tests/Fixtures
# Synthetic media owned by this project: opening red second, followed by a blue second.
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i 'color=c=red:s=160x90:r=15:d=1' \
  -f lavfi -i 'color=c=blue:s=160x90:r=15:d=1' \
  -filter_complex '[0:v][1:v]concat=n=2:v=1:a=0,format=yuv420p[v]' -map '[v]' \
  -c:v libx264 -preset ultrafast -movflags +faststart Tests/Fixtures/first-frame.mp4
ffmpeg -hide_banner -loglevel error -y -i Tests/Fixtures/first-frame.mp4 -c copy Tests/Fixtures/first-frame.mkv
