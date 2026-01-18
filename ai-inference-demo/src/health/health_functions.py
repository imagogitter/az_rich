"""Health check endpoints."""

import json
import azure.functions as func
from datetime import datetime


def main(req: func.HttpRequest) -> func.HttpResponse:
    check_type = req.route_params.get("check_type", "live")

    response = {"status": "healthy", "timestamp": datetime.utcnow().isoformat() + "Z"}

    return func.HttpResponse(
        json.dumps(response), status_code=200, mimetype="application/json"
    )
