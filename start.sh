#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$(id -u)" -eq 0 ]; then
  owner="$(stat -c '%U' "$DIR")"
  if [ -z "$owner" ] || [ "$owner" = "root" ]; then
    echo "refusing to start free-router as root" >&2
    exit 1
  fi
  if ! command -v runuser >/dev/null 2>&1; then
    echo "runuser is required to drop root; start as $owner instead" >&2
    exit 1
  fi
  exec runuser -u "$owner" -- "$DIR/start.sh" "$@"
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
  rm -f "$PID_FILE"
fi
if [ -z "$PID" ]; then
  PID="$(find_router_pid || true)"
fi
if [ -n "$PID" ]; then
  echo "$PID" >"$PID_FILE"
  echo "free-router already running (pid $PID)"
  exit 0
fi

load_env() {
  local file="$1"
  [ -f "$file" ] || return 0
  set -a
  # shellcheck disable=SC1090
  source "$file"
  set +a
}

load_env "${HOME}/.hermes/.env"
load_env "$DIR/.env"

nohup node "$DIR/server.mjs" >>"$DIR/router.log" 2>&1 &
PID=$!
echo "$PID" >"$PID_FILE"

for _ in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS "http://127.0.0.1:${FREE_ROUTER_PORT:-8787}/health" >/dev/null 2>&1; then
    echo "free-router started (pid $PID, user $(id -un))"
    echo "endpoint: http://127.0.0.1:${FREE_ROUTER_PORT:-8787}/v1"
    exit 0
  fi
  sleep 0.5
done

echo "router failed to become healthy; run: node server.mjs" >&2
exit 1
