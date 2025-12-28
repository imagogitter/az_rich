#!/usr/bin/env bash
set -euo pipefail

if [ -x "./deploy-marketing-full.sh" ]; then
  exec ./deploy-marketing-full.sh "$@"
else
  echo "⚠️ deploy-marketing-full.sh is missing or not executable. Inspect and chmod +x deploy-marketing-full.sh"
  exit 1
fi