"""
Chat Completions API - OpenAI-compatible endpoint.
Routes requests to optimal inference backend based on model and load.
"""

import json
import logging
import os
import time
import hashlib
from datetime import datetime
from typing import Dict, Optional, List, Any

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from azure.cosmos import CosmosClient
import aiohttp

logger = logging.getLogger(__name__)

# Model configuration
MODELS = {
    "mixtral-8x7b": {
        "context_length": 32768,
        "price_per_1k_tokens": 0.002,
        "priority": 1,
    },
    "llama-3-70b": {
        "context_length": 8192,
        "price_per_1k_tokens": 0.003,
        "priority": 2,
    },
    "phi-3-mini": {
        "context_length": 4096,
        "price_per_1k_tokens": 0.0005,
        "priority": 0,
    },
}


def validate_chat_request(request: Dict[str, Any]) -> None:
    """Validate chat completion request parameters."""
    # Check messages
    messages = request.get("messages", [])
    if not isinstance(messages, list) or not messages:
        raise ValueError("messages must be a non-empty list")

    for i, msg in enumerate(messages):
        if not isinstance(msg, dict):
            raise ValueError(f"message {i} must be a dictionary")
        if "role" not in msg or "content" not in msg:
            raise ValueError(f"message {i} must have 'role' and 'content' fields")
        if msg["role"] not in ["system", "user", "assistant", "function"]:
            raise ValueError(f"message {i} has invalid role: {msg['role']}")
        if not isinstance(msg["content"], str):
            raise ValueError(f"message {i} content must be a string")

    # Check model
    model = request.get("model")
    if model and model not in MODELS and model != "auto":
        raise ValueError(f"model '{model}' is not supported")

    # Check numeric parameters
    temp = request.get("temperature", 1.0)
    if not isinstance(temp, (int, float)) or not (0.0 <= temp <= 2.0):
        raise ValueError("temperature must be between 0.0 and 2.0")

    max_tokens = request.get("max_tokens", 256)
    if not isinstance(max_tokens, int) or max_tokens < 1 or max_tokens > 4096:
        raise ValueError("max_tokens must be between 1 and 4096")

    top_p = request.get("top_p", 1.0)
    if not isinstance(top_p, (int, float)) or not (0.0 <= top_p <= 1.0):
        raise ValueError("top_p must be between 0.0 and 1.0")

    # Check token limits
    total_chars = sum(len(str(m.get("content", ""))) for m in messages)
    estimated_tokens = total_chars // 4
    selected_model = (
        model if model != "auto" else "mixtral-8x7b"
    )  # Default for validation
    max_context = MODELS.get(selected_model, MODELS["mixtral-8x7b"])["context_length"]

    if estimated_tokens > max_context:
        raise ValueError(
            f"estimated tokens ({estimated_tokens}) exceed model context length ({max_context})"
        )


class SecretsManager:
    """Manages secrets from Azure Key Vault with caching."""

    _instance = None
    _secrets_cache: Dict[str, str] = {}

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def _initialize(self):
        if not self._initialized:
            kv_name = os.environ.get("KEY_VAULT_NAME")
            if kv_name:
                credential = DefaultAzureCredential()
                vault_url = f"https://{kv_name}.vault.azure.net"
                self._client = SecretClient(vault_url=vault_url, credential=credential)
            else:
                self._client = None
            self._initialized = True

    def get_secret(self, name: str) -> Optional[str]:
        self._initialize()

        if name in self._secrets_cache:
            return self._secrets_cache[name]

        if self._client:
            try:
                secret = self._client.get_secret(name)
                self._secrets_cache[name] = secret.value
                return secret.value
            except Exception as e:
                logger.error(f"Failed to get secret {name}: {e}")

        return os.environ.get(name.upper().replace("-", "_"))


