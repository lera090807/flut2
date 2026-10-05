#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
exec flutter run -d chrome --web-hostname localhost --web-port 5555 --dart-define=API_BASE_URL=http://localhost:8080/api
