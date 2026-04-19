
# Agentic RAG Azure Infrastructure Setup

This document provisions a basic Agentic RAG playground infrastructure on Azure using Azure CLI.
fully functional production-style setup:
✅ Infrastructure
```
Azure VMs (2× Standard_D2s_v3)
Same VNet / subnet
firewalld + NSG correctly configured

✅ LLM VM (vm-llm-phi3)

Ollama running under azureuser
$HOME correctly set
Bound to network (0.0.0.0:11434)
Model phi3:mini pulled and served
Reachable from other VM ✅

✅ RAG VM (vm-rag-api)

FastAPI running under systemd
LangChain + Chroma initialized
SQLite compatibility handled
Correct Ollama base_url (private IP)
/ask endpoint returning real LLM answers ✅

## Resource Group

```bash
RG=1-b3298272-playground-sandbox  ## ( depends on RG in created earlir in environement)
```
## Virtual Network & Subnet

```bash
az network vnet create \
  --resource-group $RG \
  --name vnet-agentic \
  --address-prefix 10.0.0.0/16 \
  --subnet-name subnet-rag \
  --subnet-prefix 10.0.1.0/24
```
## Virtual Machines
### LLM VM (Phi-3 / Ollama Host)
```bash
az vm create \
  --resource-group $RG \
  --name vm-llm-phi3 \
  --image RedHat:RHEL:9_3:latest \
  --size Standard_D2s_v3 \
  --admin-username azureuser \
  --generate-ssh-keys \
  --vnet-name vnet-agentic \
  --subnet subnet-rag \
  --nsg-rule SSH
```
### RAG API VM

```bash
az vm create \
  --resource-group $RG \
  --name vm-rag-api \
  --image RedHat:RHEL:9_3:latest \
  --size Standard_D2s_v3 \
  --admin-username azureuser \
  --generate-ssh-keys \
  --vnet-name vnet-agentic \
  --subnet subnet-rag \
  --nsg-rule SSH
```
## Network Security Group (NSG) Rules
### Allow Ollama Traffic (11434) from RAG Subnet to LLM VM

```bash
az network nsg rule create \
  --resource-group $RG \
  --nsg-name vm-llm-phi3NSG \
  --name AllowOllamaFromRAG \
  --priority 100 \
  --protocol Tcp \
  --destination-port-ranges 11434 \
  --source-address-prefixes 10.0.1.0/24 \
  --access Allow
```
### Allow RAG API Traffic (8000) to RAG VM 
```bash
az network nsg rule create \
  --resource-group $RG \
  --nsg-name vm-rag-apiNSG \
  --name AllowRAGAPI \
  --priority 100 \
  --protocol Tcp \
  --destination-port-ranges 8000 \
  --access Allow
```
## update FS size for each VM 
### update FS size vm-llm-phi3
```bash
 sudo lvextend -L +10G /dev/mapper/rootvg-homelv
 sudo xfs_growfs  /home
 sudo lvextend -L +10G  /dev/mapper/rootvg-rootlv
 sudo xfs_growfs  /
 sudo lvextend -L +10G  /dev/mapper/rootvg-tmplv
 sudo xfs_growfs /tmp

```

### update FS size vm-rag-api
```bash
 sudo lvextend -L +10G /dev/mapper/rootvg-homelv
 sudo xfs_growfs  /home
 sudo lvextend -L +10G  /dev/mapper/rootvg-rootlv
 sudo xfs_growfs  /
 sudo lvextend -L +10G  /dev/mapper/rootvg-tmplv
 sudo xfs_growfs /tmp

```

## deployment commands 
### on VM1 
```bash
#Install dependencies
sudo dnf update -y
sudo dnf install -y curl zstd
#Install Ollama
curl -fsSL https://ollama.com/install.sh | sh
ollama --version
#Pull the model
ollama pull phi3:mini
```
####Ollama systemd service (memory‑safe)

```bash
sudo tee /etc/systemd/system/ollama.service > /dev/null << 'EOF'
[Unit]
Description=Ollama LLM Runtime
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=azureuser
Group=azureuser
Environment="HOME=/home/azureuser"
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_KEEP_ALIVE=5m"
WorkingDirectory=/home/azureuser
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
```
### Edit the systemd override (overwrite it)
```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null << 'EOF'
[Service]
Environment="HOME=/home/azureuser"
Environment="OLLAMA_HOST=0.0.0.0"
EOF
```



#### Start Service
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now ollama
sudo systemctl stop ollama
sudo pkill -9 ollama || true
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl start ollama
```
#### VERIFY bind (this is the success gate)
```bash
ss -lntp | grep 11434
```
### updated firewall on vm‑llm‑phi3:
```bash
sudo firewall-cmd --list-ports 
sudo firewall-cmd --add-port=11434/tcp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```
#### You must see:
##### 11434/tcp
### output 
```bash
LISTEN ... 0.0.0.0:11434
or 
LISTEN ... *:11434
#Test with curl  
curl http://localhost:11434/api/tags
# output
{"models":[{"name":"phi3:mini", ...}]}
```
### VM‑2 (vm-rag-api) : Agentic RAG API
```bash
sudo dnf update -y
sudo dnf install -y \
  python3.11 python3.11-devel \
  gcc gcc-c++ make git
```
sudo systemctl restart agentic-rag



####  Final step: your RAG API will now work
```bash
curl http://localhost:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"agent_type":"engineering","question":"How does auth work?"}'
```
##### Expected result
{
  "answer": "The authentication service uses a microservices architecture with JWT-based stateless authentication and gRPC for service-to-service communication."
}



🔥 High‑Impact SRE Agent Questions (Incident & Ops)
🚨 Incident Response

“We are seeing intermittent 500 errors in prod. What should be checked first?”
“API latency suddenly increased after the last deployment. What diagnostics should we run?”
“Users report login failures. Which services and dependencies should be validated?”
“A pod is restarting frequently. What are the likely causes and next steps?”
“Traffic dropped sharply in the last 10 minutes. How do we verify if it’s an infra issue or upstream dependency?”


📊 Reliability & SLO/SLA

“What actions should be taken if we are close to breaching the SLO for availability?”
“Which metrics are most important to monitor for checkout service reliability?”
“How do we analyze SLI trends to predict potential outages?”
“What is the recommended response when error budget burn rate spikes?”


🧠 Root Cause Analysis (RCA)

“How do we perform RCA for a database-related outage?”
“What data should be captured during an incident to support postmortem analysis?”
“How can we differentiate between code defects and infrastructure failures during RCA?”
“What questions should be answered in a blameless postmortem?”


🔧 Operational Runbooks

“We see high memory usage on application nodes. What runbook steps should be followed?”
“Redis cache eviction rate increased suddenly. What should we investigate?”
“How should we safely restart a critical service during business hours?”
“What is the standard rollback procedure after a failed deployment?”


🛠️ Automation & Self‑Healing

“Which alerts are good candidates for auto‑remediation?”
“How can we automate detection and restart of unhealthy services?”
“What safeguards should be in place before enabling self‑healing actions?”


☁️ Cloud & Infrastructure

“What are common causes of VM performance degradation in Azure?”
“How do we validate network connectivity issues between microservices?”
“What checks should be done when a load balancer stops routing traffic correctly?”
