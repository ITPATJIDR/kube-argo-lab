#!/usr/bin/env bash
# Wire the shop app to GitHub: Argo CD Application + pipeline template.
# Usage: REPO_URL=https://github.com/OWNER/REPO.git ./setup.sh
# Credentials (private repo / push access) are created separately — see README.
set -euo pipefail
cd "$(dirname "$0")"
export KUBECONFIG="${KUBECONFIG_K3S:-$HOME/.kube/k3s.yaml}"

: "${REPO_URL:?set REPO_URL=https://github.com/OWNER/REPO.git}"

kubectl apply -f registry/registry.yaml
kubectl apply -f workflows/rbac.yaml -f workflows/shop-ci.yaml
sed "s#REPO_URL#${REPO_URL}#" argocd/shop-app.yaml | kubectl apply -f -

echo
echo "Run the pipeline:"
echo "  REPO_URL=${REPO_URL} ./run-pipeline.sh"
echo "or in the UI: http://argo-workflows.localhost → Workflow Templates → shop-ci → Submit"
