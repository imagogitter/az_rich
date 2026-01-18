# Deployment Fix Verification Checklist

## Pre-Merge Verification

### Code Quality
- [x] YAML syntax validated
- [x] No linting errors
- [x] Code review completed (0 issues)
- [x] Git history clean and well-documented

### Documentation
- [x] DEPLOYMENT_GUIDE.md created (comprehensive)
- [x] DEPLOYMENT_FIX_SUMMARY.md created (technical details)
- [x] PR_SUMMARY.md created (overview)
- [x] Comments added to code changes
- [x] Backward compatibility confirmed

### Changes Review
- [x] terraform/main.tf - backend block removed
- [x] full-deployment.yml - state management fixed
- [x] State restoration added
- [x] Environment-specific artifacts
- [x] Error handling improved
- [x] No breaking changes

## Post-Merge Verification

### Phase 1: Dev Environment Test
```bash
# Test 1: First deployment
gh workflow run full-deployment.yml -f environment=dev
```
- [ ] Workflow completes successfully
- [ ] All jobs pass (validate, lint, deploy-infrastructure, deploy-functions, deploy-frontend, get-details, verify)
- [ ] State artifact created: `terraform-state-dev`
- [ ] Deployment details artifact created
- [ ] Resources created in Azure (check portal)

```bash
# Test 2: Idempotency check (no changes)
gh workflow run full-deployment.yml -f environment=dev
```
- [ ] Workflow completes successfully
- [ ] Terraform plan shows "No changes"
- [ ] Terraform apply reports "Apply complete! Resources: 0 added, 0 changed, 0 destroyed"
- [ ] State artifact updated
- [ ] No resource recreation in Azure

```bash
# Test 3: Update existing deployment
# Make a small change (e.g., add a tag in terraform)
git checkout -b test-update
# Edit terraform/main.tf - add tag
git commit -am "test: add tag for idempotency test"
git push
gh workflow run full-deployment.yml -f environment=dev
```
- [ ] Workflow completes successfully
- [ ] Only changed resources updated
- [ ] Existing resources unchanged
- [ ] State properly updated

### Phase 2: Multiple Environment Test
```bash
# Deploy to staging
gh workflow run full-deployment.yml -f environment=staging
```
- [ ] Separate state artifact created: `terraform-state-staging`
- [ ] Resources created in different resource group
- [ ] No conflicts with dev environment
- [ ] Independent deployment successful

```bash
# Verify dev still works
gh workflow run full-deployment.yml -f environment=dev
```
- [ ] Dev environment unaffected
- [ ] Uses correct state artifact
- [ ] No cross-environment issues

### Phase 3: State Artifact Verification
- [ ] Download `terraform-state-dev` artifact
- [ ] Verify contains: terraform.tfstate
- [ ] Verify contains: terraform.tfstate.backup
- [ ] Verify contains: .terraform.lock.hcl
- [ ] Check artifact size is reasonable (not corrupted)
- [ ] Verify 90-day retention policy set

### Phase 4: Deployment Details Verification
- [ ] Download `deployment-details` artifact
- [ ] Contains: deployment-details.txt
- [ ] Contains: deployment-details.json
- [ ] Contains: DEPLOYMENT-INFO.md
- [ ] Contains: deployment-summary.md
- [ ] Contains: api-credentials.txt (if applicable)
- [ ] All information accurate and complete

### Phase 5: Job Dependencies
- [ ] deploy-functions job gets correct function_app_name from deploy-infrastructure
- [ ] deploy-frontend job gets correct container_registry_name from deploy-infrastructure
- [ ] get-deployment-details job downloads state successfully
- [ ] verify-deployment job can access all terraform outputs

### Phase 6: Error Handling
```bash
# Test with invalid credentials (temporarily)
# This should fail gracefully
gh workflow run full-deployment.yml -f environment=dev
```
- [ ] Fails with clear error message
- [ ] No partial state corruption
- [ ] Can recover on next run with valid credentials

### Phase 7: Azure Resources Verification
Login to Azure Portal and verify:
- [ ] Resource group created with correct naming
- [ ] Function App deployed and running
- [ ] Container App deployed and running
- [ ] Key Vault created with secrets
- [ ] Storage account created
- [ ] Cosmos DB created
- [ ] Container Registry created
- [ ] VMSS created (if applicable)
- [ ] All resources properly tagged

### Phase 8: API Testing
```bash
# Get Function App URL from deployment details
FUNCTION_APP_URL=$(cat deployment-details.json | jq -r '.endpoints.function_app_url')

# Test health endpoints
curl $FUNCTION_APP_URL/api/health/live
curl $FUNCTION_APP_URL/api/health/ready

# Get API key from Key Vault
KEY_VAULT_NAME=$(cat deployment-details.json | jq -r '.authentication.key_vault_name')
API_KEY=$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name frontend-openai-api-key --query value -o tsv)

# Test chat completions
curl -X POST "$FUNCTION_APP_URL/api/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "mixtral-8x7b",
    "messages": [{"role": "user", "content": "Hello, test deployment"}],
    "max_tokens": 50
  }'
```
- [ ] Health endpoints return 200 OK
- [ ] Chat completions API works
- [ ] API key retrieved successfully
- [ ] Response is valid JSON

### Phase 9: Frontend Verification
```bash
# Get Frontend URL from deployment details
FRONTEND_URL=$(cat deployment-details.json | jq -r '.endpoints.frontend_url')

# Test frontend
curl -I $FRONTEND_URL
```
- [ ] Frontend accessible via HTTPS
- [ ] Returns 200 OK
- [ ] Can load UI in browser
- [ ] Can create admin account

### Phase 10: Production Readiness
- [ ] All dev/staging tests passed
- [ ] Documentation reviewed by team
- [ ] Monitoring/alerting configured
- [ ] Cost tracking enabled
- [ ] Security review completed
- [ ] Backup strategy documented
- [ ] Disaster recovery plan in place

```bash
# Final production deployment
gh workflow run full-deployment.yml -f environment=prod
```
- [ ] Production deployment successful
- [ ] All verification steps pass in prod
- [ ] Monitoring alerts working
- [ ] Production environment stable

## Issue Reporting

If any checks fail:
1. Document the failure in detail
2. Check workflow logs for specific errors
3. Review DEPLOYMENT_GUIDE.md troubleshooting section
4. Open an issue with reproduction steps
5. Roll back if necessary

## Success Criteria

All items checked = **VERIFIED AND PRODUCTION READY** ✅

## Sign-Off

- [ ] Developer verification complete
- [ ] QA verification complete
- [ ] DevOps review complete
- [ ] Documentation reviewed
- [ ] Production deployment successful

---

**Date:** _________________  
**Verified by:** _________________  
**Notes:** _________________
