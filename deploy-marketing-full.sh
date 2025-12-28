#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="ai-arbitrage-marketing"
RESOURCE_GROUP="${PROJECT_NAME}-marketing-rg"
LOCATION="${LOCATION:-eastus}"
TAGS="project=${PROJECT_NAME} component=marketing"

log() { echo -e "[MARKETING] $*"; }
error() { echo -e "[ERROR] $*" >&2; exit 1; }

load_env() {
  if [[ -f .env ]]; then
    source .env
  fi
}

deploy_prospector() {
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
  log "Prospector script generated"
}

deploy_calculator() {
  mkdir -p marketing
  cat > marketing/calculator.html <<'HTML'
<!doctype html>
<html>
  <head><meta charset="utf-8"><title>AI Cost Calculator</title></head>
  <body>
    <h1>AI Cost Calculator</h1>
    <p>Upload billing JSON to estimate savings.</p>
  </body>
</html>
HTML
  log "Calculator generated: marketing/calculator.html"
}

main() {
  load_env

  # Ensure marketing resource group exists
  if ! az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --tags "$TAGS"
    log "Created resource group $RESOURCE_GROUP"
  else
    log "Resource group $RESOURCE_GROUP already exists"
  fi

  deploy_prospector
  deploy_calculator
  log "Marketing components created locally"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
