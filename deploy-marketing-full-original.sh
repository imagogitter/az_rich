#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="ai-arbitrage-marketing"
RESOURCE_GROUP="${PROJECT_NAME}-marketing-rg"
LOCATION="${LOCATION:-eastus}"

log() { echo -e "\033[1;34m[MARKETING] *\033[0m"; } warn() { echo -e "\033[1;33m[WARNING] *\033[0m" >&2; }

load_env() {
  if [[ -f .env ]]; then
    source .env
  fi
}

deploy_github_prospector() {
  log "Deploying GitHub Prospector bot..."

  read -p "Enter GitHub Personal Access Token: " GITHUB_TOKEN
  read -p "Enter Crunchbase API Key: " CRUNCHBASE_API_KEY
  read -p "Enter Hunter.io API Key: " HUNTER_API_KEY

  # Create container instance
  az container create \
      --name "${PROJECT_NAME}-gh-prospector" \
      --resource-group "${RESOURCE_GROUP}" \
      --image "python:3.11-slim" \
      --command-line "bash -c 'pip install requests pandas && python /app/prospector.py'" \
      --environment-variables \
          GITHUB_TOKEN="${GITHUB_TOKEN}" \
          CRUNCHBASE_API_KEY="${CRUNCHBASE_API_KEY}" \
          HUNTER_API_KEY="${HUNTER_API_KEY}" \
      --restart-policy OnFailure \
      --cpu 1 --memory 2 \
      --location "${LOCATION}" \
      --tags project="${PROJECT_NAME}" automation="github-prospector"

  # Generate prospector script
  cat > scripts/prospector.py <<'PYEOF'
import os, requests, csv
from datetime import datetime, timedelta


def get_github_leads():
    headers = {'Authorization': f'token {os.environ["GITHUB_TOKEN"]}'}
    query = "openai language:python pushed:>2024-01-01"
    url = f"https://api.github.com/search/repositories?q={query}"

    repos = requests.get(url, headers=headers).json().get('items', [])[:1000]
    leads = []

    for repo in repos:
        # Get contributors
        contrib_url = repo.get('contributors_url')
        contributors = requests.get(contrib_url, headers=headers).json()[:3]
        
        for dev in contributors:
            # Enrich email
            email = requests.get(
                f"https://api.hunter.io/v2/email-finder",
                params={"domain": "github.com", "first_name": dev.get('login')},
                headers={"api_key": os.environ.get("HUNTER_API_KEY","")}
            ).json().get('data', {}).get('email', '')
            
            if email:
                leads.append({
                    "name": dev.get('login'),
                    "email": email,
                    "repo": repo.get('name'),
                    "stars": repo.get('stargazers_count'),
                    "last_active": repo.get('updated_at')
                })

    # Save leads
    if leads:
        with open('/output/leads.csv', 'w') as f:
            writer = csv.DictWriter(f, fieldnames=leads[0].keys())
            writer.writeheader()
            writer.writerows(leads)

    print(f"✅ Generated {len(leads)} leads")


if __name__ == "__main__":
    get_github_leads()
PYEOF

  log "GitHub Prospector deployed"
}

