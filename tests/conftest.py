import pytest
import os
from unittest.mock import Mock, patch


@pytest.fixture
def mock_env():
    """Mock environment variables for testing."""
    env_vars = {
        "KEY_VAULT_NAME": "test-kv",
        "COSMOS_ACCOUNT": "test-cosmos",
        "VMSS_NAME": "test-vmss",
    }
    with patch.dict(os.environ, env_vars):
        yield


@pytest.fixture
def mock_request():
    """Mock Azure Functions HTTP request."""
    req = Mock()
    req.headers = {"X-Request-ID": "test-request-id"}
    req.get_json.return_value = {
        "model": "mixtral-8x7b",
        "messages": [{"role": "user", "content": "Hello"}],
        "temperature": 0.7,
        "max_tokens": 100,
    }
    return req


@pytest.fixture
def mock_response():
    """Mock Azure Functions HTTP response."""
    return Mock()
