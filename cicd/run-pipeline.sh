#!/usr/bin/env bash
# Submit the shop-ci pipeline (no argo CLI needed).
# Usage: REPO_URL=https://github.com/OWNER/REPO.git ./run-pipeline.sh [revision]
set -euo pipefail
export KUBECONFIG="${KUBECONFIG_K3S:-$HOME/.kube/k3s.yaml}"
: "${REPO_URL:?set REPO_URL=https://github.com/OWNER/REPO.git}"
REV="${1:-main}"

kubectl create -f - <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: shop-ci-
  namespace: argo
spec:
  workflowTemplateRef:
    name: shop-ci
  arguments:
    parameters:
      - name: repo-url
        value: ${REPO_URL}
      - name: revision
        value: ${REV}
      # Passed explicitly (not left to template defaults) so that "Retry" in the UI
      # still resolves them — Argo does not re-apply template defaults on retry.
      - name: app-dir
        value: application
      - name: push-registry
        value: registry.registry.svc.cluster.local:5000
      - name: argocd-app
        value: shop
YAML
echo "Watch: http://argo-workflows.localhost/workflows/argo"
