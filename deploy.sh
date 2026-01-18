#!/usr/bin/env bash
set -euo pipefail

# Main deployment script wrapper - deploys infrastructure
if [ -x "./deploy-infrastructure.sh" ]; then
  exec ./deploy-infrastructure.sh "$@"
else
  echo "⚠️ deploy-infrastructure.sh is missing or not executable."
  echo "Run: chmod +x deploy-infrastructure.sh"
  exit 1
fi