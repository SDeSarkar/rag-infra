import logging
from typing import Any

from azure.search.documents.indexes.models import (
    SearchIndex, SearchField, SearchFieldDataType,
    SimpleField, SearchableField, VectorSearch,
    HnswAlgorithmConfiguration, VectorSearchProfile,
    SemanticConfiguration, SemanticSearch, SemanticPrioritizedFields,
    SemanticField,
)

import app.core.clients as clients
from app.agents.tools.search_tool import hybrid_search, get_embedding
from app.core.config import settings

logger = logging.getLogger(__name__)
CONTEXT_MAX_CHARS = 6000


async def ensure_index_exists():
    """Create AI Search index if it doesn't already exist."""
    index_name = settings.azure_search_index_name
    try:
        await clients.search_index_client.get_index(index_name)
        logger.info("Search index '%s' already exists.", index_name)
        return
    except Exception:
        pass

    fields = [
        SimpleField(name="id", type=SearchFieldDataType.String, key=True),
        SearchableField(name="content", type=SearchFieldDataType.String),
        SearchableField(name="title", type=SearchFieldDataType.String, filterable=True),
        SimpleField(name="source", type=SearchFieldDataType.String, filterable=True),
        SearchField(
            name="content_vector",
            type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
            searchable=True,
            vector_search_dimensions=3072,
            vector_search_profile_name="hnsw-profile",
        ),
    ]

    vector_search = VectorSearch(
        algorithms=[HnswAlgorithmConfiguration(name="hnsw-algo")],
        profiles=[VectorSearchProfile(name="hnsw-profile", algorithm_configuration_name="hnsw-algo")],
    )

    semantic_config = SemanticConfiguration(
        name="semantic-config",
        prioritized_fields=SemanticPrioritizedFields(
            content_fields=[SemanticField(field_name="content")],
            title_field=SemanticField(field_name="title"),
        ),
    )

    index = SearchIndex(
        name=index_name,
        fields=fields,
        vector_search=vector_search,
        semantic_search=SemanticSearch(configurations=[semantic_config]),
    )

    await clients.search_index_client.create_index(index)
    logger.info("Created search index '%s'.", index_name)


async def retrieve_context(query: str, top_k: int = 5) -> tuple[str, list[str]]:
    """Retrieve relevant chunks and build context string."""
    query_vector = await get_embedding(query)
    docs = await hybrid_search(query, query_vector, top_k=top_k)

    context_parts = []
    sources = []
    total_chars = 0

    for doc in docs:
        chunk = f"[{doc['title']}]\n{doc['content']}"
        if total_chars + len(chunk) > CONTEXT_MAX_CHARS:
            break
        context_parts.append(chunk)
        sources.append(doc["source"])
        total_chars += len(chunk)

    context = "\n\n---\n\n".join(context_parts)
    return context, list(set(sources))
