# Load Testing Guide

This directory contains load testing scripts for the AI Inference Platform.

## Prerequisites

```bash
pip install -r scripts/requirements-test.txt
```

## Running Load Tests

### Local Testing

```bash
# Install dependencies
pip install -r scripts/requirements-test.txt

# Set environment variables
export API_BASE_URL="http://localhost:7071/api"
export API_KEY="your-test-key"

# Run locust web interface
locust -f scripts/load_test.py --host=$API_BASE_URL

# Open http://localhost:8089 for web interface
```

### Distributed Testing

```bash
# Start master
locust -f scripts/load_test.py --master --host=$API_BASE_URL

# Start workers (on different machines)
locust -f scripts/load_test.py --worker --master-host=localhost
```

### Command Line Testing

```bash
# Run for 60 seconds with 10 users
locust -f scripts/load_test.py --no-web -c 10 -r 2 --run-time 60s --host=$API_BASE_URL
```

## Test Scenarios

- **Simple Chat**: 60% of requests - Basic conversations with phi-3-mini
- **Complex Chat**: 40% of requests - Technical queries with auto model selection
- **Model Listing**: 20% of requests - GET /v1/models
- **Health Checks**: 20% of requests - All health endpoints

## Performance Targets

- Response time < 5 seconds (P95)
- Error rate < 1%
- Throughput: 100+ requests/minute
- Cache hit rate > 40%

## Monitoring

During load tests, monitor:

- Azure Functions metrics
- Cosmos DB RU consumption
- VMSS scaling events
- Application Insights telemetry

## CI/CD Integration

Load tests can be run in CI:

```yaml
- name: Load Test
  run: |
    pip install -r scripts/requirements-test.txt
    locust -f scripts/load_test.py --no-web -c 5 -r 1 --run-time 30s --host=$API_BASE_URL