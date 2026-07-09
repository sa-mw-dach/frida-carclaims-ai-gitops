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
  cluster.yaml                # Cluster-specific (generated, gitignored)
  cluster.yaml.example        # Template
  dev/values.yaml
  stage/values.yaml
  prod/values.yaml
argocd/
  bootstrap/app-of-apps.yaml
  applications/
scripts/
  configure-cluster.sh        # Writes environments/cluster.yaml from env var
  bootstrap.sh                # First-time cluster install
docs/promotion.md
.env.example
```

## Prerequisites

- OpenShift cluster with `oc` CLI access
- ArgoCD installed (OpenShift GitOps operator or upstream ArgoCD)
- Container images in `quay.io/mklaasse/`

This is a **public** GitHub repository — ArgoCD can read it over HTTPS without credentials or deploy keys.

## Cluster configuration

Before the first deploy, set your cluster's apps domain. This is the only cluster-specific setting required.

**Option A — environment variable:**

```bash
export CLUSTER_APPS_DOMAIN=apps.mycluster.example.com
./scripts/configure-cluster.sh
```

**Option B — `.env` file:**

```bash
cp .env.example .env
# edit CLUSTER_APPS_DOMAIN in .env
./scripts/configure-cluster.sh
```

**Discover the domain on OpenShift:**

```bash
oc get ingresscontroller default -n openshift-ingress-operator \
  -o jsonpath='{.status.domain}{"\n"}'
```

This writes `environments/cluster.yaml`:

```yaml
global:
  appsDomain: apps.mycluster.example.com
```

Route hosts are then computed automatically:

| Environment | URL |
|-------------|-----|
| dev | `https://frida-carclaims-dev.<appsDomain>/` |
| stage | `https://frida-carclaims-stage.<appsDomain>/` |
| prod | `https://frida-carclaims.<appsDomain>/` |

To override a single route host, set `frontend.route.host` in the environment values file.

## Bootstrap (new cluster)

```bash
export CLUSTER_APPS_DOMAIN=apps.mycluster.example.com
./scripts/bootstrap.sh
```

Then create secrets and verify:

```bash
for ns in frida-carclaims-dev frida-carclaims-stage frida-carclaims-prod; do
  oc create secret generic voice-backend-secrets -n "$ns" \
    --from-literal=LITELLM_API_KEY='sk-...' \
    --dry-run=client -o yaml | oc apply -f -
done

curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://frida-carclaims-dev.${CLUSTER_APPS_DOMAIN}/"
```

## Local validation

```bash
export CLUSTER_APPS_DOMAIN=apps.mycluster.example.com
./scripts/configure-cluster.sh

helm template frida-carclaims charts/frida-carclaims \
  -f environments/cluster.yaml \
  -f environments/dev/values.yaml

# Or pass the domain directly without writing cluster.yaml:
helm template frida-carclaims charts/frida-carclaims \
  -f environments/dev/values.yaml \
  --set global.appsDomain=apps.mycluster.example.com
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
