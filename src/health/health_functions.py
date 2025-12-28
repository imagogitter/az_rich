"""Health check functions for Kubernetes-style probes."""

import json
import logging
import os
import time
from datetime import datetime
from typing import Dict, Any

import aiohttp
import azure.functions as func
from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

logger = logging.getLogger(__name__)

# Cache for health check results
_health_cache: Dict[str, Any] = {}
_cache_ttl = 10  # seconds


async def check_keyvault() -> Dict[str, Any]:
    """Check Key Vault connectivity."""
    try:
        kv_name = os.environ.get("KEY_VAULT_NAME")
        if not kv_name:
            return {"status": "skip", "message": "KEY_VAULT_NAME not set"}

        start = time.time()
        credential = DefaultAzureCredential()
        client = SecretClient(vault_url=f"https://{kv_name}.vault.azure.net", credential=credential)
        # Try to list secrets (lightweight operation)
        list(client.list_properties_of_secrets(max_page_size=1))
        latency_ms = int((time.time() - start) * 1000)
        return {"status": "healthy", "latency_ms": latency_ms}
    except Exception as e:
        logger.error(f"Key Vault health check failed: {e}")
        return {"status": "unhealthy", "error": str(e)}


async def check_cosmos() -> Dict[str, Any]:
    """Check Cosmos DB connectivity."""
    try:
        cosmos_account = os.environ.get("COSMOS_ACCOUNT")
        if not cosmos_account:
            return {"status": "skip", "message": "COSMOS_ACCOUNT not set"}

        start = time.time()
        credential = DefaultAzureCredential()

        # Test actual connection by checking if account is accessible
        client = CosmosClient(url=f"https://{cosmos_account}.documents.azure.com:443/", credential=credential)
        # List databases (lightweight operation to verify connectivity)
        list(client.list_databases())
        latency_ms = int((time.time() - start) * 1000)
        return {"status": "healthy", "latency_ms": latency_ms}
    except Exception as e:
        logger.error(f"Cosmos DB health check failed: {e}")
        return {"status": "unhealthy", "error": str(e)}


async def check_inference_backend() -> Dict[str, Any]:
    """Check inference backend availability."""
    try:
        vmss_name = os.environ.get("VMSS_NAME")
        if not vmss_name:
            return {"status": "skip", "message": "VMSS_NAME not set"}

        # Build the backend health endpoint URL
        backend_url = f"http://{vmss_name}.internal:8080/health"

        start = time.time()
        async with aiohttp.ClientSession() as session:
            async with session.get(backend_url, timeout=aiohttp.ClientTimeout(total=5)) as response:
                if response.status == 200:
                    data = await response.json()
                    latency_ms = int((time.time() - start) * 1000)
                    return {"status": "healthy", "instances": data.get("instances", 0), "latency_ms": latency_ms}
                else:
                    return {"status": "unhealthy", "error": f"Backend returned {response.status}"}
    except Exception as e:
        logger.error(f"Inference backend health check failed: {e}")
        # If backend is not available, mark as degraded (not unhealthy)
        # since the service can still function without active GPU instances
        return {"status": "degraded", "error": str(e), "instances": 0}


def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    Health check endpoint supporting:
    - /health/live - Liveness probe (is the service running?)
    - /health/ready - Readiness probe (is the service ready to accept traffic?)
    - /health/startup - Startup probe (has the service started?)
    """
    check_type = req.route_params.get("check_type", "live")

    response = {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "version": os.environ.get("WEBSITE_INSTANCE_ID", "local"),
        "checks": {},
    }

    status_code = 200

    if check_type == "live":
        # Liveness: Just check if the function is responding
        response["checks"]["self"] = {"status": "healthy"}

    elif check_type == "ready":
        # Readiness: Check all dependencies
        import asyncio

        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

        try:
            # Run health checks
            kv_result = loop.run_until_complete(check_keyvault())
            cosmos_result = loop.run_until_complete(check_cosmos())
            backend_result = loop.run_until_complete(check_inference_backend())

            response["checks"] = {"keyvault": kv_result, "cosmos": cosmos_result, "inference_backend": backend_result}

            # Determine overall status
            unhealthy = [k for k, v in response["checks"].items() if v.get("status") == "unhealthy"]

            if unhealthy:
                response["status"] = "unhealthy"
                status_code = 503
            elif any(v.get("status") == "degraded" for v in response["checks"].values()):
                response["status"] = "degraded"
                status_code = 200

        finally:
            loop.close()

    elif check_type == "startup":
        # Startup: Check if initial setup is complete
        response["checks"]["initialization"] = {"status": "healthy"}

    else:
        return func.HttpResponse(
            json.dumps({"error": f"Unknown check type: {check_type}"}), status_code=400, mimetype="application/json"
        )

    return func.HttpResponse(
        json.dumps(response, indent=2),
        status_code=status_code,
        mimetype="application/json",
        headers={"Cache-Control": "no-cache, no-store, must-revalidate", "X-Health-Check": check_type},
    )
