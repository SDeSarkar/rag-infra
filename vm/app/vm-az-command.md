
RG=1-b3298272-playground-sandbox

# Agentic RAG Azure Infrastructure Setup

This document provisions a basic Agentic RAG playground infrastructure on Azure using Azure CLI.

## Resource Group

```bash
RG=1-b3298272-playground-sandbox

## Virtual Network & Subnet

az network vnet create \
  --resource-group $RG \
  --name vnet-agentic \
  --address-prefix 10.0.0.0/16 \
  --subnet-name subnet-rag \
  --subnet-prefix 10.0.1.0/24



















az network vnet create   --resource-group $RG   --name vnet-agentic   --address-prefix 10.0.0.0/16   --subnet-name subnet-rag   --subnet-prefix 10.0.1.0/24 
az vm create   --resource-group $RG   --name vm-llm-phi3   --image RedHat:RHEL:9_3:latest   --size Standard_D2s_v3   --admin-username azureuser   --generate-ssh-keys   --vnet-name vnet-agentic   --subnet subnet-rag   --nsg-rule SSH
az vm create   --resource-group $RG   --name vm-rag-api   --image RedHat:RHEL:9_3:latest   --size Standard_D2s_v3   --admin-username azureuser   --generate-ssh-keys   --vnet-name vnet-agentic   --subnet subnet-rag   --nsg-rule SSH
az network nsg rule create   --resource-group $RG   --nsg-name vm-llm-phi3NSG   --name AllowOllamaFromRAG   --priority 100   --protocol Tcp   --destination-port-ranges 11434   --source-address-prefixes 10.0.1.
az network nsg rule create   --resource-group $RG   --nsg-name vm-llm-phi3NSG   --name AllowOllamaFromRAG   --priority 100   --protocol Tcp   --destination-port-ranges 11434   --source-address-prefixes 10.0.1.0/24
az network nsg rule create   --resource-group rg-agentic-rag   --nsg-name vm-rag-apiNSG   --name AllowRAGAPI   --priority 100   --protocol Tcp   --destination-port-ranges 8000 \
az network nsg rule create   --resource-group $RG   --nsg-name vm-rag-apiNSG   --name AllowRAGAPI   --priority 100   --protocol Tcp   --destination-port-ranges 8000   --access Allow
