#!/usr/bin/env sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DEFAULT_FLUTTER_BIN="$PROJECT_DIR/../.tooling/flutter/bin/flutter"
FLUTTER_BIN="${FLUTTER_BIN:-$DEFAULT_FLUTTER_BIN}"

HOST="${WEB_HOST:-0.0.0.0}"
PORT="${WEB_PORT:-8082}"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "Usage: ./run_web_vps.sh [host] [port]"
  echo ""
  echo "Defaults:"
  echo "  host: \$WEB_HOST or 0.0.0.0"
  echo "  port: \$WEB_PORT or 8082"
  echo ""
  echo "Overrides:"
  echo "  FLUTTER_BIN=/path/to/flutter ./run_web_vps.sh"
  exit 0
fi

if [ $# -ge 1 ]; then
  HOST="$1"
fi

if [ $# -ge 2 ]; then
  PORT="$2"
fi

if [ ! -x "$FLUTTER_BIN" ]; then
  echo "Flutter binary not found/executable at: $FLUTTER_BIN" >&2
  echo "Set FLUTTER_BIN or install Flutter at ../.tooling/flutter/bin/flutter" >&2
  exit 1
fi

cd "$PROJECT_DIR"

export FLUTTER_SUPPRESS_ANALYTICS=true
export DART_SUPPRESS_ANALYTICS=true
export PATH="$(dirname "$FLUTTER_BIN"):$PATH"

echo "Running members-2 web server on http://$HOST:$PORT"
echo "Using Flutter: $FLUTTER_BIN"

"$FLUTTER_BIN" config --enable-web >/dev/null

exec "$FLUTTER_BIN" run -d web-server \
  --web-hostname "$HOST" \
  --web-port "$PORT" \
  --web-server-debug-protocol=sse \
  --web-server-debug-backend-protocol=sse \
  --web-server-debug-injected-client-protocol=sse
