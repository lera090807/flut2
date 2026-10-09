#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if command -v node >/dev/null 2>&1; then
  exec node api/mock-server.js --port 8080 --origin http://localhost:5555 "$@"
fi
for runtime in .tools/node-*/bin/node; do
  if [ -x "$runtime" ]; then exec "$runtime" api/mock-server.js --port 8080 --origin http://localhost:5555 "$@"; fi
done
printf '%s\n' 'Нужен Node.js 18+: https://nodejs.org/' >&2
exit 1
