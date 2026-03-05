import logging
import asyncio

from azure.identity.aio import ManagedIdentityCredential
from azure.keyvault.secrets.aio import SecretClient
from azure.search.documents.aio import SearchClient
from azure.search.documents.indexes.aio import SearchIndexClient
from azure.storage.blob.aio import BlobServiceClient
from azure.identity import (
    ManagedIdentityCredential as SyncMI,
    get_bearer_token_provider,
)
from openai import AsyncAzureOpenAI
import redis.asyncio as aioredis
import asyncpg

from app.core.config import settings

logger = logging.getLogger(__name__)

credential: ManagedIdentityCredential = None
kv_client: SecretClient = None
search_client: SearchClient = None
search_index_client: SearchIndexClient = None
blob_service_client: BlobServiceClient = None
openai_client: AsyncAzureOpenAI = None
redis_client: aioredis.Redis = None
pg_pool: asyncpg.Pool = None


async def _safe(coro, name: str, timeout: int = 15):
    """Run coroutine with timeout — log warning on failure, NEVER crash startup."""
    try:
        return await asyncio.wait_for(coro, timeout=timeout)
    except asyncio.TimeoutError:
        logger.warning("STARTUP TIMEOUT: %s timed out after %ds — continuing", name, timeout)
    except Exception as exc:
        logger.warning("STARTUP ERROR: %s failed — %s: %s — continuing", name, type(exc).__name__, exc)
    return None


async def init_clients():
    global credential, kv_client, search_client, search_index_client
    global blob_service_client, openai_client, redis_client, pg_pool

    logger.info("Initialising ManagedIdentityCredential client_id=%s", settings.azure_client_id)
    credential = ManagedIdentityCredential(client_id=settings.azure_client_id)

    # ── Key Vault ─────────────────────────────────────────────────────────────
    kv_client = SecretClient(vault_url=settings.keyvault_uri, credential=credential)

    pg_password = None
    redis_key = None

    result = await _safe(
        kv_client.get_secret(settings.kv_secret_pg_password),
        "KV:pg_password", timeout=15
    )
    if result:
        pg_password = result.value
        logger.info("STARTUP: KV pg_password fetched OK")
    else:
        logger.warning(
            "STARTUP: KV pg_password fetch FAILED — vault=%s secret=%s",
            settings.keyvault_uri,
            settings.kv_secret_pg_password,
        )

    result = await _safe(
        kv_client.get_secret(settings.kv_secret_redis_key),
        "KV:redis_key", timeout=15
    )
    if result:
        redis_key = result.value
        logger.info(
            "STARTUP: KV redis_key fetched OK (length=%d)",
            len(redis_key),
        )
    else:
        logger.warning(
            "STARTUP: KV redis_key fetch FAILED — vault=%s secret=%s",
            settings.keyvault_uri,
            settings.kv_secret_redis_key,
        )

    # ── Azure AI Search (lazy — no connection at startup) ─────────────────────
    search_client = SearchClient(
        endpoint=settings.azure_search_endpoint,
        index_name=settings.azure_search_index_name,
        credential=credential,
    )
    search_index_client = SearchIndexClient(
        endpoint=settings.azure_search_endpoint,
        credential=credential,
    )
    logger.info("STARTUP: Search clients initialised OK")

    # ── Blob Storage (lazy — no connection at startup) ────────────────────────
    account_url = settings.blob_uri.rsplit("/", 1)[0]
    blob_service_client = BlobServiceClient(
        account_url=account_url,
        credential=credential,
    )
    logger.info("STARTUP: Blob client initialised OK")

    # ── Azure OpenAI (lazy — no connection at startup) ────────────────────────
    sync_credential = SyncMI(client_id=settings.azure_client_id)
    token_provider = get_bearer_token_provider(
        sync_credential,
        "https://cognitiveservices.azure.com/.default"
    )
    openai_client = AsyncAzureOpenAI(
        azure_endpoint=settings.azure_openai_endpoint,
        azure_ad_token_provider=token_provider,
        api_version=settings.azure_openai_api_version,
    )
    logger.info("STARTUP: OpenAI client initialised OK")

    # ── PostgreSQL (with timeout — won't crash startup) ───────────────────────
    if pg_password:
        pool = await _safe(
            asyncpg.create_pool(
                host=settings.postgres_host,
                database=settings.postgres_db,
                user=settings.postgres_user,
                password=pg_password,
                ssl="require",
                min_size=1,
                max_size=5,
                command_timeout=10,
            ),
            "PostgreSQL:create_pool", timeout=20
        )
        if pool:
            pg_pool = pool
            logger.info("STARTUP: PostgreSQL pool created OK")
        else:
            logger.warning("STARTUP: PostgreSQL pool FAILED — fix firewall rules")
    else:
        logger.warning("STARTUP: No PG password — skipping PostgreSQL")

    # ── Redis (with timeout — won't crash startup) ────────────────────────────
    if redis_key:
        logger.info(
            "STARTUP: Redis key fetched OK (length=%d), attempting connection to %s:%s",
            len(redis_key),
            settings.redis_host,
            settings.redis_ssl_port,
        )
        try:
            r = aioredis.from_url(
                f"rediss://{settings.redis_host}:{settings.redis_ssl_port}",
                password=redis_key,
                decode_responses=True,
                socket_connect_timeout=10,
                socket_timeout=10,
            )
            await asyncio.wait_for(r.ping(), timeout=10)
            redis_client = r
            logger.info("STARTUP: Redis connected OK")
        except asyncio.TimeoutError:
            logger.warning(
                "STARTUP: Redis FAILED — TimeoutError — host=%s port=%s unreachable, check firewall",
                settings.redis_host,
                settings.redis_ssl_port,
            )
        except Exception as exc:
            logger.warning(
                "STARTUP: Redis FAILED — %s: %s — fix firewall/config",
                type(exc).__name__,
                exc,
            )
    else:
        logger.warning(
            "STARTUP: No Redis key — skipping Redis (KV secret name: %s)",
            settings.kv_secret_redis_key,
        )

    # ── Always reaches here ───────────────────────────────────────────────────
    logger.info("STARTUP COMPLETE — app is ready to accept requests")


async def close_clients():
    if credential:
        await credential.close()
    if kv_client:
        await kv_client.close()
    if search_client:
        await search_client.close()
    if search_index_client:
        await search_index_client.close()
    if blob_service_client:
        await blob_service_client.close()
    if redis_client:
        await redis_client.aclose()
    if pg_pool:
        await pg_pool.close()
