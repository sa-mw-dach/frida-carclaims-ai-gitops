# Frida Car Claims AI — GitOps

Production GitOps repository for the Frida Car Claims AI stack, deployed via **Helm** and **ArgoCD** with a git promotion workflow across three environments.

## Stack

| Component | Description |
|-----------|-------------|
| **Frontend** | React SPA + nginx reverse proxy (public Route) |
| **Voice backend** | Quarkus API for voice-to-form extraction (ClusterIP) |
| **Whisper** | In-cluster speech-to-text (ClusterIP + PVC) |
| **LiteLLM / Qwen** | External LLM service (ConfigMap + Secret) |

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
  cluster.yaml                # Cluster-specific apps domain (you create this)
  cluster.yaml.example        # Template
  dev/values.yaml
  stage/values.yaml
  prod/values.yaml
argocd/
  bootstrap/app-of-apps.yaml
  applications/
docs/promotion.md
```

## Prerequisites

- OpenShift cluster with `oc` CLI access
- ArgoCD installed (OpenShift GitOps operator or upstream ArgoCD)
- Container images in `quay.io/mklaasse/`

This is a **public** GitHub repository — ArgoCD can read it over HTTPS without credentials or deploy keys.

## First-time setup

### 1. Create `environments/cluster.yaml`

Copy the example and set your cluster's apps domain:

```bash
cp environments/cluster.yaml.example environments/cluster.yaml
```

Edit `environments/cluster.yaml`:

```yaml
global:
  appsDomain: apps.mycluster.example.com
```

Discover the domain on OpenShift:

```bash
oc get ingresscontroller default -n openshift-ingress-operator \
  -o jsonpath='{.status.domain}{"\n"}'
```

Route hosts are computed automatically from this value:

| Environment | URL |
|-------------|-----|
| dev | `https://frida-carclaims-dev.<appsDomain>/` |
| stage | `https://frida-carclaims-stage.<appsDomain>/` |
| prod | `https://frida-carclaims.<appsDomain>/` |

To override a single route host, set `frontend.route.host` in the environment values file.

### 2. Create secrets

The voice backend requires a LiteLLM API key. Create this secret in each namespace before the backend pods can start:

```bash
oc create secret generic voice-backend-secrets -n frida-carclaims-dev \
  --from-literal=LITELLM_API_KEY='sk-...'

oc create secret generic voice-backend-secrets -n frida-carclaims-stage \
  --from-literal=LITELLM_API_KEY='sk-...'

oc create secret generic voice-backend-secrets -n frida-carclaims-prod \
  --from-literal=LITELLM_API_KEY='sk-...'
```

| Secret | Namespaces | Keys |
|--------|------------|------|
| `voice-backend-secrets` | dev, stage, prod | `LITELLM_API_KEY` (required), `WHISPER_API_KEY` (optional) |

### 3. Bootstrap ArgoCD

Apply the app-of-apps (one-time):

```bash
oc apply -f argocd/bootstrap/app-of-apps.yaml
```

This creates the root `frida-carclaims-apps` Application, which deploys dev, stage, and prod.

### 4. Verify

```bash
argocd app sync frida-carclaims-dev
curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://frida-carclaims-dev.apps.mycluster.example.com/"
```

## Local validation

```bash
helm template frida-carclaims charts/frida-carclaims \
  -f environments/cluster.yaml \
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
                                                            ├─ whisper (STT)
                                                            └─ LiteLLM (external LLM)
```
