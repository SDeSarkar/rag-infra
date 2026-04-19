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

app = FastAPI(title="Agentic RAG – phi3:mini")

CHROMA_DIR = "/opt/agentic-rag/chroma"

docs = [
    Document(
        page_content="SRE RUNBOOK: For 500 errors, check DB connection, restart Redis then DB.",
        metadata={"source": "sre_manual.md"},
    ),
    Document(
        page_content="ENGINEERING DESIGN: Auth service uses microservices, JWT and gRPC.",
        metadata={"source": "engineering_design.md"},
    ),
    Document(
        page_content="SLO POLICY: Checkout requires 99.9% availability, P95 < 200ms.",
        metadata={"source": "slos.md"},
    ),
]

embeddings = HuggingFaceEmbeddings(
    model_name="sentence-transformers/all-MiniLM-L6-v2"
)

if os.path.exists(CHROMA_DIR) and os.listdir(CHROMA_DIR):
    vector_db = Chroma(
        persist_directory=CHROMA_DIR,
        embedding_function=embeddings,
    )
else:
    vector_db = Chroma.from_documents(
        docs,
        embeddings,
        persist_directory=CHROMA_DIR,
    )
    vector_db.persist()

llm = OllamaLLM(
    model="phi3:mini",
    base_url="http://10.0.1.4:11434",
    temperature=0.3,
)

class Query(BaseModel):
    agent_type: str
    question: str

@app.post("/ask")
def ask(q: Query):
    results = vector_db.similarity_search(q.question, k=1)

    if results:
        context = results[0].page_content
    else:
        context = "No internal documentation found."

    if q.agent_type == "sre":
        persona = "You are an expert Site Reliability Engineer."
    else:
        persona = "You are a Lead Software Engineer."

    prompt = f"""
ROLE: {persona}
INTERNAL DOCS: {context}
QUESTION: {q.question}

Answer concisely.
"""

    return {"answer": llm.invoke(prompt)}
