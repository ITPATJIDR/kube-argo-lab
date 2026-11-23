# Argo CD + Argo Workflows + Argo Rollouts on local k3s

| Component      | Chart                      | App    | Namespace | URL                              |
|----------------|----------------------------|--------|-----------|----------------------------------|
| Argo CD        | argo/argo-cd 10.18.2       | v3.6.2 | argocd    | http://argocd.localhost          |
| Argo Workflows | argo/argo-workflows 2.0.18 | v4.1.6 | argo      | http://argo-workflows.localhost  |
| Argo Rollouts  | argo/argo-rollouts 2.43.12 | v1.10.2 | argo-rollouts | http://argo-rollouts.localhost |

```
argo/
├── argocd/values.yaml          # Argo CD values (Traefik ingress, HTTP, no dex)
├── argo-workflows/values.yaml  # Argo Workflows values (Traefik ingress, auth mode "server")
├── argo-rollouts/values.yaml   # Argo Rollouts controller + dashboard (Traefik ingress)
├── examples/hello-world.yaml   # sample Workflow
├── install.sh                  # helm upgrade --install both
└── uninstall.sh
```

Scripts always use `~/.kube/k3s.yaml` (override with `KUBECONFIG_K3S`), never the default kubeconfig.

## Install

```bash
./install.sh
```

Argo CD login: `admin` / password from
`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`

## Run the example workflow

```bash
export KUBECONFIG=~/.kube/k3s.yaml
kubectl create -f examples/hello-world.yaml
kubectl -n argo get wf
```

## Fedora: firewalld blocks pod-to-pod traffic

Symptom: ingress returns 502, pods get `No route to host`, in-cluster DNS fails.
Fix (one-time, needs root) — trust the k3s pod/service CIDRs:

```bash
sudo firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
sudo firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16
sudo firewall-cmd --reload
```

## kubectl plugin (Argo Rollouts)

```bash
V=v1.10.2; U=https://github.com/argoproj/argo-rollouts/releases/download/$V
curl -fLO $U/kubectl-argo-rollouts-linux-amd64 && curl -fsL $U/argo-rollouts-checksums.txt | sha256sum -c --ignore-missing
install -m 755 kubectl-argo-rollouts-linux-amd64 ~/.local/bin/kubectl-argo-rollouts && rm kubectl-argo-rollouts-linux-amd64
kubectl argo rollouts version
```

## Notes

- Argo Workflows UI runs with `authModes: [server]` (no login) — lab only.
- Argo Rollouts dashboard has no auth — lab only.
- Workflows run in namespace `argo` with ServiceAccount `argo-workflow`.
