# OpenAI API Key Setup Guide

This guide helps you create an OpenAI API key for the Frida Car Claims AI transcription service.

## Step 1: Create OpenAI Account

1. Go to https://platform.openai.com/signup
2. Sign up with your email or GitHub account
3. Verify your email address

## Step 2: Add Payment Method

OpenAI requires a payment method for API access:

1. Go to https://platform.openai.com/account/billing/overview
2. Click **"Add payment details"**
3. Enter your credit card information
4. **Set a usage limit** (recommended: $10-50/month to prevent surprises)

## Step 3: Create API Key

1. Go to https://platform.openai.com/api-keys
2. Click **"+ Create new secret key"**
3. Name it: `frida-carclaims-dev` (or similar)
4. **Copy the key immediately** - you won't be able to see it again!
5. Store it securely (you'll need it for the next step)

The key will look like: `sk-proj-...` (starts with `sk-`)

## Step 4: Create Kubernetes Secret

Now create the secret in your OpenShift cluster for each environment:

### Development Environment

```bash
oc create secret generic voice-backend-secrets \
  --from-literal=CHAT_API_KEY='your-chat-key-here' \
  --from-literal=TRANSCRIPTION_API_KEY='sk-proj-your-openai-key-here' \
  --namespace=frida-carclaims-dev \
  --dry-run=client -o yaml | oc apply -f -
```

### Stage Environment

```bash
oc create secret generic voice-backend-secrets \
  --from-literal=CHAT_API_KEY='your-chat-key-here' \
  --from-literal=TRANSCRIPTION_API_KEY='sk-proj-your-openai-key-here' \
  --namespace=frida-carclaims-stage \
  --dry-run=client -o yaml | oc apply -f -
```

### Production Environment

```bash
oc create secret generic voice-backend-secrets \
  --from-literal=CHAT_API_KEY='your-chat-key-here' \
  --from-literal=TRANSCRIPTION_API_KEY='sk-proj-your-openai-key-here' \
  --namespace=frida-carclaims-prod \
  --dry-run=client -o yaml | oc apply -f -
```

## Step 5: Verify Secret

Check that the secret was created:

```bash
# Check if secret exists
oc get secret voice-backend-secrets -n frida-carclaims-dev

# Verify it has both keys
oc get secret voice-backend-secrets -n frida-carclaims-dev -o jsonpath='{.data}' | jq 'keys'
```

Should output:
```json
[
  "CHAT_API_KEY",
  "TRANSCRIPTION_API_KEY"
]
```

## Step 6: Test the API Key

Verify your OpenAI API key works:

```bash
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer sk-proj-your-key-here"
```

Should return a list of available models including `whisper-1`.

## Pricing

OpenAI Whisper API pricing (as of 2024):
- **$0.006 per minute** of audio

### Cost Examples

| Usage | Minutes/month | Cost/month |
|-------|---------------|------------|
| Light (100 claims) | 200 min | $1.20 |
| Medium (1,000 claims) | 2,000 min | $12.00 |
| Heavy (10,000 claims) | 20,000 min | $120.00 |

**Recommendation**: Set a monthly budget limit of $50 in OpenAI dashboard to prevent unexpected costs.

## Usage Limits

Default rate limits for new accounts:
- **3 requests per minute (RPM)**
- Increases automatically with usage

If you need higher limits, request them at: https://platform.openai.com/account/rate-limits

## Monitoring Usage

Monitor your OpenAI API usage:

1. Go to https://platform.openai.com/usage
2. View daily/monthly usage
3. Download detailed usage reports
4. Set up billing alerts

## Security Best Practices

### Rotate Keys Regularly

```bash
# Create new key in OpenAI dashboard
# Update the secret
oc create secret generic voice-backend-secrets \
  --from-literal=CHAT_API_KEY='your-chat-key' \
  --from-literal=TRANSCRIPTION_API_KEY='sk-proj-new-key' \
  --namespace=frida-carclaims-dev \
  --dry-run=client -o yaml | oc apply -f -

# Restart pods to pick up new key
oc rollout restart deployment/voice-backend -n frida-carclaims-dev
```

### Restrict Key Permissions

In OpenAI dashboard, limit the key to only Whisper API:
1. Edit the API key
2. Set permissions to "Restricted"
3. Enable only: "Audio" → "Transcriptions"

### Never Commit Keys to Git

✅ **DO**: Store in Kubernetes Secrets
❌ **DON'T**: Put in values.yaml or commit to repository

## Troubleshooting

### Error: "Invalid API key"

**Cause**: Wrong key format or expired key

**Solution**: 
- Verify key starts with `sk-`
- Create a new key in OpenAI dashboard
- Update the secret

### Error: "Rate limit exceeded"

**Cause**: Too many requests per minute

**Solution**:
- Wait 60 seconds and retry
- Request higher rate limits from OpenAI
- Consider implementing retry logic in backend

### Error: "Insufficient credits"

**Cause**: No payment method or usage limit reached

**Solution**:
- Add payment method in OpenAI dashboard
- Increase usage limit
- Check billing status

## Alternative: Use Organization API Key

For production, consider using an **Organization API key**:

1. Create an OpenAI Organization
2. Invite team members
3. Create organization-level API keys
4. Better billing tracking and team management

## Next Steps

After creating the API key:

1. ✅ Create secret in all environments (dev, stage, prod)
2. ✅ Test with integration tests: `./mvnw test -Dtest=OpenAiTranscriptionIntegrationTest`
3. ✅ Deploy backend to cluster
4. ✅ Test end-to-end flow
5. ✅ Monitor usage in OpenAI dashboard

## Support

- OpenAI Documentation: https://platform.openai.com/docs
- OpenAI Support: https://help.openai.com
- Pricing: https://openai.com/pricing
