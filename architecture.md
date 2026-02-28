# Architecture Specification: Comparison AWS/OSS Vs Azure Cloud
**Focus:** Enterprise RAG (Retrieval-Augmented Generation) with Multi-Agent Orchestration

---

## 1. High-Level Mapping
This architecture transitions from a Kubernetes-heavy, self-hosted stack to a **Managed PaaS** model on Azure, reducing operational overhead  while maintaining strict private networking.

| Function | Original Stack (Image) | Azure Native Stack |
| :--- | :--- | :--- |
| **Compute / Orchestration** | Kubernetes (EKS) / Helm | **Azure Kubernetes Service (AKS)** or **Container Apps** |
| **LLM Serving** | Ray Serve / vLLM | **Azure OpenAI Service** (GPT-4o/O1) |
| **Vector Storage** | Qdrant | **Azure AI Search** (Vector Store) |
| **Graph Database** | Neo4j | **Azure Cosmos DB** (Apache Gremlin API) |
| **Data Ingestion** | Custom Chunking Scripts | **Azure AI Search Indexers** (Integrated Vectorization) |
| **API Gateway** | Custom API Gateway | **Azure API Management (APIM)** |
| **Monitoring** | Prometheus & Grafana | **Azure Monitor & Application Insights** |

---

## 2. Azure Architecture Diagram (Conceptual)



---

## 3. Layered Technical Breakdown

### A. Data Ingestion & Storage Layer
Instead of managing separate "Document Loaders" and "Graph Extraction" pods:
* **Storage:** Raw documents reside in **Azure Blob Storage (ADLS Gen2)**.
* **Ingestion:** Use **Azure AI Search Indexers**. These automatically handle document cracking (PDF/Docx), chunking, and calling embedding models in one managed pipeline.
* **Database:** **Azure SQL** or **Cosmos DB** handles the RDBMS requirements for structured metadata.

### B. The "Multi-Sub Agent" Brain
* **Orchestrator:** Use the **Semantic Kernel** or **LangChain** frameworks.
* **Hosting:** Deploy the "Planner" and "Agents" as microservices on **Azure Container Apps (ACA)**. This allows for serverless scaling without the complexity of managing a full K8s control plane, though **AKS** remains an option if you require deep cluster-level control.
* **Model Serving:** Replace vLLM with **Azure OpenAI**. This provides a private, high-availability endpoint for GPT models without managing GPU drivers.

### C. API Services & Security
* **Gateway:** **Azure API Management (APIM)** acts as the front door. It includes built-in policies for **LLM Token Rate Limiting** and **Circuit Breakers** to prevent model overload.
* **Auth:** **Microsoft Entra ID** (formerly Azure AD) provides OAuth2/OIDC.
* **Private Link:** All services communicate via **Azure Private Endpoints**, ensuring traffic never leaves the Azure backbone, matching the "Private Network" requirement in your original design.

### D. Monitoring & Evaluation
* **Tracing:** **Application Insights** provides end-to-end distributed tracing (similar to Jaeger/Zipkin).
* **AI Evaluation:** Use **Azure AI Studio** to run "Groundness" and "Relevance" tests on your RAG outputs, replacing manual model evaluation scripts.

---

## 4. Infrastructure as Code (IaC)
Since you currently use **Terraform**, the migration path involves:
1. **Provider:** Switch from `aws` to `azurerm`.
2. **Resource Modules:**
    * `azurerm_cognitive_account` (for OpenAI)
    * `azurerm_search_service` (for AI Search)
    * `azurerm_api_management` (for the Gateway)
    * `azurerm_kubernetes_cluster` (if staying with K8s)

---

## 5. Summary of Benefits
* **Reduced Complexity:** No need to manage Ray clusters or Qdrant updates.
* **Security:** Native integration with Entra ID and Private Link across all components.
* **Scale:** Azure OpenAI handles the GPU scaling for you, allowing you to focus on the "Planner" logic.

