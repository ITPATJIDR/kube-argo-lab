#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="${KUBECONFIG_K3S:-$HOME/.kube/k3s.yaml}"
helm uninstall argo-workflows -n argo || true
helm uninstall argocd -n argocd || true
kubectl delete namespace argo argocd --ignore-not-found
