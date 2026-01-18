#!/usr/bin/env bash
set -euo pipefail

# Main deployment script wrapper - deploys infrastructure
if [ ! -f "./deploy-infrastructure.sh" ]; then
  echo "⚠️ deploy-infrastructure.sh not found."
  exit 1
elif [ ! -x "./deploy-infrastructure.sh" ]; then
  echo "⚠️ deploy-infrastructure.sh is not executable."
  echo "Run: chmod +x deploy-infrastructure.sh"
  exit 1
fi

exec ./deploy-infrastructure.sh "$@"