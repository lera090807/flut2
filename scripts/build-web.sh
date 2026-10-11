#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
flutter build web --release "$@"
python3 tool/prepare_web.py build/web
