
# Agentic RAG Azure Infrastructure Setup

This document provisions a basic Agentic RAG playground infrastructure on Azure using Azure CLI.

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
### update FS size vm-rag-api
```bash
 sudo lvextend -L +10G /dev/mapper/rootvg-homelv
 sudo xfs_growfs  /home
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
vi /etc/systemd/system/ollama.service
```
#### update the file & save
```bash
[Unit]
Description=Ollama LLM Runtime
After=network-online.target

[Service]
ExecStart=/usr/bin/ollama serve
Restart=always
RestartSec=3

# Critical limits for 8GB systems
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_KEEP_ALIVE=5m"

[Install]
WantedBy=multi-user.target
```
#### Start Service
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now ollama
```
