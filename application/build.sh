#!/usr/bin/env bash
# Build all images with podman and export them to dist/ as an OCI archive for k3s import.
set -euo pipefail
cd "$(dirname "$0")"

TAG="${TAG:-0.1.0}"
mkdir -p dist

podman build -t "localhost/shop-auth:$TAG"     services/auth
podman build -t "localhost/shop-products:$TAG" services/products
podman build -t "localhost/shop-search:$TAG"   services/search
podman build -t "localhost/shop-frontend:$TAG" frontend

rm -f dist/shop-images.tar
podman save --multi-image-archive -o dist/shop-images.tar \
  "localhost/shop-auth:$TAG" "localhost/shop-products:$TAG" \
  "localhost/shop-search:$TAG" "localhost/shop-frontend:$TAG"

echo
echo "Images saved to dist/shop-images.tar"
echo "Import into k3s (needs root):  sudo k3s ctr images import $(pwd)/dist/shop-images.tar"
