#!/usr/bin/env bash
# video-thumbs.sh FILE...: a small still from each video (about a tenth of the way in) for Drift's media tab, cached in
# ~/.cache/jellyface/video-thumbs/<md5 of the path>.jpg. Existing ones are kept; prints each path once its still exists.
# Runs at low priority, one video at a time.
set -uo pipefail
dir="${XDG_CACHE_HOME:-$HOME/.cache}/jellyface/video-thumbs"
mkdir -p "$dir"
command -v ffmpeg >/dev/null || exit 0
for f in "$@"; do
    out="$dir/$(printf '%s' "$f" | md5sum | cut -d' ' -f1).jpg"
    if [ ! -s "$out" ]; then
        len="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f" 2>/dev/null | cut -d. -f1)"
        at=$(( ${len:-0} > 0 ? len / 10 : 5 ))
        nice -n 15 timeout 20 ffmpeg -v error -nostdin -ss "$at" -i "$f" -frames:v 1 -vf "scale=288:-2" -q:v 4 -y "$out.tmp.jpg" 2>/dev/null &&
            mv -f "$out.tmp.jpg" "$out" || { rm -f "$out.tmp.jpg"; continue; }
    fi
    printf '%s\n' "$f"
done
