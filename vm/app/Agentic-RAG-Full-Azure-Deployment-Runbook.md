# Agentic RAG (2‑VM) Deployment & Operations Runbook

> **Scope:** Single region, **two RHEL 9 VMs on Azure**, running a lightweight Agentic RAG stack:
> - **VM‑LLM**: Ollama + `phi3:mini`
> - **VM‑RAG**: FastAPI (Uvicorn) + LangChain + Chroma (persistent) + HuggingFace embeddings
>
> **Audience:** SRE / Platform / DevOps engineers.

---

## 0) Reference baseline

This runbook is adapted from the internal deployment‑guide structure in <File>Loop code block 2.loop</File> (TOC, agent split, use cases, and troubleshooting format). citeturn46search193

---

## 1) Architecture

### 1.1 Components

- **VM‑LLM (RHEL9)**
  - Ollama API: `http://<LLM_PRIVATE_IP>:11434`
  - Model: `phi3:mini`
  - Runs as a **systemd service** under `azureuser` to ensure `$HOME` is defined.

- **VM‑RAG (RHEL9)**
  - FastAPI app: `http://<RAG_PRIVATE_IP>:8000`
  - Endpoint: `POST /ask`
  - Vector store: Chroma (persisted to disk)
  - Embeddings: `sentence-transformers/all-MiniLM-L6-v2` (downloaded on first run)

### 1.2 Request flow (high level)

1. Client sends request to `VM‑RAG :8000/ask`
2. RAG app retrieves top‑K docs from Chroma
3. RAG app calls Ollama on `VM‑LLM :11434`
4. Returns answer

---

## 2) Prerequisites

### 2.1 Azure prerequisites

- 2× VMs in same VNet/subnet
- NSG rules:
  - VM‑RAG inbound: **TCP 8000** (source = your desired client scope)
  - VM‑LLM inbound: **TCP 11434** (source = VM‑RAG subnet or VM‑RAG private IP)

> **Note on sandbox subscriptions:** Some Azure playground / hands‑on‑lab subscriptions block inbound internet access even with NSG rules. Prefer VNet‑internal access or a non‑sandbox subscription for public exposure.

### 2.2 VM sizing

- Works on **Standard_D2s_v3** (2 vCPU / 8 GiB) when using `phi3:mini`.

### 2.3 OS packages

On both VMs:

```bash
sudo dnf update -y
sudo dnf install -y curl git zstd
```

On VM‑RAG (build dependencies for Python wheels):

```bash
sudo dnf install -y python3.11 python3.11-devel gcc gcc-c++ make
```

---

## 3) VM‑LLM: Ollama + phi3:mini

### 3.1 Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama --version
```

### 3.2 Configure systemd service (critical)

Ollama needs `$HOME` when running under systemd; if not set, it can crash/panic. Also, enabling network access requires `OLLAMA_HOST`. (Ollama documents configuring `OLLAMA_HOST` via systemd environment variables.) citeturn30search172turn30search170

Create `/etc/systemd/system/ollama.service`:

```ini
[Unit]
Description=Ollama LLM Runtime
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=azureuser
Group=azureuser
WorkingDirectory=/home/azureuser
Environment="HOME=/home/azureuser"
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Create the drop‑in override directory and file:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null << 'EOF'
[Service]
Environment="HOME=/home/azureuser"
Environment="OLLAMA_HOST=0.0.0.0"
EOF
```

Reload and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now ollama
sudo systemctl status ollama
```

Verify bind:

```bash
ss -lntp | grep 11434
curl http://localhost:11434/api/tags
```

### 3.3 Pull model

```bash
ollama pull phi3:mini
curl http://localhost:11434/api/tags
```

### 3.4 Host firewall

Allow port 11434:

```bash
sudo firewall-cmd --add-port=11434/tcp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

---

## 4) VM‑RAG: FastAPI + Chroma + LangChain

### 4.1 App layout

Recommended layout:

```
/opt/agentic-rag/
  app/main.py
  chroma/              # persistent DB
  venv/
