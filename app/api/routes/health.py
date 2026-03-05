import logging

from fastapi import APIRouter

from app.models.schemas import HealthResponse, ServiceStatus
import app.core.clients as clients

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("", response_model=HealthResponse)
async def health():
    services = {}
    overall = ServiceStatus.ok

    # Redis
    try:
        await clients.redis_client.ping()
        services["redis"] = "ok"
    except Exception as exc:
        services["redis"] = str(exc)
        overall = ServiceStatus.degraded

    # PostgreSQL
    try:
        async with clients.pg_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        services["postgres"] = "ok"
    except Exception as exc:
        services["postgres"] = str(exc)
        overall = ServiceStatus.degraded

    # AI Search — check service reachability only, not index existence
    try:
        from app.core.config import settings
        from azure.core.exceptions import ResourceNotFoundError

        try:
            await clients.search_index_client.get_index(settings.azure_search_index_name)
            services["ai_search"] = "ok"
        except ResourceNotFoundError:
            # Index doesn't exist yet — service is reachable, index created on first upload
            services["ai_search"] = "ok (index not yet created — upload a document to initialise)"
            logger.info(
                "AI Search reachable but index '%s' not yet created — this is expected before first upload",
                settings.azure_search_index_name,
            )
    except Exception as exc:
        services["ai_search"] = str(exc)
        overall = ServiceStatus.degraded

    # Blob Storage
    try:
        container_client = clients.blob_service_client.get_container_client("raw-docs")
        await container_client.get_container_properties()
        services["blob_storage"] = "ok"
    except Exception as exc:
        services["blob_storage"] = str(exc)
        overall = ServiceStatus.degraded

    return HealthResponse(status=overall, services=services)
