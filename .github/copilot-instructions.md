# Copilot Instructions for az_rich

## Project Overview

This is an AI inference arbitrage platform built on Azure Functions that resells GPU-based AI inference with 200-300% margins using Azure spot instances. The platform provides OpenAI-compatible API endpoints for chat completions with intelligent model routing, caching, and cost optimization.

## Technology Stack

- **Runtime**: Python 3.11
- **Platform**: Azure Functions (consumption tier)
- **Infrastructure**: Azure (Terraform & Bicep)
- **Caching**: Azure Cosmos DB (serverless)
- **Secrets**: Azure Key Vault
- **CI/CD**: GitHub Actions
- **Models**: Llama-3-70B, Mixtral 8x7B, Phi-3-mini

## Architecture

- **API Layer**: Azure API Management (consumption tier)
- **Compute**: VM Scale Sets with Spot priority (80% discount)
- **Orchestration**: Azure Functions with health checks
- **Caching**: 40% cache hit rate with Cosmos DB
- **Failover**: <30s spot preemption failover

## Code Organization

```
src/
├── api_orchestrator/    # Main chat completions API handler
├── health/             # Health check endpoints (liveness/readiness)
├── models_list/        # Model listing endpoint
├── requirements.txt    # Python dependencies
└── host.json          # Azure Functions configuration

terraform/              # Infrastructure as Code (Terraform)
scripts/               # Utility scripts (deployment, load testing)
tests/                 # Test suite (pytest)
frontend/              # Open WebUI container application
docs/                  # Additional documentation
```

## Development Commands

### Setup
```bash
# Install dependencies
pip install -r src/requirements.txt
pip install pytest pytest-cov pytest-asyncio black flake8 mypy
```

### Linting & Formatting
```bash
# Format code
black src

# Lint
flake8 src --count --select=E9,F63,F7,F82 --show-source --statistics
flake8 src --count --exit-zero --max-complexity=10 --max-line-length=120 --statistics

# Type checking
mypy src --ignore-missing-imports
```

### Testing
```bash
# Run tests (when available)
pytest tests -v --cov=src --cov-report=xml
```

### Deployment
```bash
# Deploy via script (recommended)
./setup-frontend-complete.sh

# Or deploy infrastructure only
cd terraform && terraform init && terraform apply
```

## Coding Standards

### Python Style
- Follow PEP 8 conventions
- Use Black for code formatting (max line length: 120)
- Maximum complexity: 10 (enforced by flake8)
- Type hints preferred (checked with mypy, errors non-blocking)
- Docstrings required for all public functions

### Code Patterns
- **Singletons**: Use for shared resources (SecretsManager, CacheManager)
- **Async/Await**: Use for I/O operations (cache, secrets, HTTP)
- **Error Handling**: Always log exceptions before returning error responses
- **Secrets**: Never hardcode secrets; use Azure Key Vault via SecretsManager
- **Caching**: Use cache_manager for response caching with TTL
- **Health Checks**: Support Kubernetes-style probes (liveness, readiness, startup)

### Azure Functions Conventions
- Use `func.HttpRequest` and `func.HttpResponse` types
- Set appropriate HTTP status codes and headers
- Include `X-Request-ID` header for request tracing
- Return JSON with proper `mimetype="application/json"`
- Use structured logging with the logger module

### API Standards
- OpenAI-compatible API format for chat completions
- Support streaming and non-streaming responses
- Include performance metadata in response headers:
  - `X-Request-ID`: Request tracking
  - `X-Cache`: Cache hit/miss status
  - `X-Model`: Selected model
  - `X-Duration-Ms`: Request duration

## Testing Guidelines

- Test files should be placed in `tests/` directory
- Use pytest as the test framework
- Follow naming convention: `test_*.py`
- Use async test fixtures when testing async functions
- Mock external dependencies (Azure services, HTTP calls)

## Security Practices

- Use Azure Managed Identity for authentication
- Store all secrets in Azure Key Vault
- Never commit `.env` files or credentials
- Validate all user inputs before processing
- Set appropriate CORS policies
- Use HTTPS for all external communications

## Infrastructure

- Prefer Terraform for infrastructure changes
- Use Spot instances for cost optimization
- Configure auto-scaling (0-20 GPU instances)
- Set up health check endpoints for monitoring
- Use consumption tier for serverless components

## Common Patterns

### Secrets Management
```python
# SecretsManager is a singleton defined in api_orchestrator/main.py
secrets_manager = SecretsManager()
api_key = secrets_manager.get_secret("api-key")
```

### Response Caching
```python
# CacheManager is a singleton defined in api_orchestrator/main.py
cache_manager = CacheManager()
cached = await cache_manager.get_cached_response(request)
```

### Error Responses
```python
return func.HttpResponse(
    json.dumps({"error": {"code": "error_code", "message": "Description"}}),
    status_code=400,
    mimetype="application/json"
)
```

## CI/CD

- CI runs on push to `main` and `develop` branches
- PRs to `main` trigger CI checks
- All code must pass: flake8, black format check, and tests
- Mypy type checking is informational (continue-on-error: true)
- Three main workflows:
  - `ci.yml`: Lint, format, and test on every push/PR
  - `terraform-deploy.yml`: Terraform infrastructure deployment (main branch only)
  - `full-deployment.yml`: Complete deployment with infrastructure, functions, and frontend
  - `frontend-deploy.yml`: Frontend-only deployment

## Notes

- The platform targets 40% cache hit rate for cost efficiency
- Spot instances provide 80% cost savings but can be preempted
- Model routing is automatic based on context length requirements
- Health checks follow Kubernetes probe patterns for compatibility
