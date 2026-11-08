#!/bin/sh
# Translate Home Assistant app options into TorBoxarr environment variables,
# then hand over to the upstream entrypoint (which handles PUID/PGID).
set -eu

OPTIONS=/data/options.json

opt() {
    jq -r --arg k "$1" '.[$k] // empty' "$OPTIONS"
}

fail() {
    echo "[torboxarr addon] $*" >&2
    exit 1
}

TORBOXARR_TORBOX_API_TOKEN="$(opt torbox_api_token)"
TORBOXARR_QBIT_PASSWORD="$(opt qbit_password)"
TORBOXARR_SAB_API_KEY="$(opt sab_api_key)"

[ -n "$TORBOXARR_TORBOX_API_TOKEN" ] || fail "torbox_api_token is required"
[ -n "$TORBOXARR_QBIT_PASSWORD" ] || fail "qbit_password is required"
[ -n "$TORBOXARR_SAB_API_KEY" ] || fail "sab_api_key is required"

TORBOXARR_DATA_ROOT="$(opt data_root)"
TORBOXARR_LOG_LEVEL="$(opt log_level)"
PUID="$(opt puid)"
PGID="$(opt pgid)"

export TORBOXARR_TORBOX_API_TOKEN TORBOXARR_QBIT_PASSWORD TORBOXARR_SAB_API_KEY
export TORBOXARR_DATA_ROOT TORBOXARR_LOG_LEVEL
export PUID="${PUID:-0}" PGID="${PGID:-0}"

# Optional values: only export when set so upstream defaults apply.
v="$(opt sab_nzb_key)";        [ -z "$v" ] || export TORBOXARR_SAB_NZB_KEY="$v"
v="$(opt server_base_url)";    [ -z "$v" ] || export TORBOXARR_SERVER_BASE_URL="$v"

# /data is the app's persistent storage; keep the SQLite DB there.
export TORBOXARR_DATABASE_PATH=/data/torboxarr.db

mkdir -p "$TORBOXARR_DATA_ROOT"
# Top level only (not recursive) so existing media isn't touched.
chown "$PUID:$PGID" "$TORBOXARR_DATA_ROOT"

# The upstream entrypoint only chowns /config, so point it at /data.
rm -rf /config
ln -s /data /config

# Turn upstream's JSON log lines into readable text:
#   09:03:36 INFO  starting torboxarr version=1.0.5
# Non-JSON lines (e.g. goose) pass through unchanged.
FORMAT='
. as $line | (try ($line | fromjson) catch $line) |
if type == "object" and has("msg") then
  ((.time // "")[11:19]) + " " + (((.level // "INFO") + "     ")[0:5]) + " " + .msg
  + (del(.time, .level, .msg) | to_entries
     | map(" " + .key + "=" + (.value | if type == "string" then . else tojson end))
     | join(""))
else . end'

FIFO=/tmp/torboxarr.log
rm -f "$FIFO"
mkfifo "$FIFO"
jq -R -r --unbuffered "$FORMAT" < "$FIFO" &
fmt_pid=$!

/entrypoint.sh > "$FIFO" 2>&1 &
app_pid=$!

# Forward stop signals so the app shuts down gracefully.
trap 'kill -TERM "$app_pid" 2>/dev/null || true' TERM INT
wait "$app_pid" || true
trap - TERM INT
wait "$app_pid" 2>/dev/null
status=$?
wait "$fmt_pid" 2>/dev/null || true
exit "$status"
