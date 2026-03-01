
```mermaid
flowchart TD
classDef dark fill=#1e1e1e,stroke=#888,color=#eee;
classDef node fill=#2b2b2b,stroke=#999,color=#fff;
classDef accent fill=#004c99,stroke=#66aaff,color=#fff;

subgraph Clients["User Interfaces"]
    A1["SRE UI (Web/Teams)"]:::node
    A2["Engineering UI (VS Code/Portal)"]:::node
end:::dark

subgraph Access["Identity & Access"]
    B1["Entra ID AuthN/AuthZ"]:::accent
end:::dark

subgraph API["Agentic RAG API
(Azure Container Apps)"]
    C1["SRE Agent"]:::node
    C2["Engineering Agent"]:::node
    C3["RAG Service"]:::node
end:::dark

subgraph Data["Knowledge & Memory"]
    D1["Azure Blob Storage"]:::node
    D2["Azure AI Search"]:::node
    D3["Azure PostgreSQL"]:::node
    D4["Azure Redis Cache"]:::node
end:::dark

subgraph AI["AI Compute"]
    E1["Azure OpenAI
GPT‑4.1 / Embeddings"]:::accent
end:::dark

subgraph Security["Security"]
    F1["Key Vault"]:::node
    F2["User Assigned MI"]:::accent
end:::dark

A1 -->|SSO| B1
A2 -->|SSO| B1
A1 --> C1
A2 --> C2

C1 --> D2
C1 --> E1
C1 --> D3
C1 --> D4
C1 --> F1

C2 --> D2
C2 --> E1
C2 --> D3
C2 --> D4
C2 --> F1

C3 --> D2
C3 --> E1

D1 -->|ETL| C3

F2 --> C1
F2 --> C2
F2 --> C3
```
``















```mermaid

flowchart TD

subgraph Clients["User Interfaces"]
    A1["SRE UI (Web/Teams)"]
    A2["Engineering UI (Web/IDE/Teams)"]
end

subgraph ID["Identity & Access"]
    B1["Entra ID (Azure AD)"]
    B2["Azure API Management (optional)"]
end

subgraph CAE["Azure Container Apps Env"]
    subgraph API["Agentic RAG API (FastAPI + LangGraph)"]
        C1["/agent/sre"]
        C2["/agent/eng"]
        C3["/rag/ask"]
        C4["/healthz"]
    end

    subgraph Sandbox["Sandbox Executor"]
        S1["Python Sandbox
No outbound network"]
    end
end

subgraph Data["Data & Knowledge Stores"]
    D1["Azure Blob Storage
Raw docs, code snapshots"]
    D2["Azure AI Search
sre-knowledge-index
code-index"]
    D3["Azure Database for PostgreSQL
Chat history, agent state"]
    D4["Azure Cache for Redis
Semantic cache"]
end

subgraph AI["AI & Intelligence"]
    E1["Azure OpenAI
GPT-4.x deployments
Embeddings"]
end

subgraph Sec["Security & Secrets"]
    F1["Key Vault
Secrets & config"]
    F2["User-assigned Managed Identity
agentic-rag-dev-api-mi"]
end

subgraph Mon["Monitoring & Observability"]
    G1["Application Insights"]
    G2["Log Analytics Workspace"]
end

%% Connections
A1 -->|SSO| B1
A2 -->|SSO| B1

A1 -->|HTTPS| C1
A2 -->|HTTPS| C2

C1 -->|call tools| D2
C1 -->|LLM calls| E1
C1 -->|read/write| D3
C1 -->|cache| D4
C1 -->|get secrets| F1
C1 -->|logs/metrics| G1

C2 -->|call tools| D2
C2 -->|LLM calls| E1
C2 -->|read/write| D3
C2 -->|cache| D4
C2 -->|get secrets| F1
C2 -->|logs/metrics| G1

C3 -->|RAG search| D2
C3 -->|LLM calls| E1

S1 -->|exec code/Kusto| C1
S1 -->|logs| G1

D1 -->|"ETL / Ingestion Jobs"| C3
C3 -->|embeddings| E1
C3 -->|upsert| D2

F2 -->|assigned to| C1
F2 -->|assigned to| C3
F2 -->|authN| D1
F2 -->|authN| D2
F2 -->|authN| E1
F2 -->|authN| F1

G1 --> G2

```
``
