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
        with open('leads.csv', 'w') as f:
            writer = csv.DictWriter(f, fieldnames=leads[0].keys())
            writer.writeheader()
            writer.writerows(leads)

    print(f"✅ Generated {len(leads)} leads")


if __name__ == "__main__":
    get_github_leads()