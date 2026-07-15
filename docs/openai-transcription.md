# OpenAI Audio Transcription Setup

## Overview

The Frida Car Claims AI backend now uses OpenAI-compatible audio transcription instead of in-cluster Whisper.cpp. This change:

- ✅ Eliminates the need for a dedicated Whisper container
- ✅ Reduces cluster resource usage
- ✅ Uses battle-tested OpenAI Whisper API
- ✅ Maintains backward compatibility with whisper.cpp if needed

## Quick Start

### 1. Obtain an OpenAI API Key

Sign up at https://platform.openai.com/ and create an API key.

### 2. Create Secrets

Add the transcription API key to each environment:

```bash
# Dev
oc create secret generic voice-backend-secrets \
  --from-literal=CHAT_API_KEY='your-chat-key' \
  --from-literal=TRANSCRIPTION_API_KEY='sk-your-openai-key' \
  --dry-run=client -o yaml | oc apply -f - -n frida-carclaims-dev

# Stage  
oc create secret generic voice-backend-secrets \
  --from-literal=CHAT_API_KEY='your-chat-key' \
  --from-literal=TRANSCRIPTION_API_KEY='sk-your-openai-key' \
  --dry-run=client -o yaml | oc apply -f - -n frida-carclaims-stage

# Prod
oc create secret generic voice-backend-secrets \
  --from-literal=CHAT_API_KEY='your-chat-key' \
  --from-literal=TRANSCRIPTION_API_KEY='sk-your-openai-key' \
  --dry-run=client -o yaml | oc apply -f - -n frida-carclaims-prod
```

### 3. Configuration

The environments are already configured to use OpenAI transcription:

```yaml
# environments/*/values.yaml
backend:
  config:
    transcriptionBaseUrl: "https://api.openai.com/v1/"
    transcriptionModel: "whisper-1"
```

### 4. Deploy

ArgoCD will automatically sync the changes. Verify deployment:

```bash
oc get pods -n frida-carclaims-dev
oc logs -n frida-carclaims-dev deployment/voice-backend
```

## Alternative: Use Your Own Whisper Service

If you prefer to self-host or use a different provider:

```yaml
backend:
  config:
    transcriptionBaseUrl: "https://your-whisper-api.example.com/v1/"
    transcriptionModel: "whisper-1"
```

The endpoint must be compatible with OpenAI's `/v1/audio/transcriptions` API.

## Cost Estimation

OpenAI Whisper API pricing (as of 2024):
- **$0.006 per minute** of audio

Example monthly cost:
- 1,000 claims × 2 minutes each = 2,000 minutes = **$12/month**
- 10,000 claims × 2 minutes each = 20,000 minutes = **$120/month**

Compare this to running a Whisper container 24/7 (compute + storage costs).

## Troubleshooting

### Backend fails to start

Check the secret exists and contains `TRANSCRIPTION_API_KEY`:

```bash
oc get secret voice-backend-secrets -n frida-carclaims-dev -o yaml
```

### HTTP 401 errors

Verify your API key is valid:

```bash
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer sk-your-key"
```

### Audio transcription timeouts

Increase the timeout if needed:

```yaml
backend:
  config:
    chatTimeout: "180s"
```

## References

- [OpenAI Whisper API Documentation](https://platform.openai.com/docs/guides/speech-to-text)
- [Backend Migration Guide](../frida-carclaims-voice-backend/TRANSCRIPTION_MIGRATION.md)
