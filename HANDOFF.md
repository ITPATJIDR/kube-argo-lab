# Handoff — kube-argo-lab

แลบ GitOps บน k3s ในเครื่องเดียว: แอป microservice 4 ตัว ใช้ **Argo Workflows** (CI) build และทดสอบ, ใช้ **Argo CD** (CD) deploy และใช้ **Argo Rollouts** ทำ canary ให้ frontend

Repo: https://github.com/ITPATJIDR/kube-argo-lab (public, branch `main`)

---

## 1. ภาพรวม

```
 dev ── git push ──► GitHub (main)
                        │
      Submit pipeline   │ clone
            ▼           ▼
 ┌──────────── Argo Workflows: shop-ci (ns argo) ────────────────────────────┐
 │ checkout ─► test-auth (Go) ┐                                               │
 │          ─► test-search (Py)├─► build ×4 (kaniko) ─► bump-tags ─► deploy   │
 │          ─► test-products(Rb)┘    push registry       git push    รอ Synced │
 └───────────────────────────────────────┬───────────────────────────────────┘
                                          │ commit "ci: deploy shop images <sha> [skip ci]"
                                          ▼
                         Argo CD app "shop" (ดู application/k8s)
                                          ▼
 ns shop:  frontend (Argo Rollout canary) ─► auth (Go) / products (Ruby) / search (Python)
           Traefik IngressRoute shop.localhost ─► TraefikService frontend-split (stable/canary)
```

### Components

| Component | Version | Namespace | URL |
|---|---|---|---|
| k3s (มี Traefik + ServiceLB + local-path) | v1.37.2+k3s1 | kube-system | — |
| Argo CD | chart `argo/argo-cd` 10.18.2 (v3.6.2) | argocd | http://argocd.localhost |
| Argo Workflows | chart `argo/argo-workflows` 2.0.18 (v4.1.6) | argo | http://argo-workflows.localhost |
| Argo Rollouts + dashboard | chart `argo/argo-rollouts` 2.43.12 (v1.10.2) | argo-rollouts | http://argo-rollouts.localhost |
| Docker registry (HTTP) | registry:2.8.3 | registry | push: `registry.registry.svc.cluster.local:5000`, pull: `localhost:30500` |
| Shop app | tag = commit SHA 8 ตัวแรก | shop | http://shop.localhost |

### แอป shop

| Service | Stack | Port | Endpoints |
|---|---|---|---|
| frontend | nginx + vanilla JS (**Argo Rollout**) | 8080 | `/`, proxy `/api/*` |
| auth | Go 1.23 stdlib | 8080 | `POST /api/auth/login`, `GET /api/auth/verify` |
| products | Ruby 3.3 + Sinatra | 4567 | `GET /api/products[?category=]`, `/api/products/:id` |
| search | Python 3.12 + FastAPI | 8000 | `GET /api/search?q=` (เรียก products) |

ผู้ใช้ทดสอบ: `alice/alice123`, `bob/bob123` · ทุก service มี `GET /healthz`

---

## 2. โครงสร้าง repo

```
lab/
├── HANDOFF.md                  ← ไฟล์นี้
├── argo/                       ติดตั้ง Argo ทั้ง 3 ตัวด้วย helm
│   ├── install.sh / uninstall.sh
│   ├── argocd/values.yaml          (Traefik ingress, server.insecure, ปิด dex)
│   ├── argo-workflows/values.yaml  (authModes: server = ไม่ต้อง login, workflowNamespaces: argo)
│   ├── argo-rollouts/values.yaml   (เปิด dashboard + ingress)
│   └── examples/hello-world.yaml
├── application/                โค้ดและ manifest ของแอป
│   ├── frontend/  services/{auth,products,search}/   (แต่ละตัวมี Dockerfile)
│   ├── k8s/                    kustomize ← Argo CD sync โฟลเดอร์นี้
│   │   ├── kustomization.yaml      (บล็อก images: ← pipeline แก้ newTag ตรงนี้)
│   │   ├── frontend.yaml           (Rollout + Service frontend-stable / frontend-canary)
│   │   └── frontend-traffic.yaml   (TraefikService frontend-split + IngressRoute)
│   └── build.sh                ใช้ build ด้วย podman ในเครื่อง (ไม่จำเป็นสำหรับ flow ปกติ)
└── cicd/
    ├── registry/registry.yaml  registry ในคลัสเตอร์ (NodePort 30500, PVC 20Gi)
    ├── workflows/shop-ci.yaml  WorkflowTemplate ของ pipeline
    ├── workflows/rbac.yaml     ให้ SA argo-workflow สั่ง refresh และอ่าน Argo CD app ได้
    ├── argocd/shop-app.yaml    Argo CD Application (auto-sync, prune, selfHeal, ignoreDifferences ของ weight)
    ├── setup.sh                apply ทุกอย่างใน cicd/ (ต้องตั้ง REPO_URL)
    └── run-pipeline.sh         สั่งรัน pipeline (ไม่ต้องมี argo CLI)
```

