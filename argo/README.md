# Argo CD + Argo Workflows on local k3s

| Component      | Chart                      | App    | Namespace | URL                              |
|----------------|----------------------------|--------|-----------|----------------------------------|
| Argo CD        | argo/argo-cd 10.18.2       | v3.6.2 | argocd    | http://argocd.localhost          |
| Argo Workflows | argo/argo-workflows 2.0.18 | v4.1.6 | argo      | http://argo-workflows.localhost  |

```
argo/
├── argocd/values.yaml          # Argo CD values (Traefik ingress, HTTP, no dex)
├── argo-workflows/values.yaml  # Argo Workflows values (Traefik ingress, auth mode "server")
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

## Notes

- Argo Workflows UI runs with `authModes: [server]` (no login) — lab only.
- Workflows run in namespace `argo` with ServiceAccount `argo-workflow`.