class CacheManager:
    """Manages response caching with Cosmos DB."""

    def __init__(self):
        self.cosmos_account = os.environ.get("COSMOS_ACCOUNT")
        self._client = None

    def _get_client(self):
        if self._client is None and self.cosmos_account:
            # In production, use managed identity
            credential = DefaultAzureCredential()
            self._client = CosmosClient(
                url=f"https://{self.cosmos_account}.documents.azure.com:443/",
                credential=credential,
            )
        return self._client

    def _generate_cache_key(self, request: Dict) -> str:
        """Generate deterministic cache key from request."""
        # Normalize request for caching - include all parameters that affect response
        cache_data = {
            "model": request.get("model"),
            "messages": request.get("messages"),
            "temperature": request.get("temperature", 1.0),
            "max_tokens": request.get("max_tokens", 256),
            "top_p": request.get("top_p", 1.0),
            "frequency_penalty": request.get("frequency_penalty", 0.0),
            "presence_penalty": request.get("presence_penalty", 0.0),
            "stop": request.get("stop"),
            "functions": request.get("functions"),  # For function calling
            "tools": request.get("tools"),  # For tool use
        }
        cache_str = json.dumps(cache_data, sort_keys=True, default=str)
        return hashlib.sha256(cache_str.encode()).hexdigest()[:32]

    async def get_cached_response(self, request: Dict) -> Optional[Dict]:
        """Try to get cached response."""
        try:
            client = self._get_client()
            if not client:
                return None

            cache_key = self._generate_cache_key(request)
            database = client.get_database_client("inferencecache")
            container = database.get_container_client("responses")

            try:
                partition_key = request.get("model", "default")
                item = container.read_item(item=cache_key, partition_key=partition_key)
                logger.info(f"Cache hit for key: {cache_key[:8]}...")
                return item.get("response")
            except Exception:
                return None

        except Exception as e:
            logger.warning(f"Cache lookup failed: {e}")
            return None

    async def set_cached_response(self, request: Dict, response: Dict):
        """Store response in cache."""
        try:
            client = self._get_client()
            if not client:
                return

            cache_key = self._generate_cache_key(request)
            database = client.get_database_client("inferencecache")
            container = database.get_container_client("responses")

            container.upsert_item(
                {
                    "id": cache_key,
                    "modelId": request.get("model", "default"),
                    "response": response,
                    "created_at": datetime.utcnow().isoformat(),
                    "ttl": 3600,  # 1 hour
                }
            )
            logger.info(f"Cached response for key: {cache_key[:8]}...")

        except Exception as e:
            logger.warning(f"Cache write failed: {e}")


class ModelRouter:
    """Routes requests to optimal model/backend."""

    def __init__(self):
        self.backends: Dict[str, List[str]] = {}

    def select_model(self, requested_model: str, messages: List[Dict]) -> str:
        """Select optimal model based on request characteristics."""
        if requested_model != "auto":
            return requested_model

        # Calculate token estimate and complexity
        total_chars = sum(len(m.get("content", "")) for m in messages)
        estimated_tokens = total_chars // 4

        # Analyze message complexity (presence of code, technical terms, etc.)
        complexity_score = 0
        technical_terms = [
            "function",
            "class",
            "import",
            "def",
            "api",
            "database",
            "algorithm",
        ]
        content_lower = " ".join(m.get("content", "").lower() for m in messages)

        for term in technical_terms:
            if term in content_lower:
                complexity_score += 1

        # Select model based on requirements
        if estimated_tokens > 4000 or complexity_score > 2:
            return "mixtral-8x7b"  # Best for complex, long contexts
        elif estimated_tokens > 2000 or complexity_score > 0:
            return "llama-3-70b"  # Good balance of capability and cost
        else:
            return "phi-3-mini"  # Fastest and cheapest for simple tasks

    def get_backend_url(self, model: str) -> str:
        """Get backend URL for model."""
        # In production, this would query VMSS for healthy instances
        vmss_name = os.environ.get("VMSS_NAME", "localhost")
        return f"http://{vmss_name}.internal:8080/v1/chat/completions"


# Initialize singletons
secrets_manager = SecretsManager()
cache_manager = CacheManager()
model_router = ModelRouter()


async def forward_to_backend(
    url: str, request: Dict, headers: Dict, max_retries: int = 3
) -> Dict:
    """Forward request to inference backend with retry logic."""
    import asyncio

    for attempt in range(max_retries):
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    url,
                    json=request,
                    headers=headers,
                    timeout=aiohttp.ClientTimeout(total=120),
                ) as response:
                    if response.status == 200:
                        return await response.json()
                    elif response.status >= 500:
                        # Retry on server errors
                        if attempt < max_retries - 1:
                            await asyncio.sleep(2**attempt)  # Exponential backoff
                            continue
                        else:
                            return await response.json()  # Return error response
                    else:
                        # Don't retry on client errors
                        return await response.json()
        except (aiohttp.ClientError, asyncio.TimeoutError) as e:
            if attempt < max_retries - 1:
                logger.warning(
                    f"Backend request failed (attempt {attempt + 1}/{max_retries}): {e}"
                )
                await asyncio.sleep(2**attempt)
                continue
            else:
                raise e

    raise Exception(f"Failed to forward request after {max_retries} attempts")