สคริปต์ทุกตัวใช้ kubeconfig ที่ **`~/.kube/k3s.yaml`** (เปลี่ยนได้ด้วย `KUBECONFIG_K3S`) และจะไม่ไปยุ่งกับ `~/.kube/config`

---

## 3. ติดตั้งบนเครื่องใหม่

### สิ่งที่ต้องมี
- Linux x86_64 · RAM 4GB ขึ้นไป · 2 CPU ขึ้นไป · ดิสก์ว่างประมาณ 20GB
- พอร์ต **80, 443, 30500** ต้องว่าง
- `git`, `helm` 3.x, `kubectl` (ใช้ `sudo k3s kubectl` แทนได้)
- สิทธิ์ sudo
- GitHub fine-grained token ของ repo นี้ สิทธิ์ **Contents: Read and write**
- **ไม่ต้อง**มี podman หรือ Docker เพราะ pipeline build ในคลัสเตอร์

### ขั้นตอน

```bash
# 1) k3s  (ต้องใช้ root · ต้องรันใน terminal จริง เพราะ sudo ต้องถามรหัสผ่าน)
curl -sfL https://get.k3s.io | sudo sh -
mkdir -p ~/.kube
sudo cat /etc/rancher/k3s/k3s.yaml | sed 's/: default$/: k3s/' > ~/.kube/k3s.yaml
chmod 600 ~/.kube/k3s.yaml

# 2) Fedora/RHEL ที่เปิด firewalld เท่านั้น — ถ้าไม่ทำ pod คุยกันไม่ได้ ingress จะได้ 502
sudo firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
sudo firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16
sudo firewall-cmd --reload

# 3) clone
git clone https://github.com/ITPATJIDR/kube-argo-lab.git && cd kube-argo-lab

# 4) Argo CD + Workflows + Rollouts  (ตอนจบจะแสดงรหัส admin ของ Argo CD)
./argo/install.sh

# 5) GitHub token ให้ pipeline ใช้ push tag กลับ (อย่าวาง token ในแชทหรือไฟล์)
export KUBECONFIG=~/.kube/k3s.yaml
read -rs GH_TOKEN
kubectl -n argo create secret generic github-credentials \
  --from-literal=username=ITPATJIDR --from-literal=token="$GH_TOKEN"
unset GH_TOKEN

# 6) registry + pipeline + Argo CD app
export REPO_URL=https://github.com/ITPATJIDR/kube-argo-lab.git
./cicd/setup.sh

# 7) รัน pipeline รอบแรก เพื่อ build image ลง registry ของเครื่องนี้
./cicd/run-pipeline.sh
```

> หลังขั้น 6 pod ใน `shop` จะเป็น `ImagePullBackOff` ไปก่อน เพราะ registry ยังว่าง
> พอ pipeline ขั้น 7 เสร็จจะหายเอง

### (ถ้าต้องการ) kubectl plugin ของ Argo Rollouts
```bash
V=v1.10.2; U=https://github.com/argoproj/argo-rollouts/releases/download/$V
curl -fLO $U/kubectl-argo-rollouts-linux-amd64 && curl -fsL $U/argo-rollouts-checksums.txt | sha256sum -c --ignore-missing
install -m 755 kubectl-argo-rollouts-linux-amd64 ~/.local/bin/kubectl-argo-rollouts && rm kubectl-argo-rollouts-linux-amd64
```

