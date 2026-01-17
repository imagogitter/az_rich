#!/usr/bin/env bash
# 
# AI Inference Platform - cURL Examples
# 
# This script contains example cURL commands for testing the API.
# Set your connection details before running.
#

set -euo pipefail

# Configuration
# Get these values from connection-details.txt or run ./setup-frontend-complete.sh
API_KEY="${OPENAI_API_KEY:-your-api-key-here}"
BASE_URL="${OPENAI_API_BASE:-https://your-app.azurewebsites.net/api/v1}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

echo_command() {
    echo -e "${YELLOW}Command:${NC}"
    echo "$1"
    echo ""
}

# Check configuration
if [ "$API_KEY" = "your-api-key-here" ]; then
    echo "ERROR: Please set your API key!"
    echo ""
    echo "Set environment variables:"
    echo "  export OPENAI_API_KEY='your-key'"
    echo "  export OPENAI_API_BASE='your-base-url'"
    echo ""
    echo "Or get them from: ./setup-frontend-complete.sh"
    exit 1
fi

echo "======================================================================"
echo "           AI Inference Platform - cURL Examples"
echo "======================================================================"
echo ""
echo "Base URL: $BASE_URL"
echo "API Key:  ${API_KEY:0:20}..."
echo ""
echo "Note: The /health endpoint is public (no authentication required)."
echo "      All other endpoints require authentication with API key."
echo ""

# Example 1: Health Check (Public endpoint)
echo_section "1. Health Check (No Authentication Required)"

echo_command "curl -s \"$BASE_URL/health\""
curl -s "$BASE_URL/health" | jq '.' || echo "Error: Could not connect to backend"

# Example 2: List Models
echo_section "2. List Available Models"

echo_command "curl -s \"$BASE_URL/models\" -H \"Authorization: Bearer $API_KEY\""
curl -s "$BASE_URL/models" -H "Authorization: Bearer $API_KEY" | jq '.'

# Example 3: Simple Chat Completion
echo_section "3. Simple Chat Completion"

echo_command "curl -s -X POST \"$BASE_URL/chat/completions\" \
  -H \"Content-Type: application/json\" \
  -H \"Authorization: Bearer $API_KEY\" \
  -d '{...}'"

curl -s -X POST "$BASE_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "mixtral-8x7b",
    "messages": [{"role": "user", "content": "What is 2+2?"}],
    "temperature": 0.7,
    "max_tokens": 50
  }' | jq '.choices[0].message.content'

# Example 4: Chat with System Prompt
echo_section "4. Chat with System Prompt"

echo_command "curl -s -X POST \"$BASE_URL/chat/completions\" \
  -H \"Content-Type: application/json\" \
  -H \"Authorization: Bearer $API_KEY\" \
  -d '{...}'"

curl -s -X POST "$BASE_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "llama-3-70b",
    "messages": [
      {"role": "system", "content": "You are a helpful Python expert."},
      {"role": "user", "content": "Explain list comprehensions in one sentence."}
    ],
    "temperature": 0.5,
    "max_tokens": 100
  }' | jq '.choices[0].message.content'

# Example 5: Different Temperature Settings
echo_section "5. Temperature Comparison"

echo "Low temperature (0.2) - More focused:"
curl -s -X POST "$BASE_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "phi-3-mini",
    "messages": [{"role": "user", "content": "Describe a sunset."}],
    "temperature": 0.2,
    "max_tokens": 50
  }' | jq '.choices[0].message.content'

echo ""
echo "High temperature (1.5) - More creative:"
curl -s -X POST "$BASE_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "phi-3-mini",
    "messages": [{"role": "user", "content": "Describe a sunset."}],
    "temperature": 1.5,
    "max_tokens": 50
  }' | jq '.choices[0].message.content'

# Example 6: Model Comparison
echo_section "6. Model Comparison"

QUESTION="Explain AI in one sentence."

for MODEL in "phi-3-mini" "mixtral-8x7b" "llama-3-70b"; do
    echo "Model: $MODEL"
    echo "$(printf '%.0s-' {1..50})"
    
    curl -s -X POST "$BASE_URL/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $API_KEY" \
      -d "{
        \"model\": \"$MODEL\",
        \"messages\": [{\"role\": \"user\", \"content\": \"$QUESTION\"}],
        \"temperature\": 0.7,
        \"max_tokens\": 100
      }" | jq -r '.choices[0].message.content'
    
    echo ""
done

# Example 7: Full Response Details
echo_section "7. Full Response with Usage Stats"

echo_command "curl -s -X POST \"$BASE_URL/chat/completions\" \
  -H \"Content-Type: application/json\" \
  -H \"Authorization: Bearer $API_KEY\" \
  -d '{...}'"

RESPONSE=$(curl -s -X POST "$BASE_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "mixtral-8x7b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 50
  }')

echo "$RESPONSE" | jq '{
  response: .choices[0].message.content,
  model: .model,
  tokens: .usage,
  finish_reason: .choices[0].finish_reason
}'

# Example 8: Multi-turn Conversation
echo_section "8. Multi-turn Conversation"

echo "Building a conversation..."
echo ""

# First turn
echo "User: Write a Python function to add two numbers"
RESPONSE1=$(curl -s -X POST "$BASE_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "mixtral-8x7b",
    "messages": [
      {"role": "user", "content": "Write a Python function to add two numbers"}
    ],
    "temperature": 0.7,
    "max_tokens": 200
  }')

ASSISTANT_MSG=$(echo "$RESPONSE1" | jq -r '.choices[0].message.content')
echo "Assistant: $ASSISTANT_MSG"
echo ""

# Second turn (using previous response)
echo "User: Now add error handling"
curl -s -X POST "$BASE_URL/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "{
    \"model\": \"mixtral-8x7b\",
    \"messages\": [
      {\"role\": \"user\", \"content\": \"Write a Python function to add two numbers\"},
      {\"role\": \"assistant\", \"content\": $(echo "$ASSISTANT_MSG" | jq -R .)},
      {\"role\": \"user\", \"content\": \"Now add error handling\"}
    ],
    \"temperature\": 0.7,
    \"max_tokens\": 300
  }" | jq -r '.choices[0].message.content'

# Summary
echo ""
echo "======================================================================"
echo "                    Examples Completed"
echo "======================================================================"
echo ""
echo "All examples ran successfully!"
echo ""
echo "For more examples and documentation, see:"
echo "  - docs/LLM-CONNECTION-GUIDE.md"
echo "  - FRONTEND-COMMANDS.md"
echo "  - examples/python-openai-sdk.py"
echo ""