deploy_cost_calculator() {
  log "Deploying cost calculator..."

  az staticwebapp create \
      --name "${PROJECT_NAME}-calculator" \
      --resource-group "${RESOURCE_GROUP}" \
      --location "${LOCATION}" \
      --sku Free \
      --tags project="${PROJECT_NAME}" lead-gen="calculator"

  cat > calculator.html <<'HTMLOF'
<!DOCTYPE html>
<html>
<head>
  <title>AI API Cost Calculator - Save 50%</title>
  <style>
    body { font-family: Arial; max-width: 800px; margin: 0 auto; padding: 40px; }
    input[type="file"] { margin: 20px 0; }
    #savings { font-size: 2em; color: #00aa00; margin: 30px 0; }
    .cta-button { background: #00aa00; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; }
  </style>
</head>
<body>
  <h1>Cut Your AI API Costs by 50%</h1>
  <p>Upload your OpenAI usage JSON to see instant savings:</p>
  <input type="file" id="bill" accept=".json">
  <div id="savings"></div>
  <script>
    document.getElementById('bill').onchange = function(e) {
      const reader = new FileReader();
      reader.onload = function() {
        const data = JSON.parse(reader.result);
        const monthly_cost = data.total_usage || 0;
        const savings = monthly_cost * 0.5;
        document.getElementById('savings').innerHTML = `<h2>You'd save $${savings.toFixed(2)}/month</h2> <a href="https://${APIM_NAME}.azure-api.net/signup" class="cta-button">Get Free API Key</a>`;
      };
      reader.readAsText(e.target.files[0]);
    }
  </script>
</body>
</html>
HTMLOF

  log "Cost calculator deployed"
}

setup_sendgrid() {
  log "Setting up SendGrid email automation..."

  read -p "Enter SendGrid API Key: " SENDGRID_API_KEY

  curl -X POST "https://api.sendgrid.com/v3/marketing/singlesends" \
      -H "Authorization: Bearer ${SENDGRID_API_KEY}" \
      -H "Content-Type: application/json" \
      -d @- <<'JSONEOF'
{
  "name": "AI API Value Prop",
  "email_config": {
    "subject": "Cut your AI API costs by 50% (same quality)",
    "html_content": "<p>Hi {{first_name}},</p><p>I saw you're using OpenAI. Our API is 2x cheaper with identical performance.</p><p>1M free tokens: <a href='{{signup_url}}'>Get Started</a></p>",
    "plain_content": "Hi {{first_name}}, Cut AI costs 50%: {{signup_url}}"
  }
}
JSONEOF

  log "SendGrid sequences configured"
}

setup_reddit() {
  log "Setting up Reddit automation..."

  read -p "Enter Reddit Client ID: " REDDIT_CLIENT_ID
  read -p "Enter Reddit Client Secret: " REDDIT_SECRET

  cat > .github/workflows/reddit-strike.yml <<'YAMLOF'
name: Reddit Precision Strike
on:
  schedule:
    - cron: '0 */6 * * *' # Every 6 hours
jobs:
  strike:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - run: pip install praw
      - run: python scripts/reddit_bot.py
      env:
        REDDIT_CLIENT_ID: ${{ secrets.REDDIT_CLIENT_ID }}
        REDDIT_SECRET: ${{ secrets.REDDIT_SECRET }}
        APIM_NAME: ${{ secrets.APIM_NAME }}
YAMLOF

  cat > scripts/reddit_bot.py <<'PYEOF'
import praw, os, time

reddit = praw.Reddit(
    client_id=os.environ['REDDIT_CLIENT_ID'],
    client_secret=os.environ['REDDIT_SECRET'],
    user_agent="AI Cost Bot 1.0"
)

for submission in reddit.subreddit("MachineLearning+OpenAI+LocalLLaMA").hot(limit=50):
    if any(kw in submission.title.lower() for kw in ["api cost", "expensive", "rate limit"]):
        comment = f"""
🔥 We built an API that's 50% cheaper than OpenAI with Mixtral-8x7B
Free tier (no CC): https://{os.environ.get('APIM_NAME')}.azure-api.net/signup
"""
        try:
            submission.reply(comment)
        except Exception:
            pass
        time.sleep(600) # Rate limit
PYEOF

  log "Reddit automation configured"
}

main() {
  log "=== Deploying Marketing Automation ==="

  load_env

  if ! az group show --name "${RESOURCE_GROUP}" &> /dev/null; then
    az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --tags project="${PROJECT_NAME}" component="marketing"
  fi

  deploy_github_prospector
  deploy_cost_calculator
  setup_sendgrid
  setup_reddit

  log "=== Marketing Engine Ready ==="
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