```

```bash
sudo mkdir -p /opt/agentic-rag/{app,chroma}
sudo chown -R azureuser:azureuser /opt/agentic-rag
cd /opt/agentic-rag
python3.11 -m venv venv
source venv/bin/activate
pip install -U pip
```

### 4.2 Python dependencies

```bash
pip install fastapi uvicorn \
  langchain langchain-community langchain-ollama \
  langchain-huggingface sentence-transformers chromadb pysqlite3-binary
```

#### SQLite requirement (Chroma)

Chroma requires SQLite >= 3.35; on many enterprise Linux builds the bundled SQLite is older. Chroma’s troubleshooting recommends using `pysqlite3-binary` and overriding `sqlite3` before importing Chroma. citeturn30search157turn30search156

### 4.3 Application code (`/opt/agentic-rag/app/main.py`)

> Set the LLM base_url to the **LLM VM private IP**.

```python
import pysqlite3
import sys
sys.modules["sqlite3"] = pysqlite3

from fastapi import FastAPI
from pydantic import BaseModel
from langchain_ollama import OllamaLLM
from langchain_community.vectorstores import Chroma
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_core.documents import Document
import os

app = FastAPI(title="Agentic RAG – 2VM phi3:mini")

CHROMA_DIR = "/opt/agentic-rag/chroma"

docs = [
    Document(page_content="SRE RUNBOOK: For 500 errors, check DB connection, restart Redis then DB.", metadata={"source": "sre_manual.md"}),
    Document(page_content="ENGINEERING DESIGN: Auth service uses microservices, JWT and gRPC.", metadata={"source": "engineering_design.md"}),
    Document(page_content="SLO POLICY: Checkout requires 99.9% availability, P95 < 200ms.", metadata={"source": "slos.md"}),
]

embeddings = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")

if os.path.exists(CHROMA_DIR) and os.listdir(CHROMA_DIR):
    vector_db = Chroma(persist_directory=CHROMA_DIR, embedding_function=embeddings)
else:
    vector_db = Chroma.from_documents(docs, embeddings, persist_directory=CHROMA_DIR)
    vector_db.persist()

llm = OllamaLLM(
    model="phi3:mini",
    base_url="http://<LLM_PRIVATE_IP>:11434",
    temperature=0.3,
)

class Query(BaseModel):
    agent_type: str
    question: str

@app.post("/ask")
def ask(q: Query):
    results = vector_db.similarity_search(q.question, k=1)
    context = results[0].page_content if results else "No internal documentation found."

    persona = "You are an expert Site Reliability Engineer." if q.agent_type == "sre" else "You are a Lead Software Engineer."

    prompt = f"""
ROLE: {persona}
INTERNAL DOCS: {context}
QUESTION: {q.question}

Answer concisely.
"""

    return {"answer": llm.invoke(prompt)}
```

### 4.4 Run as a systemd service

Create `/etc/systemd/system/agentic-rag.service`:

```ini
[Unit]
Description=Agentic RAG API
After=network-online.target

[Service]
Type=simple
User=azureuser
Group=azureuser
WorkingDirectory=/opt/agentic-rag
Environment="HOME=/home/azureuser"
ExecStart=/opt/agentic-rag/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now agentic-rag
sudo systemctl status agentic-rag
```

### 4.5 Host firewall

```bash
sudo firewall-cmd --add-port=8000/tcp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

---

## 5) Verification

### 5.1 Verify Ollama from VM‑RAG

```bash
curl http://<LLM_PRIVATE_IP>:11434/api/tags
```

### 5.2 Verify RAG API locally

```bash
curl http://localhost:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"agent_type":"engineering","question":"How does auth work?"}'
```

### 5.3 Verify from another host (same VNet)

```bash
curl http://<RAG_PRIVATE_IP>:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"agent_type":"sre","question":"We are seeing 500 errors. What should we check first?"}'
```

---

## 6) Common operational commands

### 6.1 Service control

