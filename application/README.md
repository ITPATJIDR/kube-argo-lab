# Gosoft Lab Shop — microservices demo

```
browser ──► Traefik ingress (shop.localhost)
              └─► frontend (nginx :8080)  static SPA + reverse proxy
                    ├─ /api/auth/*     ─► auth     (Go       :8080)
                    ├─ /api/products*  ─► products (Ruby     :4567)
                    └─ /api/search*    ─► search   (Python   :8000) ─► products
```

| Service  | Language / stack        | Endpoints |
|----------|-------------------------|-----------|
| frontend | nginx + vanilla JS      | `/` UI, proxies `/api/*` |
| auth     | Go 1.23 (stdlib)        | `POST /api/auth/login`, `GET /api/auth/verify` (Bearer) |
| products | Ruby 3.3 + Sinatra/Puma | `GET /api/products[?category=]`, `GET /api/products/:id` |
| search   | Python 3.12 + FastAPI   | `GET /api/search?q=` (queries products service) |

All services expose `GET /healthz`. Demo users: `alice/alice123`, `bob/bob123`.

## Layout

```
application/
├── frontend/            Dockerfile, nginx.conf (template), index.html
├── services/
│   ├── auth/            Go
│   ├── products/        Ruby
│   └── search/          Python
├── k8s/                 kustomize: namespace shop, 4 Deployments+Services, Ingress, auth Secret
└── build.sh             podman build all + export dist/shop-images.tar
```

## Build & deploy to k3s

```bash
./build.sh                                              # build with podman
sudo k3s ctr images import dist/shop-images.tar         # load into k3s containerd (root)
KUBECONFIG=~/.kube/k3s.yaml kubectl apply -k k8s
```

Open http://shop.localhost

> Fedora: if the ingress returns 502, trust the k3s pod/service CIDRs in firewalld —
> see `../argo/README.md`.

## Run locally without Kubernetes (podman pod)

```bash
podman pod create --name shop -p 18080:8080
podman run -d --pod shop -e PORT=8081 localhost/shop-auth:0.1.0
podman run -d --pod shop localhost/shop-products:0.1.0
podman run -d --pod shop -e PRODUCTS_URL=http://127.0.0.1:4567 localhost/shop-search:0.1.0
podman run -d --pod shop -e AUTH_HOST=127.0.0.1:8081 -e PRODUCTS_HOST=127.0.0.1:4567 \
  -e SEARCH_HOST=127.0.0.1:8000 localhost/shop-frontend:0.1.0
# http://localhost:18080   — cleanup: podman pod rm -f shop
```

## Notes (lab only)

- `AUTH_SECRET` is a literal in `k8s/kustomization.yaml`; tokens are HMAC-signed, 1h TTL.
- Users and products are hard-coded / JSON file — no database.
