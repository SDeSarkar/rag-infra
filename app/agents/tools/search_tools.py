import logging
from typing import Any

from azure.search.documents.models import VectorizedQuery

import app.core.clients as clients
from app.core.config import settings

logger = logging.getLogger(__name__)


async def hybrid_search(query: str, query_vector: list[float], top_k: int = 5) -> list[dict]:
    """Perform hybrid (keyword + vector) search on AI Search index."""
    vector_query = VectorizedQuery(
        vector=query_vector,
        k_nearest_neighbors=top_k,
        fields="content_vector",
    )
    results = await clients.search_client.search(
        search_text=query,
        vector_queries=[vector_query],
        select=["id", "content", "source", "title"],
        top=top_k,
    )
    docs = []
    async for result in results:
        docs.append({
            "id": result.get("id"),
            "content": result.get("content", ""),
            "source": result.get("source", ""),
            "title": result.get("title", ""),
            "score": result.get("@search.score", 0.0),
        })
    logger.info("hybrid_search returned %d results for query='%s'", len(docs), query)
    return docs


async def get_embedding(text: str) -> list[float]:
    """Embed text using Azure OpenAI embeddings (AAD auth)."""
    response = await clients.openai_client.embeddings.create(
        input=text,
        model=settings.azure_openai_embedding_deployment,
    )
    return response.data[0].embedding