async def main(req: func.HttpRequest) -> func.HttpResponse:
    """Main handler for chat completions."""
    start_time = time.time()
    request_id = req.headers.get("X-Request-ID", f"req-{int(time.time()*1000)}")

    # Structured logging
    logger.info(
        "Request started",
        extra={
            "request_id": request_id,
            "method": req.method,
            "url": req.url,
            "user_agent": req.headers.get("User-Agent", "unknown"),
            "content_length": req.headers.get("Content-Length", 0),
        },
    )

    try:
        # Parse request
        try:
            body = req.get_json()
        except ValueError:
            error_msg = {
                "error": {
                    "code": "invalid_request",
                    "message": "Invalid JSON in request body",
                }
            }
            return func.HttpResponse(
                json.dumps(error_msg),
                status_code=400,
                mimetype="application/json",
            )

        # Validate request
        try:
            validate_chat_request(body)
        except ValueError as e:
            return func.HttpResponse(
                json.dumps({"error": {"code": "invalid_request", "message": str(e)}}),
                status_code=400,
                mimetype="application/json",
            )

        # Select model
        requested_model = body.get("model", "auto")
        selected_model = model_router.select_model(
            requested_model, body.get("messages", [])
        )
        body["model"] = selected_model

        logger.info(
            f"Model selected: {selected_model}",
            extra={
                "request_id": request_id,
                "requested_model": requested_model,
                "selected_model": selected_model,
                "message_count": len(body.get("messages", [])),
            },
        )

        # Check cache (for non-streaming requests)
        if not body.get("stream", False):
            cached = await cache_manager.get_cached_response(body)
            if cached:
                duration_ms = int((time.time() - start_time) * 1000)
                logger.info(
                    "Cache hit served",
                    extra={
                        "request_id": request_id,
                        "cache_hit": True,
                        "duration_ms": duration_ms,
                        "model": selected_model,
                    },
                )
                cached["_cached"] = True
                return func.HttpResponse(
                    json.dumps(cached),
                    status_code=200,
                    mimetype="application/json",
                    headers={
                        "X-Request-ID": request_id,
                        "X-Cache": "HIT",
                        "X-Model": selected_model,
                        "X-Duration-Ms": str(duration_ms),
                    },
                )

        # Forward to backend
        backend_url = model_router.get_backend_url(selected_model)
        internal_key = secrets_manager.get_secret("internal-service-key")

        headers = {"Authorization": f"Bearer {internal_key}"}
        response = await forward_to_backend(backend_url, body, headers)

        # Cache successful response
        if not body.get("stream", False):
            await cache_manager.set_cached_response(body, response)

        duration_ms = int((time.time() - start_time) * 1000)

        logger.info(
            "Request completed successfully",
            extra={
                "request_id": request_id,
                "cache_hit": False,
                "duration_ms": duration_ms,
                "model": selected_model,
                "status_code": 200,
            },
        )

        return func.HttpResponse(
            json.dumps(response),
            status_code=200,
            mimetype="application/json",
            headers={
                "X-Request-ID": request_id,
                "X-Cache": "MISS",
                "X-Model": selected_model,
                "X-Duration-Ms": str(duration_ms),
            },
        )

    except Exception as e:
        duration_ms = int((time.time() - start_time) * 1000)
        logger.error(
            "Request failed",
            extra={
                "request_id": request_id,
                "error": str(e),
                "duration_ms": duration_ms,
                "status_code": 500,
            },
            exc_info=True,
        )
        error_response = {
            "error": {
                "code": "internal_error",
                "message": "An internal error occurred",
                "request_id": request_id,
            }
        }
        return func.HttpResponse(
            json.dumps(error_response),
            status_code=500,
            mimetype="application/json",
        )
