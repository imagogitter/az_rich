#!/usr/bin/env bash
set -euo pipefail

# Safe wrapper for deployment — uses the cleaned full script `deploy-full-clean.sh`.
if [ -x "./deploy-full-clean.sh" ]; then
  exec ./deploy-full-clean.sh "$@"
else
  echo "⚠️ deploy-full-clean.sh is missing or not executable. Inspect 'deploy-full-clean.sh' and run: chmod +x deploy-full-clean.sh"
  exit 1
fi