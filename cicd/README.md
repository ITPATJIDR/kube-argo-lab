# CI/CD — Argo Workflows pipeline + Argo CD GitOps

```
git push (GitHub) ──► run-pipeline.sh / Argo UI "Submit"
                          │
   Argo Workflows  shop-ci│
   ┌──────────────────────▼───────────────────────────────────────────────┐
   │ checkout ─► test-auth (Go)    ┐                                        │
   │          ─► test-search (Py)  ├─► build ×4 (kaniko) ─► bump-tags ─► deploy │
   │          ─► test-products (Rb)┘     push to registry     git push      wait │
   └──────────────────────────────────────────────────┬─────────────────────┘
                                                      ▼
                  Argo CD app "shop" watches application/k8s ─► namespace shop
```

| Piece | Where |
|-------|-------|
| Registry | `registry/registry.yaml` — ns `registry`; pods push to `registry.registry.svc.cluster.local:5000`, kubelet pulls `localhost:30500` |
| Pipeline | `workflows/shop-ci.yaml` (WorkflowTemplate in ns `argo`) + `workflows/rbac.yaml` (lets it refresh Argo CD apps) |
| Argo CD app | `argocd/shop-app.yaml` — auto-sync, prune, self-heal, path `application/k8s` |

Image tag = first 8 chars of the commit SHA. The pipeline commits the new tags to
`application/k8s/kustomization.yaml` (`[skip ci]` in message), Argo CD syncs that commit.

## One-time setup

1. Push this `lab/` directory to a GitHub repo (branch `main`).
2. Create a fine-grained GitHub token for that repo with **Contents: Read and write**.
3. Create the secrets **in your own terminal** (keeps the token out of chat/shell logs):

   ```bash
   export KUBECONFIG=~/.kube/k3s.yaml
   read -rs GH_TOKEN; read -r GH_USER
   # pipeline: clone + push tag bumps
   kubectl -n argo create secret generic github-credentials \
     --from-literal=username="$GH_USER" --from-literal=token="$GH_TOKEN"
   # Argo CD: only needed if the repo is private
   kubectl -n argocd create secret generic repo-shop \
     --from-literal=type=git --from-literal=url=https://github.com/OWNER/REPO.git \
     --from-literal=username="$GH_USER" --from-literal=password="$GH_TOKEN"
   kubectl -n argocd label secret repo-shop argocd.argoproj.io/secret-type=repository
   unset GH_TOKEN
   ```

4. `REPO_URL=https://github.com/OWNER/REPO.git ./setup.sh`

## Run

```bash
REPO_URL=https://github.com/OWNER/REPO.git ./run-pipeline.sh      # or: Argo UI → Workflow Templates → shop-ci → Submit
```

- Argo Workflows: http://argo-workflows.localhost
- Argo CD:        http://argocd.localhost
- App:            http://shop.localhost

## Notes

- Registry is plain HTTP and unauthenticated — lab only.
- Kaniko layer cache lives in `<registry>/cache`.
- Pipeline is triggered manually; add Argo Events + a GitHub webhook for push-triggered runs.
