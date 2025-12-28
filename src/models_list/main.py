"""List available models endpoint."""

import json
import time
import azure.functions as func

MODELS = [
    {
        "id": "mixtral-8x7b",
        "object": "model",
        "created": 1700000000,
        "owned_by": "mistralai",
        "context_length": 32768,
        "pricing": {"prompt": 0.002, "completion": 0.002}
    },
    {
        "id": "llama-3-70b",
        "object": "model",
        "created": 1700000000,
        "owned_by": "meta",
        "context_length": 8192,
        "pricing": {"prompt": 0.003, "completion": 0.003}
    },
    {
        "id": "phi-3-mini",
        "object": "model",
        "created": 1700000000,
        "owned_by": "microsoft",
        "context_length": 4096,
        "pricing": {"prompt": 0.0005, "completion": 0.0005}
    }
]

def main(req: func.HttpRequest) -> func.HttpResponse:
    return func.HttpResponse(
        json.dumps({
            "object": "list",
            "data": MODELS
        }),
        status_code=200,
        mimetype="application/json"
    )