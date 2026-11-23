#!/usr/bin/env bash
# Install / upgrade Argo CD and Argo Workflows into the local k3s cluster.
set -euo pipefail

cd "$(dirname "$0")"

# Always target k3s — never the default kubeconfig (which points at AKS)
export KUBECONFIG="${KUBECONFIG_K3S:-$HOME/.kube/k3s.yaml}"

ARGOCD_CHART_VERSION=10.18.2
WORKFLOWS_CHART_VERSION=2.0.18
ROLLOUTS_CHART_VERSION=2.43.12

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo

helm upgrade --install argocd argo/argo-cd \
  --version "$ARGOCD_CHART_VERSION" \
  --namespace argocd --create-namespace \
  -f argocd/values.yaml --wait

helm upgrade --install argo-workflows argo/argo-workflows \
  --version "$WORKFLOWS_CHART_VERSION" \
  --namespace argo --create-namespace \
  -f argo-workflows/values.yaml --wait

helm upgrade --install argo-rollouts argo/argo-rollouts \
  --version "$ROLLOUTS_CHART_VERSION" \
  --namespace argo-rollouts --create-namespace \
  -f argo-rollouts/values.yaml --wait

echo
echo "Argo CD:        http://argocd.localhost   (user: admin)"
echo -n "  password:     "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
echo "Argo Workflows: http://argo-workflows.localhost"
echo "Argo Rollouts:  http://argo-rollouts.localhost"
