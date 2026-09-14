#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$(id -u)" -eq 0 ]; then
  owner="$(stat -c '%U' "$DIR")"
  if [ -n "$owner" ] && [ "$owner" != "root" ] && command -v runuser >/dev/null 2>&1; then
    exec runuser -u "$owner" -- "$DIR/stop.sh" "$@"
  fi
fi

PID_FILE="$DIR/router.pid"

is_router_pid() {
  local pid="$1" fd exe script
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  [ -r "/proc/$pid/cmdline" ] || return 1
  exec {fd}<"/proc/$pid/cmdline" || return 1
  IFS= read -r -d '' exe <&"$fd" || true
  IFS= read -r -d '' script <&"$fd" || true
  exec {fd}<&-
  [ "${exe##*/}" = "node" ] && [ "$script" = "$DIR/server.mjs" ]
}

find_router_pid() {
  local file pid
  for file in /proc/[0-9]*/cmdline; do
    pid="${file#/proc/}"
    pid="${pid%/cmdline}"
    if is_router_pid "$pid"; then
      echo "$pid"
      return 0
    fi
  done
  return 1
}

PID=""
if [ -s "$PID_FILE" ]; then
  candidate="$(cat "$PID_FILE")"
  if is_router_pid "$candidate"; then
    PID="$candidate"
  fi
fi
if [ -z "$PID" ]; then
  PID="$(find_router_pid || true)"
fi
if [ -z "$PID" ]; then
  rm -f "$PID_FILE"
  echo "free-router is not running"
  exit 0
fi

echo "$PID" >"$PID_FILE"
kill "$PID"
for _ in {1..25}; do
  kill -0 "$PID" 2>/dev/null || break
  sleep 0.2
done
if kill -0 "$PID" 2>/dev/null; then
  echo "free-router did not stop gracefully; forcing shutdown" >&2
  kill -KILL "$PID"
  for _ in {1..10}; do
    kill -0 "$PID" 2>/dev/null || break
    sleep 0.1
  done
fi
if kill -0 "$PID" 2>/dev/null; then
  echo "failed to stop free-router (pid $PID)" >&2
  exit 1
fi
rm -f "$PID_FILE"
echo "free-router stopped"
