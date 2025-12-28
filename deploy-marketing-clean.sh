#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="ai-arbitrage-marketing"
RESOURCE_GROUP="${PROJECT_NAME}-marketing-rg"
LOCATION="${LOCATION:-eastus}"

log() { echo -e "[MARKETING] $*"; }
error() { echo -e "[ERROR] $*" >&2; exit 1; }

load_env() {
  if [[ -f .env ]]; then
    source .env
  fi
}

deploy_prospector() {
  log "Writing static prospector script scripts/prospector.py"
  mkdir -p scripts
  cat > scripts/prospector.py <<'PY'
import os, requests, csv

def get_github_leads():
    headers = {'Authorization': f'token {os.environ.get("GITHUB_TOKEN", "") }'}
    query = "openai language:python pushed:>2024-01-01"
    url = f"https://api.github.com/search/repositories?q={query}"

    repos = requests.get(url, headers=headers).json().get('items', [])[:100]
    leads = []
    for repo in repos:
        leads.append({'repo': repo.get('full_name')})

    if leads:
        with open('leads.csv', 'w') as f:
            writer = csv.DictWriter(f, fieldnames=leads[0].keys())
            writer.writeheader()
            writer.writerows(leads)
    print('✅ Generated leads')

if __name__ == '__main__':
    get_github_leads()
PY
}

main() {
  load_env
  mkdir -p scripts
  deploy_prospector
  log "Marketing cleanup done (local scripts generated)."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
