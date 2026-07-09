#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

echo "==> Configuring cluster domain"
./scripts/configure-cluster.sh

echo "==> Applying ArgoCD app-of-apps bootstrap"
oc apply -f argocd/bootstrap/app-of-apps.yaml

echo "==> Create backend secrets in each namespace (if not done yet):"
cat <<'EOF'
for ns in frida-carclaims-dev frida-carclaims-stage frida-carclaims-prod; do
  oc create secret generic voice-backend-secrets -n "$ns" \
    --from-literal=LITELLM_API_KEY='sk-...' \
    --dry-run=client -o yaml | oc apply -f -
done
EOF

echo ""
echo "==> After ArgoCD syncs, verify dev:"
echo "  curl -sS -o /dev/null -w '%{http_code}\n' \"https://frida-carclaims-dev.${CLUSTER_APPS_DOMAIN}/\""
