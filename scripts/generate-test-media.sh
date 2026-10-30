#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v ffmpeg >/dev/null 2>&1 || brew install ffmpeg
mkdir -p Tests/Fixtures UITests/Fixtures
# Synthetic media owned by this project: opening red second, followed by a blue second.
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i 'color=c=red:s=160x90:r=15:d=1' \
  -f lavfi -i 'color=c=blue:s=160x90:r=15:d=1' \
  -filter_complex '[0:v][1:v]concat=n=2:v=1:a=0,format=yuv420p[v]' -map '[v]' \
  -c:v libx264 -preset ultrafast -movflags +faststart Tests/Fixtures/first-frame.mp4
ffmpeg -hide_banner -loglevel error -y -i Tests/Fixtures/first-frame.mp4 -c copy Tests/Fixtures/first-frame.mkv

# A larger opening-frame fixture verifies the featured cover stays sharp but bounded.
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i 'color=c=red:s=1280x720:r=15:d=1' \
  -f lavfi -i 'color=c=blue:s=1280x720:r=15:d=1' \
  -filter_complex '[0:v][1:v]concat=n=2:v=1:a=0,format=yuv420p[v]' -map '[v]' \
  -c:v libx264 -preset ultrafast -movflags +faststart Tests/Fixtures/first-frame-large.mp4

# Long enough for real hide/reveal, rotation and background UI interactions.
ffmpeg -hide_banner -loglevel error -y -f lavfi -i 'testsrc2=s=320x180:r=15:d=45' \
  -f lavfi -i 'anullsrc=r=48000:cl=stereo' -t 45 \
  -c:v libx264 -preset ultrafast -crf 30 -pix_fmt yuv420p -c:a aac -b:a 64k \
  -movflags +faststart UITests/Fixtures/ui-preview.mp4
