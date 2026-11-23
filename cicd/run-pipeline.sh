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
YAML
echo "Watch: http://argo-workflows.localhost/workflows/argo"
