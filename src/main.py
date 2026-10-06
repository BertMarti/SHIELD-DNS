from fastapi import FastAPI

app = FastAPI(title="SHIELD-DNS - Ad Blocker")

@app.get("/health")
def health():
    return {"status": "ok", "service": "shield-dns"}

@app.post("/api/blocklist/add")
def add_blocklist(url: str):
    # TODO: Agregar lista de bloqueo
    return {"message": f"Blocklist added: {url}"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
