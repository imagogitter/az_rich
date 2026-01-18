import json
import pytest
from unittest.mock import patch, AsyncMock, Mock
from src.api_orchestrator.main import main as api_main


@pytest.mark.asyncio
async def test_api_valid_request(mock_request):
    """Test API handles valid chat completion request."""
    mock_response_data = {"choices": [{"message": {"content": "Hello"}}]}

    with patch("src.api_orchestrator.main.CacheManager") as mock_cache_class, patch(
        "src.api_orchestrator.main.ModelRouter"
    ) as mock_router_class, patch(
        "src.api_orchestrator.main.SecretsManager"
    ) as mock_secrets_class, patch(
        "src.api_orchestrator.main.forward_to_backend", new_callable=AsyncMock
    ) as mock_forward:

        # Setup mock instances
        mock_cache = mock_cache_class.return_value
        mock_cache.get_cached_response = AsyncMock(return_value=None)
        mock_cache.set_cached_response = AsyncMock()

        mock_router = mock_router_class.return_value
        mock_router.select_model.return_value = "mixtral-8x7b"
        mock_router.get_backend_url.return_value = (
            "http://backend:8080/v1/chat/completions"
        )

        mock_secrets = mock_secrets_class.return_value
        mock_secrets.get_secret.return_value = "test-key"

        mock_forward.return_value = mock_response_data

        resp = await api_main(mock_request)

        assert resp.status_code == 200
        data = json.loads(resp.get_body())
        assert data == mock_response_data
        assert resp.headers["X-Cache"] == "MISS"


@pytest.mark.asyncio
async def test_api_cached_response(mock_request):
    """Test API returns cached response when available."""
    cached_data = {"choices": [{"message": {"content": "Cached response"}}]}

    with patch("src.api_orchestrator.main.cache_manager") as mock_cache, patch(
        "src.api_orchestrator.main.model_router"
    ) as mock_router:

        mock_cache.get_cached_response = AsyncMock(return_value=cached_data)
        mock_router.select_model.return_value = "mixtral-8x7b"

        resp = await api_main(mock_request)

        assert resp.status_code == 200
        data = json.loads(resp.get_body())
        assert data["_cached"] is True
        assert resp.headers["X-Cache"] == "HIT"


@pytest.mark.asyncio
async def test_api_invalid_json():
    """Test API handles invalid JSON gracefully."""
    req = Mock()
    req.headers = {"X-Request-ID": "test-id"}
    req.get_json.side_effect = ValueError("Invalid JSON")

    resp = await api_main(req)

    assert resp.status_code == 400
    data = json.loads(resp.get_body())
    assert "invalid_request" in data["error"]["code"]


@pytest.mark.asyncio
async def test_api_missing_messages():
    """Test API validates required messages field."""
    req = Mock()
    req.headers = {"X-Request-ID": "test-id"}
    req.get_json.return_value = {"model": "test"}  # Missing messages

    resp = await api_main(req)

    assert resp.status_code == 400
    data = json.loads(resp.get_body())
    assert "messages must be a non-empty list" in data["error"]["message"]


@pytest.mark.asyncio
async def test_api_backend_error():
    """Test API handles backend errors gracefully."""
    req = Mock()
    req.headers = {"X-Request-ID": "test-id"}
    req.get_json.return_value = {"messages": [{"role": "user", "content": "Hello"}]}

    with patch("src.api_orchestrator.main.CacheManager") as mock_cache_class, patch(
        "src.api_orchestrator.main.ModelRouter"
    ) as mock_router_class, patch(
        "src.api_orchestrator.main.SecretsManager"
    ) as mock_secrets_class, patch(
        "src.api_orchestrator.main.forward_to_backend", new_callable=AsyncMock
    ) as mock_forward:

        mock_cache = mock_cache_class.return_value
        mock_cache.get_cached_response = AsyncMock(return_value=None)

        mock_router = mock_router_class.return_value
        mock_router.select_model.return_value = "mixtral-8x7b"
        mock_router.get_backend_url.return_value = (
            "http://backend:8080/v1/chat/completions"
        )

        mock_secrets = mock_secrets_class.return_value
        mock_secrets.get_secret.return_value = "test-key"

        mock_forward.side_effect = Exception("Backend error")

        resp = await api_main(req)

        assert resp.status_code == 500
        data = json.loads(resp.get_body())
        assert "internal_error" in data["error"]["code"]
