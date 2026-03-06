# Agentic RAG Platform — Deployment Guide

> **Status:** MVP Deployed ✅ | **Environment:** `dev` | **Region:** South India
> **API Base URL:** `https://agentic-rag-dev-api.redpond-8970ff91.southindia.azurecontainerapps.io`
> **Last Updated:** 2026-03-06

---

## Table of Contents

1. [Overview](#1-overview)
2. [Deployed Architecture](#2-deployed-architecture)
3. [Azure Resource Inventory](#3-azure-resource-inventory)
4. [Flow Diagrams](#4-flow-diagrams)
5. [Use Cases](#5-use-cases)
6. [Why SRE & Engineering Teams Should Use This Agent](#6-why-sre--engineering-teams-should-use-this-agent)
7. [Troubleshooting Log — Issues Encountered & Solutions Applied](#7-troubleshooting-log--issues-encountered--solutions-applied)
8. [How to Enrich the Knowledge Base](#8-how-to-enrich-the-knowledge-base)
9. [API Reference](#9-api-reference)
10. [Post-MVP Roadmap](#10-post-mvp-roadmap)

---

## 1. Overview

The **Agentic RAG Platform** is a production-grade, AI-powered knowledge and operations assistant built on Azure managed services. It enables engineering and SRE teams to query internal documentation, runbooks, architecture decisions, and incident history using natural language — and receive grounded, cited answers in seconds.

### What It Is

- **RAG** (Retrieval-Augmented Generation): every answer is grounded in your actual internal documents stored in Azure Blob Storage and indexed in Azure AI Search. The LLM never hallucinates from general knowledge alone — it always retrieves relevant context first.
- **Agentic**: beyond simple Q&A, agents can call tools — query Postgres for incident history or service dependencies, execute diagnostic Python code in a sandbox, and maintain multi-turn conversation memory via Redis.
- **Two Specialised Agents**:
  - 🔴 **SRE Agent** — incident triage, RCA, runbook lookup, postmortem drafting, SLO queries
  - 🔵 **Engineering Agent** — architecture guidance, code review, service dependency mapping, debugging, best practices

### Technology Stack

| Layer | Technology |
| :--- | :--- |
| Compute | Azure Container Apps (FastAPI) |
| LLM & Embeddings | Azure OpenAI — GPT-4o + text-embedding-3-large (3072d) |
| Vector Search | Azure AI Search — hybrid (vector + BM25 keyword) |
| Memory | Azure Cache for Redis — conversation history (TTL 1h) |
| Structured Data | Azure PostgreSQL Flexible Server — incident history, service deps, audit log |
| Document Store | Azure Blob Storage — raw documents (raw-docs container) |
| Secrets | Azure Key Vault — API keys fetched at startup |
| Identity | User-Assigned Managed Identity — passwordless auth |
| IaC | Terraform (`terraform/` directory) |
| CI/CD | GitHub Actions (`.github/workflows/`) |
| Observability | Application Insights + Log Analytics Workspace |

---

## 2. Deployed Architecture

The system is built in **6 layers**:

| Layer | Components |
| :--- | :--- |
| **L1 — Presentation** | SRE UI, Engineering UI (web browser / Swagger / Teams) |
| **L2 — Identity & Access** | Microsoft Entra ID (Azure AD) — JWT token validation |
| **L3 — Agents & API** | FastAPI Container App — SRE Agent, Engineering Agent, RAG Service, Sandbox Executor |
| **L4 — Data & Memory** | Blob Storage, Azure AI Search, PostgreSQL, Redis Cache |
| **L5 — AI Compute** | Azure OpenAI — GPT-4o (chat) + text-embedding-3-large (embeddings) |
| **L6 — Security & Observability** | Key Vault, Managed Identity, Application Insights, Log Analytics |

### Architectural Strengths

- **Zero-secret architecture**: Managed Identity eliminates hardcoded credentials across all services
- **Stateful agents**: Redis maintains full multi-turn conversation context per session per agent
- **Hybrid search**: Azure AI Search combines vector similarity (semantic meaning) + BM25 keyword matching for superior retrieval
- **Graceful degradation**: all external services (Postgres, Redis) have null-guards — the API never crashes on startup if a dependency is temporarily unavailable
- **Full audit trail**: every agent interaction is logged to PostgreSQL and Application Insights

---

## 3. Azure Resource Inventory

| Resource Name | Azure Service | SKU | Role in Architecture |
| :--- | :--- | :--- | :--- |
| `agentic-rag-dev-api` | Azure Container App | - | FastAPI + Agentic logic (SRE & Engineering agents) |
| `agentic-rag-dev-cae` | Container Apps Environment | - | Isolated secure runtime boundary |
| `agentic-rag-dev-openai-q7g5ye` | Azure OpenAI | S0 | GPT-4o (chat) + text-embedding-3-large (3072d embeddings) |
| `agentic-rag-dev-search-q7g5ye` | Azure AI Search | Basic | Hybrid vector + BM25 keyword index (`rag-index`) |
| `agentic-rag-dev-pg-q7g5ye` | PostgreSQL Flexible Server | - | Incident history, service dependencies, session audit log |
| `agentic-rag-dev-redis-q7g5ye` | Azure Cache for Redis | - | Conversation memory per session (TTL 1 hour) |
| `agentic-rag-dev-api-mi` | User Assigned Managed Identity | - | Passwordless auth for all Azure service-to-service calls |
| `agenticragdevkvq7g5ye` | Azure Key Vault | - | OpenAI API key, Postgres password, Redis primary key |
| `agentic-rag-dev-appi` | Application Insights | - | Request tracing, performance monitoring, failure alerts |
| `agentic-rag-dev-law` | Log Analytics Workspace | - | Centralised log aggregation and querying |
| `agenticragdevq7g5ye` (ACR) | Azure Container Registry | Basic | Docker image storage for the FastAPI app |
| `agenticragdevq7g5ye` (storage) | Azure Blob Storage | LRS | Raw documents in `raw-docs` container |

---

## 4. Flow Diagrams

### 4.1 System Architecture Diagram

```mermaid
flowchart TD

subgraph Clients["User Interfaces"]
    A1["SRE UI (Web or Teams)"]
    A2["Engineering UI (Web or IDE)"]
end

subgraph Identity["Identity & Access"]
    B1["Entra ID (Azure AD)"]
end

subgraph API["Agentic RAG API (Container Apps)"]
    C1["SRE Agent"]
    C2["Engineering Agent"]
    C3["RAG Retrieval Service"]
    C4["Health Endpoint"]
end

subgraph Sandbox["Sandbox Executor"]
    S1["Python Sandbox (No network)"]
end

subgraph Data["Knowledge and Memory"]
    D1["Blob Storage (Docs)"]
    D2["Azure AI Search (Indexes)"]
    D3["PostgreSQL (Incidents / Deps)"]
    D4["Redis (Conversation Cache)"]
end

subgraph AI["AI Compute"]
    E1["Azure OpenAI (GPT-4o + Embeddings)"]
end

subgraph Security["Secrets and IAM"]
    F1["Key Vault"]
    F2["User Assigned Managed Identity"]
end

subgraph Observability["Monitoring"]
    G1["Application Insights"]
    G2["Log Analytics Workspace"]
end

A1 --> B1
A2 --> B1
B1 --> C1
B1 --> C2

C1 --> D2
C1 --> E1
C1 --> D3
C1 --> D4
C1 --> G1

C2 --> D2
C2 --> E1
C2 --> D3
C2 --> D4
C2 --> G1

C3 --> D2
C3 --> E1

S1 --> C1
S1 --> C2

D1 --> C3

F2 --> C1
F2 --> C2
F2 --> C3
F2 --> E1
F2 --> F1

G1 --> G2
