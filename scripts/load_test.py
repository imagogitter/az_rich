#!/usr/bin/env python3
"""
Load testing script for AI Inference Platform
Uses locust for distributed load testing
"""

import json
import os
from locust import HttpUser, task, between
from locust_plugins.csv import CSVReader


class AIInferenceUser(HttpUser):
    """Load test user for AI inference API"""

    wait_time = between(1, 3)  # Random wait between 1-3 seconds

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.api_key = os.environ.get("API_KEY", "test-key")
        self.base_url = os.environ.get("API_BASE_URL", "http://localhost:7071/api")

    @task(3)  # 60% of requests
    def chat_completion_simple(self):
        """Test simple chat completion"""
        payload = {
            "model": "phi-3-mini",
            "messages": [{"role": "user", "content": "Hello, how are you?"}],
            "max_tokens": 50,
            "temperature": 0.7,
        }

        with self.client.post(
            "/v1/chat/completions",
            json=payload,
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            catch_response=True,
        ) as response:
            if response.status_code == 200:
                response.success()
            elif response.status_code == 429:
                response.success()  # Rate limited is expected under load
            else:
                response.failure(f"Unexpected status: {response.status_code}")

    @task(2)  # 40% of requests
    def chat_completion_complex(self):
        """Test complex chat completion"""
        payload = {
            "model": "auto",
            "messages": [
                {"role": "system", "content": "You are a helpful assistant."},
                {
                    "role": "user",
                    "content": "Write a Python function to calculate fibonacci numbers.",
                },
            ],
            "max_tokens": 200,
            "temperature": 0.8,
        }

        with self.client.post(
            "/v1/chat/completions",
            json=payload,
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            catch_response=True,
        ) as response:
            if response.status_code in [200, 429]:
                response.success()
            else:
                response.failure(f"Unexpected status: {response.status_code}")

    @task(1)  # 20% of requests
    def list_models(self):
        """Test models listing"""
        with self.client.get(
            "/v1/models",
            headers={"Authorization": f"Bearer {self.api_key}"},
            catch_response=True,
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Unexpected status: {response.status_code}")

    @task(1)  # 20% of requests
    def health_check(self):
        """Test health endpoints"""
        endpoints = ["/health/live", "/health/ready", "/health/startup"]

        for endpoint in endpoints:
            with self.client.get(endpoint, catch_response=True) as response:
                if response.status_code in [
                    200,
                    503,
                ]:  # 503 is acceptable for readiness
                    response.success()
                else:
                    response.failure(f"Health check failed: {response.status_code}")


if __name__ == "__main__":
    # For local testing
    import locust.main

    locust.main.main()
