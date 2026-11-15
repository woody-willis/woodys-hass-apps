#!/bin/sh
# Translate Home Assistant app options into MeTube environment variables,
# then hand over to the upstream entrypoint (which runs as PUID/PGID).
set -eu

OPTIONS=/data/options.json

opt() {
    jq -r --arg k "$1" '.[$k] // empty' "$OPTIONS"
}

trim() {
    printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

fail() {
    echo "[metube addon] $*" >&2
    exit 1
}

# Only /media and /share are mounted by this app, so anything else would be
# written inside the container and lost on restart.
require_mounted_dir() {
    case "$2" in
        /media|/media/*|/share|/share/*) ;;
        *) fail "$1 must be under /media or /share (got '$2')" ;;
    esac
}

# Normalize an optional download folder. Relative paths are resolved against
# DOWNLOAD_DIR, and the upstream image's /downloads prefix is treated as an
# alias for DOWNLOAD_DIR so Docker-style paths keep working.
resolve_optional_dir() {
    name="$1"
    value="$(trim "$2")"
    if [ -z "$value" ]; then
        printf '%s' "$DOWNLOAD_DIR"
        return 0
    fi
    case "$value" in
        /downloads) value="$DOWNLOAD_DIR" ;;
        /downloads/*) value="$DOWNLOAD_DIR/${value#/downloads/}" ;;
        /*) ;;
        *) value="$DOWNLOAD_DIR/$value" ;;
    esac
    require_mounted_dir "$name" "$value"
    printf '%s' "$value"
}

PUID="$(opt puid)"
PGID="$(opt pgid)"
DOWNLOAD_DIR="$(trim "$(opt download_dir)")"
MAX_CONCURRENT_DOWNLOADS="$(opt max_concurrent_downloads)"
OUTPUT_TEMPLATE="$(opt output_template)"
DEFAULT_THEME="$(opt default_theme)"
LOGLEVEL="$(opt log_level)"
YTDL_OPTIONS="$(opt ytdl_options)"
YTDL_NIGHTLY_UPDATE_TIME="$(opt ytdl_nightly_update_time)"

[ -n "$DOWNLOAD_DIR" ] || fail "download_dir is required"
require_mounted_dir download_dir "$DOWNLOAD_DIR"

# Audio and temp folders follow DOWNLOAD_DIR unless set. Assigning them
# explicitly also clears the image's /downloads defaults.
AUDIO_DOWNLOAD_DIR="$(resolve_optional_dir audio_download_dir "$(opt audio_download_dir)")"
TEMP_DIR="$(resolve_optional_dir temp_dir "$(opt temp_dir)")"

# Persistent queue, history, subscriptions and cookies live in /data so they
# are included in Home Assistant backups.
STATE_DIR=/data/metube

export PUID="${PUID:-0}" PGID="${PGID:-0}"

# MeTube listens on this port; Supervisor's ingress proxy forwards to it.
export HOST=0.0.0.0 PORT=8081

export DOWNLOAD_DIR AUDIO_DOWNLOAD_DIR TEMP_DIR STATE_DIR

echo "[metube addon] download dir: $DOWNLOAD_DIR"
echo "[metube addon] audio dir:    $AUDIO_DOWNLOAD_DIR"
echo "[metube addon] temp dir:     $TEMP_DIR"
echo "[metube addon] state dir:    $STATE_DIR"

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
