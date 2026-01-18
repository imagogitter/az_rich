import json
from unittest.mock import Mock
from src.models_list.main import main as models_main, MODELS


def test_models_list_endpoint():
    """Test models list returns all available models."""
    req = Mock()

    resp = models_main(req)

    assert resp.status_code == 200
    data = json.loads(resp.get_body())
    assert data["object"] == "list"
    assert len(data["data"]) == len(MODELS)

    # Check model structure
    model = data["data"][0]
    assert "id" in model
    assert "object" in model
    assert "created" in model
    assert "owned_by" in model
    assert "context_length" in model
    assert "pricing" in model
