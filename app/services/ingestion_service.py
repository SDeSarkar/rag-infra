import hashlib
import logging
from io import BytesIO

import app.core.clients as clients
from app.agents.tools.search_tool import get_embedding
from app.core.config import settings
from app.services.rag_service import ensure_index_exists

logger = logging.getLogger(__name__)
CHUNK_SIZE = 1000
CHUNK_OVERLAP = 100


def _chunk_text(text: str) -> list[str]:
    chunks = []
    start = 0
    while start < len(text):
        end = min(start + CHUNK_SIZE, len(text))
        chunks.append(text[start:end])
        start += CHUNK_SIZE - CHUNK_OVERLAP
    return chunks


async def ingest_blobs(container: str = "raw-docs", prefix: str = "", force: bool = False) -> dict:
    await ensure_index_exists()

    container_url = settings.blob_uri.rsplit("/", 1)[0]
    container_client = clients.blob_service_client.get_container_client(container)

    indexed = 0
    errors = []

    async for blob in container_client.list_blobs(name_starts_with=prefix):
        blob_name = blob.name
        if not blob_name.endswith((".txt", ".md", ".pdf")):
            continue
        try:
            blob_client = container_client.get_blob_client(blob_name)
            stream = await blob_client.download_blob()
            data = await stream.readall()
            text = data.decode("utf-8", errors="ignore")

            chunks = _chunk_text(text)
            documents = []

            for i, chunk in enumerate(chunks):
                doc_id = hashlib.md5(f"{blob_name}:{i}".encode()).hexdigest()
                vector = await get_embedding(chunk)
                documents.append({
                    "id": doc_id,
                    "content": chunk,
                    "title": blob_name,
                    "source": f"{container_url}/{container}/{blob_name}",
                    "content_vector": vector,
                })

            await clients.search_client.upload_documents(documents=documents)
            indexed += len(chunks)
            logger.info("Indexed %d chunks from blob '%s'", len(chunks), blob_name)

        except Exception as exc:
            logger.error("Failed to ingest blob '%s': %s", blob_name, exc)
            errors.append(f"{blob_name}: {exc}")

    return {"documents_indexed": indexed, "errors": errors}