### ตรวจว่าติดตั้งครบ
```bash
export KUBECONFIG=~/.kube/k3s.yaml
kubectl get nodes                                   # Ready
kubectl -n argo get wf                              # shop-ci-xxxxx  Succeeded
kubectl -n argocd get application shop              # Synced  Healthy
curl -s "http://shop.localhost/api/search?q=ssd"    # ได้ JSON 1 รายการ
```

---

## 4. ใช้งานประจำวัน

| อยากทำอะไร | ทำยังไง |
|---|---|
| แก้**โค้ด** (`application/services`, `application/frontend`) | push → **รัน pipeline** (`./cicd/run-pipeline.sh` หรือ UI → Workflow Templates → shop-ci → Submit) |
| แก้ **manifest** (`application/k8s`, เช่น replicas, env) | push อย่างเดียว แล้ว Argo CD sync เองภายใน 2 นาที หรือกด Refresh |
| รันซ้ำด้วย commit ล่าสุด | UI → workflow เดิม → **Resubmit** |
| รันขั้นที่พังซ้ำ โดยใช้ commit เดิม | **Retry** (ใช้กับปัญหาชั่วคราวเท่านั้น) |
| canary ของ frontend | ระหว่าง rollout จะหยุดที่ 10% และ 50% ให้กด **Promote** ใน http://argo-rollouts.localhost หรือ `kubectl argo rollouts promote frontend -n shop` |
| ยกเลิก canary | **Abort** (traffic กลับไป stable 100% ทันที) |
| ข้ามทุกขั้นไป 100% | **Promote-Full** หรือใส่ `--full` |

**กฎสำคัญ**
- **`git pull` ทุกครั้งก่อนแก้** เพราะ pipeline push commit `ci: deploy shop images ...` ขึ้นไปทุกรอบที่ผ่าน
- **ห้าม** `kubectl edit`, `scale`, หรือ `set image` ของใน `shop` เอง เพราะ Argo CD เปิด selfHeal ไว้ จะแก้กลับให้ตรงกับ Git ต้องแก้ผ่าน Git เท่านั้น ยกเว้น promote และ abort ของ Rollout ที่ทำได้
- canary จะเริ่มเฉพาะเมื่อ **pod template เปลี่ยน** เช่นเปลี่ยน image หรือ env ถ้าแก้แค่ `steps` จะไม่เริ่ม และตอนสร้าง Rollout ครั้งแรกจะขึ้น 100% ทันที
- ดูว่า traffic แบ่งจริงไหม ใช้ curl ดีกว่า browser (browser มี cache และใช้ connection เดิม)
  ```bash
  for i in $(seq 50); do curl -s http://shop.localhost/ | grep -o 'Lab Shop[^<]*'; done | sort | uniq -c
  ```

---

## 5. Secrets และข้อมูลที่ไม่อยู่ใน Git

