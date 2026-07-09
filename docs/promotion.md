# Git Promotion Runbook

This document describes how to promote application releases across dev, stage, and prod using this GitOps repository.

## Overview

Promotion is **git-based**: each environment's desired state lives in `environments/<env>/values.yaml`. Moving a release forward means opening a PR that copies image tags (and any env-specific config) from one environment to the next.

ArgoCD watches this repository and syncs changes automatically (dev and stage) or on demand (prod).

```
┌─────────┐    PR     ┌─────────┐    PR     ┌─────────┐
│   dev   │ ────────► │  stage  │ ────────► │  prod   │
│ auto    │           │ auto    │           │ manual  │
└─────────┘           └─────────┘           └─────────┘
```

## Image tagging convention

Application CI pushes two tags per build:

| Tag | Purpose |
|-----|---------|
| `latest` | Convenience for dev iteration |
| `sha-<commit>` | Immutable tag for promotion (e.g. `sha-a1b2c3d`) |

Pin immutable tags in environment values files for stage and prod.

## Cluster URLs

Public URLs depend on `global.appsDomain` in `environments/cluster.yaml`:

| Environment | URL |
|-------------|-----|
| dev | `https://frida-carclaims-dev.<appsDomain>/` |
| stage | `https://frida-carclaims-stage.<appsDomain>/` |
| prod | `https://frida-carclaims.<appsDomain>/` |

## Step 1: Deploy to dev

After a successful CI build in an application repo:

1. Note the SHA tag from the CI output (e.g. `sha-a1b2c3d`).
2. Update `environments/dev/values.yaml`:

```yaml
frontend:
  image:
    tag: sha-a1b2c3d

backend:
  image:
    tag: sha-a1b2c3d
```

3. Commit and push to `main` (or merge a PR).
4. ArgoCD auto-syncs `frida-carclaims-dev` within ~3 minutes.
5. Verify:

```bash
argocd app get frida-carclaims-dev
curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://frida-carclaims-dev.<appsDomain>/"
```

## Step 2: Promote dev → stage

1. Open a PR titled e.g. `promote: dev → stage (sha-a1b2c3d)`.
2. Copy `frontend.image.tag` and `backend.image.tag` from `environments/dev/values.yaml` to `environments/stage/values.yaml`.
3. Review the diff — only image tags should change (unless you intentionally promote config changes).
4. Merge after smoke-testing dev.
5. ArgoCD auto-syncs `frida-carclaims-stage`.
6. Verify:

```bash
argocd app get frida-carclaims-stage
curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://frida-carclaims-stage.<appsDomain>/"
```

## Step 3: Promote stage → prod

1. Open a PR titled e.g. `promote: stage → prod (sha-a1b2c3d)`.
2. Copy image tags from `environments/stage/values.yaml` to `environments/prod/values.yaml`.
3. Require at least one approval before merging.
4. After merge, **manually sync** prod (prod does not auto-sync):

```bash
argocd app sync frida-carclaims-prod
```

5. Verify:

```bash
argocd app get frida-carclaims-prod
curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://frida-carclaims.<appsDomain>/"
```

## Rollback

To roll back an environment, revert the image tags in that environment's `values.yaml` to the previous known-good SHA and merge. ArgoCD will sync the reverted state.

For prod, remember to manually trigger sync after merge:

```bash
argocd app sync frida-carclaims-prod
```

## What to promote

| Field | Promote? | Notes |
|-------|----------|-------|
| `frontend.image.tag` | Yes | Primary promotion artifact |
| `backend.image.tag` | Yes | Primary promotion artifact |
| `frontend.replicas` | Env-specific | Prod may run more replicas |
| `backend.config.*` | Carefully | Only promote tested config changes |
| `whisper.enabled` | Env-specific | Can differ per environment |
| `global.appsDomain` | Never | Cluster-specific; set in `environments/cluster.yaml` |
| Secrets | Never | Managed out-of-band via `oc create secret` |

## Checklist

### Dev deployment
- [ ] CI build succeeded
- [ ] Image tags updated in `environments/dev/values.yaml`
- [ ] ArgoCD dev app is Healthy and Synced
- [ ] Frontend returns HTTP 200
- [ ] Voice extraction endpoint works

### Dev → stage promotion
- [ ] Dev smoke test passed
- [ ] PR copies only intended tag changes
- [ ] PR merged
- [ ] ArgoCD stage app is Healthy and Synced
- [ ] Stage URL returns HTTP 200

### Stage → prod promotion
- [ ] Stage validation passed
- [ ] PR approved and merged
- [ ] Manual `argocd app sync frida-carclaims-prod` executed
- [ ] ArgoCD prod app is Healthy and Synced
- [ ] Prod URL returns HTTP 200
