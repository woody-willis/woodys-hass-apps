#!/bin/sh
# Translate Home Assistant app options into MeTube environment variables,
# then hand over to the upstream entrypoint (which runs as PUID/PGID).
set -eu

OPTIONS=/data/options.json

opt() {
    jq -r --arg k "$1" '.[$k] // empty' "$OPTIONS"
}

fail() {
    echo "[metube addon] $*" >&2
    exit 1
}

PUID="$(opt puid)"
PGID="$(opt pgid)"
DOWNLOAD_DIR="$(opt download_dir)"
AUDIO_DOWNLOAD_DIR="$(opt audio_download_dir)"
TEMP_DIR="$(opt temp_dir)"
MAX_CONCURRENT_DOWNLOADS="$(opt max_concurrent_downloads)"
OUTPUT_TEMPLATE="$(opt output_template)"
DEFAULT_THEME="$(opt default_theme)"
LOGLEVEL="$(opt log_level)"
YTDL_OPTIONS="$(opt ytdl_options)"
YTDL_NIGHTLY_UPDATE_TIME="$(opt ytdl_nightly_update_time)"

[ -n "$DOWNLOAD_DIR" ] || fail "download_dir is required"

export PUID="${PUID:-0}" PGID="${PGID:-0}"

# MeTube listens on this port; Supervisor's ingress proxy forwards to it.
export HOST=0.0.0.0 PORT=8081

# Persistent queue, history, subscriptions and cookies live in /data so they
# are included in Home Assistant backups.
export DOWNLOAD_DIR
export STATE_DIR=/data/metube

# Audio and temp folders follow DOWNLOAD_DIR unless set. Assigning them
# explicitly also clears the image's /downloads defaults.
AUDIO_DOWNLOAD_DIR="${AUDIO_DOWNLOAD_DIR:-$DOWNLOAD_DIR}"
TEMP_DIR="${TEMP_DIR:-$DOWNLOAD_DIR}"
export AUDIO_DOWNLOAD_DIR TEMP_DIR

[ -z "$MAX_CONCURRENT_DOWNLOADS" ] || export MAX_CONCURRENT_DOWNLOADS
[ -z "$OUTPUT_TEMPLATE" ] || export OUTPUT_TEMPLATE
[ -z "$DEFAULT_THEME" ] || export DEFAULT_THEME
[ -z "$LOGLEVEL" ] || export LOGLEVEL

if [ -n "$YTDL_OPTIONS" ]; then
    echo "$YTDL_OPTIONS" | jq -e 'type == "object"' >/dev/null 2>&1 \
        || fail 'ytdl_options must be a JSON object, e.g. {"writesubtitles": true}'
    export YTDL_OPTIONS
fi

[ -z "$YTDL_NIGHTLY_UPDATE_TIME" ] || export YTDL_NIGHTLY_UPDATE_TIME

# Create the directories and give their top level to PUID:PGID without
# recursively chowning a media library. Upstream's own chown is disabled
# because it recurses into every mapped download folder.
for dir in "$DOWNLOAD_DIR" "$AUDIO_DOWNLOAD_DIR" "$TEMP_DIR" "$STATE_DIR"; do
    mkdir -p "$dir"
    chown "$PUID:$PGID" "$dir"
done
export CHOWN_DIRS=false

exec /usr/bin/tini -g -- /app/docker-entrypoint.sh
