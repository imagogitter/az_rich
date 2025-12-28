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
from typing import Dict, Any, Optional, List

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from azure.cosmos import CosmosClient
import aiohttp

logger = logging.getLogger(name)

# Model configuration
MODELS = {
    "mixtral-8x7b": {
        "context_length": 32768,
        "price_per_1k_tokens": 0.002,
        "priority": 1
    },
    "llama-3-70b": {
        "context_length": 8192,
        "price_per_1k_tokens": 0.003,
        "priority": 2
    },
    "phi-3-mini": {
        "context_length": 4096,
        "price_per_1k_tokens": 0.0005,
        "priority": 0
    }
}

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
                self._client = SecretClient(
                    vault_url=f"https://{kv_name}.vault.azure.net",
                    credential=credential
                )
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
                credential=credential
            )
        return self._client

    def _generate_cache_key(self, request: Dict) -> str:
        """Generate deterministic cache key from request."""
        # Normalize request for caching
        cache_data = {
            "model": request.get("model"),
            "messages": request.get("messages"),
            "temperature": request.get("temperature", 1.0),
            "max_tokens": request.get("max_tokens", 256)
        }
        return hashlib.sha256(
            json.dumps(cache_data, sort_keys=True).encode()
        ).hexdigest()[:32]

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
                item = container.read_item(
                    item=cache_key,
                    partition_key=request.get("model", "default")
                )
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
            
            container.upsert_item({
                "id": cache_key,
                "modelId": request.get("model", "default"),
                "response": response,
                "created_at": datetime.utcnow().isoformat(),
                "ttl": 3600  # 1 hour
            })
            logger.info(f"Cached response for key: {cache_key[:8]}...")
            
        except Exception as e:
            logger.warning(f"Cache write failed: {e}")

class ModelRouter:
    """Routes requests to optimal model/backend."""

    def __init__(self):
        self.backends: Dict[str, List[str]] = {}
        
    def select_model(self, requested_model: str, messages: List[Dict]) -> str:
        """Select optimal model based on request."""
        if requested_model != "auto":
            return requested_model
            
        # Calculate token estimate
        total_chars = sum(len(m.get("content", "")) for m in messages)
        estimated_tokens = total_chars // 4
        
        # Select based on context length needs
        if estimated_tokens > 4000:
            return "mixtral-8x7b"
        elif estimated_tokens > 2000:
            return "llama-3-70b"
        else:
            return "phi-3-mini"  # Cheapest for short prompts

    def get_backend_url(self, model: str) -> str:
        """Get backend URL for model."""
        # In production, this would query VMSS for healthy instances
        vmss_name = os.environ.get("VMSS_NAME", "localhost")
        return f"http://{vmss_name}.internal:8080/v1/chat/completions"

# Initialize singletons
secrets_manager = SecretsManager()
cache_manager = CacheManager()
model_router = ModelRouter()

async def forward_to_backend(url: str, request: Dict, headers: Dict) -> Dict:
    """Forward request to inference backend."""
    async with aiohttp.ClientSession() as session:
        async with session.post(
            url,
            json=request,
            headers=headers,
            timeout=aiohttp.ClientTimeout(total=120)
        ) as response:
            return await response.json()

def main(req: func.HttpRequest) -> func.HttpResponse:
    """Main handler for chat completions."""
    start_time = time.time()
    request_id = req.headers.get("X-Request-ID", f"req-{int(time.time()*1000)}")

    try:
        # Parse request
        try:
            body = req.get_json()
        except ValueError:
            return func.HttpResponse(
                json.dumps({
                    "error": {
                        "code": "invalid_request",
                        "message": "Invalid JSON in request body"
                    }
                }),
                status_code=400,
                mimetype="application/json"
            )
        
        # Validate required fields
        if "messages" not in body:
            return func.HttpResponse(
                json.dumps({
                    "error": {
                        "code": "invalid_request",
                        "message": "messages field is required"
                    }
                }),
                status_code=400,
                mimetype="application/json"
            )
        
        # Select model
        requested_model = body.get("model", "auto")
        selected_model = model_router.select_model(
            requested_model, 
            body.get("messages", [])
        )
        body["model"] = selected_model
        
        # Check cache (for non-streaming requests)
        if not body.get("stream", False):
            import asyncio
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            try:
                cached = loop.run_until_complete(
                    cache_manager.get_cached_response(body)
                )
                if cached:
                    cached["_cached"] = True
                    return func.HttpResponse(
                        json.dumps(cached),
                        status_code=200,
                        mimetype="application/json",
                        headers={
                            "X-Request-ID": request_id,
                            "X-Cache": "HIT",
                            "X-Model": selected_model,
                            "X-Duration-Ms": str(int((time.time() - start_time) * 1000))
                        }
                    )
            finally:
                loop.close()
        
        # Forward to backend
        backend_url = model_router.get_backend_url(selected_model)
        internal_key = secrets_manager.get_secret("internal-service-key")
        
        import asyncio
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            response = loop.run_until_complete(
                forward_to_backend(
                    backend_url,
                    body,
                    {"Authorization": f"Bearer {internal_key}"}
                )
            )
            
            # Cache successful response
            if not body.get("stream", False):
                loop.run_until_complete(
                    cache_manager.set_cached_response(body, response)
                )
                
        finally:
            loop.close()
        
        duration_ms = int((time.time() - start_time) * 1000)
        
        return func.HttpResponse(
            json.dumps(response),
            status_code=200,
            mimetype="application/json",
            headers={
                "X-Request-ID": request_id,
                "X-Cache": "MISS",
                "X-Model": selected_model,
                "X-Duration-Ms": str(duration_ms)
            }
        )
        
    except Exception as e:
        logger.exception(f"Request failed: {e}")
        return func.HttpResponse(
            json.dumps({
                "error": {
                    "code": "internal_error",
                    "message": "An internal error occurred",
                    "request_id": request_id
                }
            }),
            status_code=500,
            mimetype="application/json"
        )