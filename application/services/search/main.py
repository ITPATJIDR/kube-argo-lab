"""search service: full-text search over the catalog served by the products service."""
import os

import httpx
from fastapi import FastAPI, HTTPException, Query

PRODUCTS_URL = os.getenv("PRODUCTS_URL", "http://products:4567")

app = FastAPI(title="search")


@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": "search"}


@app.get("/api/search")
async def search(q: str = Query("", max_length=100)):
    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.get(f"{PRODUCTS_URL}/api/products")
            resp.raise_for_status()
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"products service unavailable: {exc}")

    items = resp.json()["items"]
    terms = q.lower().split()
    if terms:
        def matches(p):
            text = f"{p['name']} {p['category']} {p['description']}".lower()
            return all(t in text for t in terms)
        items = [p for p in items if matches(p)]

    return {"query": q, "count": len(items), "items": items}
