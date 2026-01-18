#!/usr/bin/env bash
set -euo pipefail

# Main deployment wrapper - uses the complete deployment script
if [ -x "./deploy-full-clean.sh" ]; then
  exec ./deploy-full-clean.sh "$@"
else
  echo "⚠️ deploy-full-clean.sh is missing or not executable. Run: chmod +x deploy-full-clean.sh"
  exit 1
fi