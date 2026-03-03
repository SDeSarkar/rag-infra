from fastapi import APIRouter, Depends

from app.core.auth import require_role
from app.models.schemas import IngestRequest, IngestResponse
from app.services.ingestion_service import ingest_blobs

router = APIRouter()


@router.post("", response_model=IngestResponse)
async def ingest(
    request: IngestRequest,
    user: dict = Depends(require_role("sre", "engineer")),
):
    result = await ingest_blobs(
        container=request.container,
        prefix=request.blob_prefix,
        force=request.force_reindex,
    )
    return IngestResponse(
        status="completed" if not result["errors"] else "partial",
        documents_indexed=result["documents_indexed"],
        errors=result["errors"],
    )
