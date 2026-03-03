import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.clients import init_clients, close_clients
from app.api.routes import chat, ingest, documents, health

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting up — initialising Azure clients...")
    await init_clients()
    yield
    logger.info("Shutting down — closing clients...")
    await close_clients()


app = FastAPI(
    title="Agentic RAG API",
    description="SRE + Engineering Agents backed by Azure AI Search and Azure OpenAI",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, prefix="/health", tags=["Health"])
app.include_router(chat.router, prefix="/chat", tags=["Chat"])
app.include_router(ingest.router, prefix="/ingest", tags=["Ingest"])
app.include_router(documents.router, prefix="/documents", tags=["Documents"])
