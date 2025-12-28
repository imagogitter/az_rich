import pytest
import os

@pytest.fixture
def mock_env(monkeypatch):
    monkeypatch.setenv("KEY_VAULT_NAME", "test")
    monkeypatch.setenv("COSMOS_ACCOUNT", "test")
