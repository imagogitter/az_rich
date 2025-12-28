#!/usr/bin/env bash
set -euo pipefail

if [ -x "./deploy-marketing-full-clean.sh" ]; then
  exec ./deploy-marketing-full-clean.sh "$@"
else
  echo "⚠️ deploy-marketing-full-clean.sh is missing or not executable. Inspect and chmod +x deploy-marketing-full-clean.sh"
  exit 1
fi