```bash
sudo systemctl status ollama
sudo systemctl restart ollama
sudo journalctl -u ollama -n 100 --no-pager

sudo systemctl status agentic-rag
sudo systemctl restart agentic-rag
sudo journalctl -u agentic-rag -n 200 --no-pager
```

### 6.2 Check listening ports

```bash
ss -lntp | egrep '11434|8000'
```

---

## 7) Troubleshooting Guide

### T1) `No space left on device` during `pip install`

**Symptom:** pip fails with `OSError: [Errno 28] No space left on device`.

**Cause:** Temporary download/extract files go to `/tmp` and pip cache under `$HOME`.

**Fix:** Redirect temp/cache to a larger mount (example `/mnt`) and retry.

```bash
mkdir -p /mnt/pip-tmp /mnt/pip-cache
export TMPDIR=/mnt/pip-tmp
export PIP_CACHE_DIR=/mnt/pip-cache
pip install <packages>
```

### T2) Chroma error: `sqlite3 >= 3.35.0` required

**Symptom:**

```
RuntimeError: ... requires sqlite3 >= 3.35.0
```

**Fix:** Install `pysqlite3-binary` and override `sqlite3` before importing Chroma. citeturn30search157turn30search156

### T3) Ollama binds only to localhost (`127.0.0.1:11434`)

**Symptom:** `ss -lntp | grep 11434` shows `127.0.0.1:11434`; remote curl fails.

**Fix:** Set `OLLAMA_HOST=0.0.0.0` via systemd environment and restart. Ollama documents using environment variables for server config and the `systemctl edit` pattern. citeturn30search172turn23search152

### T4) Ollama fails under systemd: `panic: $HOME is not defined`

**Fix:** Run Ollama as a real user and set `HOME` in the service environment. Similar fixes are discussed in Ollama issue threads and guides. citeturn30search170turn30search172

### T5) systemd: `Start request repeated too quickly`

**Cause:** The service failed repeatedly; systemd hit StartLimit.

**Fix:** Inspect logs, fix root cause, then reset the failed counter:

```bash
sudo journalctl -u <service> -n 200 --no-pager
sudo systemctl reset-failed <service>
sudo systemctl restart <service>
```

This is standard systemd behavior and recovery guidance. citeturn30search162turn30search164

### T6) Uvicorn bind error: `Address already in use`

**Fix:** Identify PID and stop it, then restart the service.

```bash
sudo ss -lntp | grep 8000
sudo kill -9 <PID>
```

### T7) RAG returns `Internal Server Error`

**Most common causes:**
- LLM VM unreachable (wrong IP/port, firewall/NSG)
- LLM model not pulled (`phi3:mini` missing)
- Chroma persistence dir permissions

**Workflow:**

```bash
# 1) Confirm RAG service logs
sudo journalctl -u agentic-rag -n 200 --no-pager

# 2) Confirm Ollama reachable from RAG VM
curl http://<LLM_PRIVATE_IP>:11434/api/tags

# 3) Confirm model exists
# (If models empty, pull on LLM VM as service user)
ollama pull phi3:mini
```

### T8) External access times out even though NSG/firewalld look correct

If you’re using a **playground/sandbox subscription**, inbound internet may be blocked by platform policy. Use VNet‑internal access (private IP) or a standard subscription for public exposure.

---

## 8) Example requests

### SRE agent

```bash
curl http://<RAG_PRIVATE_IP>:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"agent_type":"sre","question":"We are seeing intermittent 500 errors. What should we check first?"}'
```

### Engineering agent

```bash
curl http://<RAG_PRIVATE_IP>:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"agent_type":"engineering","question":"How does auth work?"}'
```

---

## 9) Notes / Future improvements

The internal guide <File>Loop code block 2.loop</File> includes richer multi-service patterns (Redis session memory, Postgres incident history, hybrid search, etc.). Consider aligning your next iteration to that reference architecture if you expand beyond a local two‑VM POC. citeturn46search193
 
