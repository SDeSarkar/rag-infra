from fastapi import APIRouter, Depends

from app.core.auth import get_current_user
from app.core.config import settings
from app.models.schemas import DocumentItem, DocumentsResponse
import app.core.clients as clients

router = APIRouter()


@router.get("", response_model=DocumentsResponse)
async def list_documents(
    container: str = "raw-docs",
    user: dict = Depends(get_current_user),
):
    container_client = clients.blob_service_client.get_container_client(container)
    items = []
    async for blob in container_client.list_blobs():
        items.append(DocumentItem(
            name=blob.name,
            size=blob.size,
            last_modified=str(blob.last_modified),
            uri=f"{settings.blob_uri.rsplit('/', 1)[0]}/{container}/{blob.name}",
        ))
    return DocumentsResponse(container=container, documents=items)
