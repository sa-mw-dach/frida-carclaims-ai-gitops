# Frida Car Claims AI — GitOps

Production GitOps repository for the Frida Car Claims AI stack, deployed via **Helm** and **ArgoCD** with a git promotion workflow across three environments.

## Stack

| Component | Description |
|-----------|-------------|
| **Frontend** | React SPA + nginx reverse proxy (public Route) |
| **Voice backend** | Quarkus API for voice-to-form extraction (ClusterIP) |
| **Whisper** | In-cluster speech-to-text (ClusterIP + PVC) |
| **Chat API / Qwen** | External LLM service (ConfigMap + Secret) |

## Environments

| Environment | Namespace | Route hostname pattern | ArgoCD sync |
|-------------|-----------|------------------------|-------------|
| **dev** | `frida-carclaims-dev` | `frida-carclaims-dev.<appsDomain>` | Automated |
| **stage** | `frida-carclaims-stage` | `frida-carclaims-stage.<appsDomain>` | Automated |
| **prod** | `frida-carclaims-prod` | `frida-carclaims.<appsDomain>` | Manual |

`<appsDomain>` is your cluster's OpenShift apps domain (e.g. `apps.mycluster.example.com`), configured once per cluster.

## Repository layout

```
charts/frida-carclaims/       # Helm chart (frontend, backend, whisper)
environments/
  dev/values.yaml             # Dev environment configuration
  stage/values.yaml           # Stage environment configuration
  prod/values.yaml            # Prod environment configuration
argocd/
  bootstrap/app-of-apps.yaml  # App-of-apps root application
  applications/               # ArgoCD Applications (dev, stage, prod)
docs/promotion.md
```

## Prerequisites

- OpenShift cluster with `oc` CLI access
- OpenShift GitOps operator installed (provides ArgoCD in `openshift-gitops` namespace)
- Container images in `quay.io/mklaasse/`

This is a **public** GitHub repository — ArgoCD can read it over HTTPS without credentials or deploy keys.

## First-time setup

### 1. Create secrets

The voice backend requires a Chat API API key. Create this secret in each namespace before the backend pods can start:

```bash
oc create secret generic voice-backend-secrets \
  --from-literal=CHAT_API_KEY='sk-...' \
  --from-literal=TRANSCRIPTION_API_KEY='sk-...' \
  --dry-run=client -o yaml | oc apply -f - -n frida-car-claims-dev

oc create secret generic voice-backend-secrets \
  --from-literal=CHAT_API_KEY='sk-...' \
  --from-literal=TRANSCRIPTION_API_KEY='sk-...' \
  --dry-run=client -o yaml | oc apply -f - -n frida-car-claims-stage

oc create secret generic voice-backend-secrets \
  --from-literal=CHAT_API_KEY='sk-...' \
  --from-literal=TRANSCRIPTION_API_KEY='sk-...' \
  --dry-run=client -o yaml | oc apply -f - -n frida-car-claims-prod 
```

after creating the secrets restart the pods: 

```bash
oc rollout restart deployment voice-backend -n frida-car-claims-dev
oc rollout restart deployment voice-backend -n frida-car-claims-stage
oc rollout restart deployment voice-backend -n frida-car-claims-prod
```

| Secret | Namespaces | Keys |
|--------|------------|------|
| `voice-backend-secrets` | dev, stage, prod | `CHAT_API_KEY` (required), `TRANSCRIPTION_API_KEY` (required) |

### 2. Bootstrap ArgoCD

Apply the app-of-apps to the OpenShift GitOps namespace (one-time):

```bash
oc apply -f argocd/bootstrap/app-of-apps.yaml
```

This creates the root `frida-carclaims-apps` Application in the `openshift-gitops` namespace, which deploys dev, stage, and prod environments.

### 3. Verify

```bash
argocd app sync frida-carclaims-dev
curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://frida-carclaims-dev.apps.mycluster.example.com/"
```

## Local validation

```bash
helm template frida-carclaims charts/frida-carclaims \
  -f environments/dev/values.yaml
```

## Promotion workflow

Image versions are promoted between environments via pull requests. See [docs/promotion.md](docs/promotion.md) for the step-by-step runbook.

```
dev (auto-sync) → stage (auto-sync) → prod (manual sync)
```

## Application repositories

| Repo | Image |
|------|-------|
| [frida-carclaims-frontend](https://github.com/marcoklaassen/frida-carclaims-frontend) | `quay.io/mklaasse/frida-carclaims-frontend` |
| [frida-carclaims-voice-backend](https://github.com/marcoklaassen/frida-carclaims-backend-ai) | `quay.io/mklaasse/frida-carclaims-backend-ai` |

CI in those repos pushes SHA-tagged images. Update `environments/*/values.yaml` to pin specific tags during promotion.

## Traffic flow

```
Browser → OpenShift Route → frontend (nginx)
                              └─ /api/* → backend Service → voice-backend pod
                                                            ├─ whisper (external LLM)
                                                            └─ Chat API (external LLM)
```