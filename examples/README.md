# AI Inference Platform - Usage Examples

This directory contains practical examples for integrating with the AI Inference Platform.

## Available Examples

### 1. Python with OpenAI SDK (`python-openai-sdk.py`)

Comprehensive Python examples using the OpenAI SDK:
- Simple chat completions
- System prompts
- Multi-turn conversations
- Streaming responses
- Model comparison
- Listing available models

**Prerequisites:**
```bash
pip install openai
```

**Usage:**
```bash
# Set environment variables
export OPENAI_API_KEY='your-api-key'
export OPENAI_API_BASE='https://your-app.azurewebsites.net/api/v1'

# Run examples
python examples/python-openai-sdk.py
```

### 2. cURL Examples (`curl-examples.sh`)

Command-line examples using cURL:
- Health checks
- List models
- Simple completions
- System prompts
- Temperature comparison
- Model comparison
- Multi-turn conversations

**Prerequisites:**
```bash
# Requires jq for JSON parsing
sudo apt-get install jq  # Ubuntu/Debian
brew install jq          # macOS
```

**Usage:**
```bash
# Set environment variables
export OPENAI_API_KEY='your-api-key'
export OPENAI_API_BASE='https://your-app.azurewebsites.net/api/v1'

# Run examples
./examples/curl-examples.sh
```

## Getting Connection Details

Before running the examples, you need your API key and base URL.

### Option 1: Automated Setup

```bash
./setup-frontend-complete.sh
```

This saves connection details to `connection-details.txt`.

### Option 2: Manual Retrieval

```bash
cd terraform

# Get base URL
BACKEND_URL=$(az functionapp show \
  --name $(terraform output -raw function_app_name) \
  --resource-group $(terraform output -raw resource_group_name) \
  --query defaultHostName -o tsv)

echo "Base URL: https://$BACKEND_URL/api/v1"

# Get API key
az keyvault secret show \
  --vault-name $(terraform output -raw key_vault_name) \
  --name "frontend-openai-api-key" \
  --query value -o tsv

cd ..
```

### Option 3: From Saved File

```bash
cat connection-details.txt
```

## Environment Setup

Create a `.env` file in the project root:

```bash
# AI Inference Platform Configuration
OPENAI_API_KEY=your-api-key-here
OPENAI_API_BASE=https://your-app.azurewebsites.net/api/v1
DEFAULT_MODEL=mixtral-8x7b
```

Then load it:

```bash
source .env
```

Or use `python-dotenv`:

```python
from dotenv import load_dotenv
load_dotenv()
```

## Integration Patterns

### Pattern 1: Direct API Calls

```python
import requests

response = requests.post(
    f"{BASE_URL}/chat/completions",
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}"
    },
    json={
        "model": "mixtral-8x7b",
        "messages": [{"role": "user", "content": "Hello!"}]
    }
)

print(response.json()["choices"][0]["message"]["content"])
```

### Pattern 2: OpenAI SDK

```python
from openai import OpenAI

client = OpenAI(api_key=API_KEY, base_url=BASE_URL)
response = client.chat.completions.create(
    model="mixtral-8x7b",
    messages=[{"role": "user", "content": "Hello!"}]
)

print(response.choices[0].message.content)
```

### Pattern 3: LangChain

```python
from langchain.chat_models import ChatOpenAI

llm = ChatOpenAI(
    model_name="mixtral-8x7b",
    openai_api_key=API_KEY,
    openai_api_base=BASE_URL
)

response = llm.predict("Hello!")
print(response)
```

### Pattern 4: LlamaIndex

```python
from llama_index import OpenAI

llm = OpenAI(
    model="llama-3-70b",
    api_key=API_KEY,
    api_base=BASE_URL
)

response = llm.complete("Hello!")
print(response)
```

## Available Models

| Model ID | Provider | Context | Best For |
|----------|----------|---------|----------|
| `mixtral-8x7b` | Mistral AI | 32K | Long documents, fast |
| `llama-3-70b` | Meta | 8K | High quality, reasoning |
| `phi-3-mini` | Microsoft | 4K | Quick queries, testing |

## Common Use Cases

### 1. Simple Q&A

```bash
curl -X POST "$OPENAI_API_BASE/chat/completions" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mixtral-8x7b",
    "messages": [{"role": "user", "content": "What is Python?"}]
  }'
```

### 2. Code Generation

```python
response = client.chat.completions.create(
    model="llama-3-70b",
    messages=[
        {"role": "system", "content": "You are a Python expert."},
        {"role": "user", "content": "Write a function to merge two sorted lists"}
    ],
    temperature=0.5
)
```

### 3. Document Analysis

```python
response = client.chat.completions.create(
    model="mixtral-8x7b",  # Large context
    messages=[
        {"role": "system", "content": "Analyze the following document."},
        {"role": "user", "content": f"Document: {long_document}\n\nSummarize the key points."}
    ],
    max_tokens=1000
)
```

### 4. Interactive Chat

```python
messages = []

while True:
    user_input = input("You: ")
    if user_input.lower() == 'quit':
        break
    
    messages.append({"role": "user", "content": user_input})
    
    response = client.chat.completions.create(
        model="mixtral-8x7b",
        messages=messages
    )
    
    assistant_msg = response.choices[0].message.content
    messages.append({"role": "assistant", "content": assistant_msg})
    
    print(f"Assistant: {assistant_msg}")
```

## Troubleshooting

### Connection Issues

```bash
# Test backend health
curl "$OPENAI_API_BASE/health"

# Test with verbose output
curl -v -X POST "$OPENAI_API_BASE/chat/completions" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "mixtral-8x7b", "messages": [{"role": "user", "content": "test"}]}'
```

### Authentication Errors

```bash
# Verify API key
echo $OPENAI_API_KEY

# Verify it's in Key Vault
az keyvault secret show \
  --vault-name <key-vault-name> \
  --name "frontend-openai-api-key"
```

### Model Not Found

```bash
# List available models
curl "$OPENAI_API_BASE/models" \
  -H "Authorization: Bearer $OPENAI_API_KEY"
```

## Best Practices

1. **Use appropriate models**
   - `phi-3-mini` for simple/quick queries
   - `mixtral-8x7b` for long context
   - `llama-3-70b` for complex reasoning

2. **Set reasonable limits**
   - Use `max_tokens` to control cost
   - Set appropriate `temperature` (0.7 is a good default)

3. **Handle errors gracefully**
   - Implement retry logic
   - Check for rate limits
   - Validate responses

4. **Optimize for caching**
   - Repeated queries benefit from 40% cache hit rate
   - Use consistent formatting

5. **Monitor usage**
   - Check Azure Portal for metrics
   - Track token usage
   - Set budget alerts

## Additional Resources

- **[LLM Connection Guide](../docs/LLM-CONNECTION-GUIDE.md)** - Complete API reference
- **[Command Reference](../FRONTEND-COMMANDS.md)** - All setup/deploy commands
- **[Frontend Usage](../docs/frontend-usage.md)** - Web UI guide
- **[OpenAPI Spec](../openapi.json)** - Full API specification

## Support

For issues or questions:

1. Check the documentation in `docs/`
2. Review backend logs: `az functionapp log tail --name <app> --resource-group <rg>`
3. Test with the examples in this directory
4. See troubleshooting section above

---

**Last Updated**: 2024-01-17
