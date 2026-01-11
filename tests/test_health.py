import json
import pytest
from unittest.mock import patch, Mock
from src.health.health_functions import main as health_main


def test_health_live_check(mock_env):
    """Test liveness probe returns healthy."""
    req = Mock()
    req.route_params = {"check_type": "live"}

    resp = health_main(req)

    assert resp.status_code == 200
    data = json.loads(resp.get_body())
    assert data["status"] == "healthy"
    assert "self" in data["checks"]


def test_health_ready_check(mock_env):
    """Test readiness probe checks dependencies."""
    req = Mock()
    req.route_params = {"check_type": "ready"}

    with patch('src.health.health_functions.check_keyvault') as mock_kv, \
         patch('src.health.health_functions.check_cosmos') as mock_cosmos, \
         patch('src.health.health_functions.check_inference_backend') as mock_backend:

        # Make the async functions return values directly for sync testing
        kv_result = {"status": "healthy"}
        cosmos_result = {"status": "healthy"}
        backend_result = {"status": "healthy"}

        mock_kv.return_value = kv_result
        mock_cosmos.return_value = cosmos_result
        mock_backend.return_value = backend_result

        # Mock the asyncio parts to return the mock results
        with patch('asyncio.new_event_loop') as mock_new_loop, \
             patch('asyncio.set_event_loop') as mock_set_loop:

            mock_loop = Mock()
            mock_new_loop.return_value = mock_loop
            mock_loop.run_until_complete.side_effect = [kv_result, cosmos_result, backend_result]

            resp = health_main(req)

            assert resp.status_code == 200
            data = json.loads(resp.get_body())
            assert data["status"] == "healthy"
            assert "keyvault" in data["checks"]
            assert "cosmos" in data["checks"]
            assert "inference_backend" in data["checks"]


def test_health_startup_check(mock_env):
    """Test startup probe returns healthy."""
    req = Mock()
    req.route_params = {"check_type": "startup"}

    resp = health_main(req)

    assert resp.status_code == 200
    data = json.loads(resp.get_body())
    assert data["status"] == "healthy"
    assert "initialization" in data["checks"]


def test_health_unknown_check_type(mock_env):
    """Test unknown check type returns 400."""
    req = Mock()
    req.route_params = {"check_type": "unknown"}

    resp = health_main(req)

    assert resp.status_code == 400
    data = json.loads(resp.get_body())
    assert "error" in data