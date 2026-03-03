from enum import Enum
from typing import Any, Optional
from pydantic import BaseModel, Field


class AgentType(str, Enum):
    sre = "sre"
    engineering = "engineering"


class ChatRequest(BaseModel):
    agent: AgentType = AgentType.sre
    session_id: str = Field(..., description="Unique session/conversation ID")
    message: str = Field(..., min_length=1, max_length=4096)


class ChatResponse(BaseModel):
    session_id: str
    agent: AgentType
    answer: str
    sources: list[str] = []
    tool_calls: list[str] = []


class IngestRequest(BaseModel):
    container: str = "raw-docs"
    blob_prefix: str = ""
    force_reindex: bool = False


class IngestResponse(BaseModel):
    status: str
    documents_indexed: int
    errors: list[str] = []


class DocumentItem(BaseModel):
    name: str
    size: int
    last_modified: str
    uri: str


class DocumentsResponse(BaseModel):
    container: str
    documents: list[DocumentItem]


class ServiceStatus(str, Enum):
    ok = "ok"
    degraded = "degraded"
    error = "error"


class HealthResponse(BaseModel):
    status: ServiceStatus
    services: dict[str, Any]
