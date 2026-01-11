# Using the AI Inference Platform Frontend

This guide shows you how to use the Open WebUI frontend after deployment.

## First Time Setup

### 1. Access the Frontend

Get your frontend URL from Terraform:

```bash
cd terraform
terraform output frontend_url
```

Open this URL in your web browser.

### 2. Create Admin Account

On first visit, you'll see a **Sign Up** page:

1. Enter your desired **username**
2. Enter your **full name**
3. Enter a strong **password**
4. Click **Create Account**

**Important**: The first user to sign up becomes the admin. After creating the admin account, it's recommended to disable public signup.

### 3. Disable Public Signup (Recommended)

After creating your admin account, prevent unauthorized signups:

```bash
# Get resource group name
RESOURCE_GROUP=$(cd terraform && terraform output -raw resource_group_name)

# Disable signup
az containerapp update \
  --name ai-inference-platform-frontend \
  --resource-group $RESOURCE_GROUP \
  --set-env-vars "ENABLE_SIGNUP=false"

# Wait a few seconds for the update to apply
sleep 10

# Restart the container app
az containerapp revision restart \
  --name ai-inference-platform-frontend \
  --resource-group $RESOURCE_GROUP
```

## Using the Interface

### Starting a New Chat

1. Click the **+ New Chat** button in the sidebar
2. Select a model from the dropdown:
   - **Llama-3-70B**: Best for complex tasks, 8K context
   - **Mixtral 8x7B**: Fast and efficient, 32K context
   - **Phi-3-mini**: Lightweight for simple queries, 4K context
3. Type your message in the text box
4. Press **Enter** or click the **Send** button

### Adjusting Settings

Click the **Settings** icon (⚙️) to adjust:

- **Temperature** (0.0 - 2.0): Controls randomness
  - Lower = more focused and deterministic
  - Higher = more creative and varied
- **Top P** (0.0 - 1.0): Controls diversity
  - Lower = more focused on likely tokens
  - Higher = considers more token options
- **Max Tokens** (1 - 4096): Maximum response length
  - Adjust based on your needs
  - Higher = longer responses

### Using System Prompts

System prompts set the behavior and context for the AI:

1. Click the **System** field at the top of the chat
2. Enter your system prompt, for example:
   - "You are a helpful coding assistant."
   - "You are an expert in Python programming."
   - "Respond in a friendly, casual tone."
3. The system prompt applies to all messages in the conversation

### Saving and Managing Chats

- **Auto-save**: Chats are automatically saved as you type
- **Chat History**: Access previous chats from the sidebar
- **Rename Chat**: Click the chat title to rename
- **Delete Chat**: Click the trash icon next to a chat
- **Export Chat**: Click the download icon to export

### Advanced Features

#### Multi-turn Conversations

The interface maintains conversation context automatically. Each message references previous messages in the conversation.

#### Code Blocks

The interface automatically detects and formats code:
- Syntax highlighting for multiple languages
- Copy button for easy code copying

#### Markdown Support

Messages support full Markdown formatting:
- **Bold text**: `**bold**`
- *Italic text*: `*italic*`
- Lists, tables, links, and more

#### Streaming Responses

Responses stream in real-time, so you can read the answer as it's generated.

## Managing Users (Admin Only)

As an admin, you can manage other users:

1. Click your profile picture
2. Select **Admin Settings**
3. Navigate to **Users**
4. View, edit, or remove users

### Adding New Users

If you need to add users after disabling signup:

1. Temporarily enable signup:
   ```bash
   az containerapp update \
     --name ai-inference-platform-frontend \
     --resource-group $RESOURCE_GROUP \
     --set-env-vars "ENABLE_SIGNUP=true"
   ```

2. Share the URL with the new user

3. Have them create their account

4. Disable signup again:
   ```bash
   az containerapp update \
     --name ai-inference-platform-frontend \
     --resource-group $RESOURCE_GROUP \
     --set-env-vars "ENABLE_SIGNUP=false"
   ```

## Troubleshooting

### Cannot Connect to Backend

If you see errors about connecting to the API:

1. Check that the backend Azure Functions are running
2. Verify the `OPENAI_API_BASE_URL` environment variable is correct
3. Check the logs:
   ```bash
   az containerapp logs show \
     --name ai-inference-platform-frontend \
     --resource-group $RESOURCE_GROUP \
     --tail 100
   ```

### Authentication Issues

If you're locked out or forgot your password:

1. Access the container's database (requires admin access to Azure)
2. Reset the password using the Open WebUI CLI
3. Or, if necessary, delete and recreate the container app

### Slow Response Times

If responses are slow:

1. Check the backend GPU instances are running
2. Verify cache is working (should see fast responses for repeated queries)
3. Try a lighter model (Phi-3-mini) for faster responses

### Model Not Available

If a model doesn't appear in the dropdown:

1. Verify the backend API is returning the models list
2. Check: `curl https://<your-function-app>.azurewebsites.net/api/v1/models`
3. Ensure the models are configured in the backend

## Best Practices

### Security

- **Use Strong Passwords**: Minimum 12 characters with mixed case, numbers, and symbols
- **Limit Users**: Only give access to trusted users
- **Keep Signup Disabled**: Prevent unauthorized access
- **Monitor Usage**: Check logs regularly for suspicious activity

### Cost Optimization

- **Choose Right Model**: Use Phi-3-mini for simple tasks to save costs
- **Set Token Limits**: Limit max_tokens to avoid excessive usage
- **Clear Old Chats**: Delete chats you no longer need

### Performance

- **Use Cache**: Repeated queries benefit from 40% cache hit rate
- **Batch Requests**: Group similar queries together
- **Monitor Response Times**: If slow, scale up backend resources

## Support

For issues or questions:

- **Frontend (Open WebUI)**: https://docs.openwebui.com
- **Backend Issues**: Check Azure Function logs
- **Infrastructure**: Review Terraform configuration
- **General Help**: See the main README.md
