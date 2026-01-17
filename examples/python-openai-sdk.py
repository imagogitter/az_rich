#!/usr/bin/env python3
"""
Example: Using the AI Inference Platform with OpenAI SDK

This example demonstrates how to connect to the AI Inference Platform
and make chat completion requests using the OpenAI Python SDK.
"""

import os
from openai import OpenAI

# Configuration
# Get these values from connection-details.txt or run ./setup-frontend-complete.sh
API_KEY = os.environ.get("OPENAI_API_KEY", "your-api-key-here")
BASE_URL = os.environ.get("OPENAI_API_BASE", "https://your-app.azurewebsites.net/api/v1")

# Initialize client
client = OpenAI(
    api_key=API_KEY,
    base_url=BASE_URL
)


def example_simple_chat():
    """Simple chat completion example"""
    print("=== Simple Chat Example ===\n")
    
    response = client.chat.completions.create(
        model="mixtral-8x7b",
        messages=[
            {"role": "user", "content": "What is the capital of France?"}
        ],
        temperature=0.7,
        max_tokens=256
    )
    
    print(f"Response: {response.choices[0].message.content}\n")
    print(f"Tokens used: {response.usage.total_tokens}")
    print(f"Model: {response.model}\n")


def example_system_prompt():
    """Chat with system prompt"""
    print("=== System Prompt Example ===\n")
    
    response = client.chat.completions.create(
        model="llama-3-70b",
        messages=[
            {"role": "system", "content": "You are a helpful Python programming assistant."},
            {"role": "user", "content": "Write a function to calculate fibonacci numbers"}
        ],
        temperature=0.5,
        max_tokens=512
    )
    
    print(f"Response:\n{response.choices[0].message.content}\n")


def example_multi_turn():
    """Multi-turn conversation"""
    print("=== Multi-turn Conversation Example ===\n")
    
    messages = [
        {"role": "system", "content": "You are a helpful coding assistant."}
    ]
    
    # First message
    messages.append({"role": "user", "content": "Write a Python function to sort a list"})
    response = client.chat.completions.create(
        model="mixtral-8x7b",
        messages=messages,
        temperature=0.7,
        max_tokens=512
    )
    
    assistant_response = response.choices[0].message.content
    messages.append({"role": "assistant", "content": assistant_response})
    print(f"Assistant: {assistant_response}\n")
    
    # Follow-up message
    messages.append({"role": "user", "content": "Now add error handling to that function"})
    response = client.chat.completions.create(
        model="mixtral-8x7b",
        messages=messages,
        temperature=0.7,
        max_tokens=512
    )
    
    print(f"Assistant: {response.choices[0].message.content}\n")


def example_streaming():
    """Streaming response example"""
    print("=== Streaming Example ===\n")
    
    print("Assistant: ", end="", flush=True)
    
    response = client.chat.completions.create(
        model="phi-3-mini",
        messages=[
            {"role": "user", "content": "Tell me a short story about a robot"}
        ],
        temperature=0.8,
        max_tokens=256,
        stream=True
    )
    
    for chunk in response:
        if chunk.choices[0].delta.content:
            print(chunk.choices[0].delta.content, end="", flush=True)
    
    print("\n")


def example_different_models():
    """Compare responses from different models"""
    print("=== Model Comparison Example ===\n")
    
    question = "Explain recursion in programming in one sentence."
    
    for model in ["phi-3-mini", "mixtral-8x7b", "llama-3-70b"]:
        print(f"\nModel: {model}")
        print("-" * 50)
        
        response = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": question}],
            temperature=0.7,
            max_tokens=100
        )
        
        print(response.choices[0].message.content)


def example_list_models():
    """List available models"""
    print("=== Available Models ===\n")
    
    models = client.models.list()
    
    for model in models.data:
        print(f"ID: {model.id}")
        print(f"  Owner: {model.owned_by}")
        if hasattr(model, 'context_length'):
            print(f"  Context: {model.context_length} tokens")
        print()


def main():
    """Run all examples"""
    
    print("=" * 70)
    print("AI Inference Platform - Python Examples")
    print("=" * 70)
    print()
    
    try:
        # Check configuration
        if not API_KEY or API_KEY.strip() == '' or API_KEY == "your-api-key-here":
            print("ERROR: Please set your API key!")
            print("Set environment variables:")
            print("  export OPENAI_API_KEY='your-key'")
            print("  export OPENAI_API_BASE='your-base-url'")
            print()
            print("Or get them from: ./setup-frontend-complete.sh")
            return
        
        # Run examples
        example_list_models()
        example_simple_chat()
        example_system_prompt()
        example_multi_turn()
        example_streaming()
        example_different_models()
        
        print("\n" + "=" * 70)
        print("All examples completed successfully!")
        print("=" * 70)
        
    except Exception as e:
        print(f"\nError: {e}")
        print("\nMake sure:")
        print("1. The backend is deployed (./deploy.sh)")
        print("2. Your API key is correct")
        print("3. The base URL is correct")


if __name__ == "__main__":
    main()