| อะไร | อยู่ที่ไหน | หมายเหตุ |
|---|---|---|
| GitHub token | secret `argo/github-credentials` (`username`, `token`) | สร้างเองที่แต่ละเครื่อง |
| รหัส admin ของ Argo CD | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d` | ได้ใหม่ทุกครั้งที่ติดตั้ง ควรเปลี่ยนหลัง login |
| `AUTH_SECRET` ของ auth | literal ใน `application/k8s/kustomization.yaml` | **ใช้ได้แค่ในแลบ** งานจริงต้องย้ายไป Sealed Secrets หรือ External Secrets |
| image | registry ในคลัสเตอร์ (PVC) | ไม่ได้ย้ายไปด้วย pipeline จะ build ใหม่ให้ |

---

## 6. ปัญหาที่เคยเจอและวิธีแก้

| อาการ | สาเหตุ | วิธีแก้ |
|---|---|---|
| ingress ได้ 502, pod ขึ้น `No route to host`, DNS ในคลัสเตอร์ใช้ไม่ได้ | firewalld บล็อก CIDR ของ pod และ service | ขั้น 2 ในหัวข้อ 3 |
| `sudo: a terminal is required` | รัน sudo ผ่าน `!` ใน Claude Code ซึ่งไม่มี TTY ให้ใส่รหัสผ่าน | รันใน terminal ปกติ |
| kaniko: `please provide a valid path to a Dockerfile` แล้ว log มี `{{workflow.parameters.app-dir}}` | กด **Retry** กับ workflow ที่สร้างตอนส่ง parameter ไม่ครบ ตอน Retry, Argo จะไม่เติมค่า default ของ template ให้ | สร้างใหม่ด้วย Submit หรือ Resubmit (`run-pipeline.sh` ตอนนี้ส่งครบทุกตัวแล้ว) |
| `bump-tags`: `could not read Username` หรือ `secret argo/github-credentials ... is required` | ยังไม่มี token secret | ขั้น 5 ในหัวข้อ 3 |
| `git push` จากเครื่อง dev ถูก reject | pipeline push commit ขึ้นไปก่อนแล้ว | `git pull --rebase` แล้วค่อย push |
| pod ขึ้น `ImagePullBackOff` หลังติดตั้งใหม่ | registry ยังว่าง | รัน pipeline หนึ่งรอบ |
| `curl localhost:30500` ไม่ตอบ | `localhost` ไปที่ ::1 แต่ NodePort ฟังแค่ IPv4 | ใช้ `127.0.0.1:30500` |
| ไม่มีปุ่ม Promote | ไม่มี canary ค้างอยู่ (เป็น revision แรก หรือ promote ไปแล้ว) | push การเปลี่ยนโค้ดแล้วรัน pipeline |
| Argo CD กับ Rollouts แก้ weight สลับกันไปมา | Argo CD มองว่า weight ที่เปลี่ยนเป็น drift | ใช้ `ignoreDifferences` และ `RespectIgnoreDifferences` (มีอยู่ใน `cicd/argocd/shop-app.yaml` แล้ว) |
| kubectl ขึ้นเตือนเรื่อง version | kubectl จาก dnf (1.27) เก่ากว่า server (1.37) มาก | ใช้ `sudo k3s kubectl` หรืออัปเดต kubectl |
| ลบ tag ใน registry แล้ว tag อื่นหายไปด้วย | registry ลบตาม **digest** ถ้า tag ไหนชี้ digest เดียวกันจะหายหมด | อย่าลบ manifest ที่มีหลาย tag ใช้ digest ร่วมกัน |

---

## 7. ข้อจำกัดที่รู้อยู่แล้ว

- **ใช้ repo เดียวกับหลายเครื่องพร้อมกันไม่ได้**: แต่ละเครื่องมี registry ของตัวเอง ถ้าเครื่อง A push tag ใหม่ Argo CD ของเครื่อง B จะดึง tag ที่ registry ของ B ไม่มี ทางแก้คือแยก branch ต่อเครื่อง (`targetRevision` และ parameter `revision`) หรือใช้ registry กลาง เช่น GHCR
- pipeline ยัง**ต้องกดสั่งรันเอง** ถ้าจะให้รันอัตโนมัติตอน push ต้องติดตั้ง Argo Events และตั้ง GitHub webhook ซึ่งต้องให้ GitHub เข้าถึงเครื่องจากภายนอกได้
- canary **ยังไม่มี analysis อัตโนมัติ** เพราะยังไม่มี Prometheus ตอนนี้ต้องดูเองแล้วกด promote
- canary ใช้ได้แค่ **traffic ที่เข้าจากข้างนอก** มาที่ frontend เท่านั้น การเรียกกันเองระหว่าง service (search → products) ต้องใช้ service mesh
- ไม่มี auth บน UI ของ Argo Workflows และ dashboard ของ Rollouts registry เป็น HTTP และไม่มี auth ใช้ได้แค่ในแลบ
- `*.localhost` ใช้ได้แค่บนเครื่องที่รัน k3s ถ้าจะเปิดจากเครื่องอื่นต้องแก้ไฟล์ hosts ให้ชี้ไปที่ IP ของ node

---

## 8. ถอนการติดตั้ง

```bash
export KUBECONFIG=~/.kube/k3s.yaml
kubectl -n argocd delete application shop      # app ไม่มี finalizer → ไม่ลบ resource ให้
kubectl delete namespace shop
kubectl delete -f cicd/registry/registry.yaml
./argo/uninstall.sh
# ถอน k3s ทั้งหมด (ต้องใช้ root)
sudo /usr/local/bin/k3s-uninstall.sh
```
