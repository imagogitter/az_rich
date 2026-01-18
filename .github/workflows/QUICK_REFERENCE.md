# Quick Reference: Terraform Deployment Workflow

## Setup Checklist

### 1. Create Azure Service Principal
```bash
az ad sp create-for-rbac \
  --name "github-actions-terraform" \
  --role Contributor \
  --scopes /subscriptions/{YOUR_SUBSCRIPTION_ID} \
  --sdk-auth
```

### 2. Add GitHub Secrets
Go to: Repository Settings → Secrets and variables → Actions → New repository secret

Add these 4 secrets:
- [ ] `AZURE_CLIENT_ID`
- [ ] `AZURE_CLIENT_SECRET`
- [ ] `AZURE_TENANT_ID`
- [ ] `AZURE_SUBSCRIPTION_ID`

### 3. Configure Environment Protection
Go to: Repository Settings → Environments

1. Click "New environment"
2. Name: `production`
3. Check "Required reviewers"
4. Add reviewers (e.g., your team)
5. Save protection rules

### 4. Test the Workflow

**Option A: Test with PR (plan only)**
```bash
git checkout -b test-terraform-workflow
git commit --allow-empty -m "Test workflow"
git push origin test-terraform-workflow
# Create PR to main on GitHub
# Check PR for plan comment
```

**Option B: Test deployment (plan + apply)**
```bash
# Merge PR to main or push directly
git checkout main
git push origin main
# Wait for approval in Actions tab
# Approve and verify deployment
```

## Quick Commands

### View Workflow Runs
```bash
# Using GitHub CLI
gh run list --workflow=terraform-deploy.yml

# View specific run
gh run view <run-id>
```

### Troubleshooting

**Init fails?**
- Verify Azure secrets are correct
- Check backend storage account exists
- Ensure service principal has access

**Validate fails?**
- Run `terraform validate` locally
- Fix syntax errors
- Push changes

**Plan fails?**
- Review error in workflow logs
- Check resource configurations
- Verify required variables

**Apply stuck?**
- Check Actions tab for approval button
- Click "Review deployments"
- Approve or reject

## Workflow Files

| File | Purpose |
|------|---------|
| `.github/workflows/terraform-deploy.yml` | Main workflow |
| `.github/workflows/TERRAFORM_DEPLOYMENT.md` | Full documentation |
| `IMPLEMENTATION_SUMMARY.md` | Implementation details |

## Support

For detailed information, see:
- [Full Documentation](.github/workflows/TERRAFORM_DEPLOYMENT.md)
- [Implementation Summary](IMPLEMENTATION_SUMMARY.md)

## Common Scenarios

### Scenario 1: Deploy to production
1. Create PR with Terraform changes
2. Review plan in PR comments
3. Merge PR to main
4. Wait for approval notification
5. Approve in Actions tab
6. Verify deployment in Azure Portal

### Scenario 2: Emergency rollback
1. Revert commit in main branch
2. Wait for approval
3. Approve rollback
4. Verify in Azure Portal

### Scenario 3: Skip deployment
1. Close/reject approval request
2. Make fixes in new PR
3. Repeat deployment process

## Important Notes

- ⚠️ Always review plan output before approving
- 🔒 Never commit secrets to repository
- 📝 Plan artifacts expire after 5 days
- 💾 Output artifacts kept for 30 days
- 🔄 Workflow uses Terraform 1.5.0
- 🌍 Working directory is `terraform/`

## Workflow Behavior

| Event | Action | Result |
|-------|--------|--------|
| Push to main | Plan + Apply | Waits for approval |
| PR to main | Plan only | Comments on PR |
| PR updated | Plan only | Updates comment |
| Other branches | Nothing | No action |
