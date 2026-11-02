#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v python3 >/dev/null 2>&1; then
  echo "Cần Python 3 để chạy công cụ build. Xem README.md."
  exit 1
fi
python3 scripts/builder_ui.py
