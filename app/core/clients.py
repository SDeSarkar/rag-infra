import logging
import os

from azure.identity.aio import ManagedIdentityCredential
from azure.keyvault.secrets.aio import SecretClient
from azure.search.documents.aio import SearchClient
from azure.search.documents.indexes.aio import SearchIndexClient
from azure.storage.blob.aio import BlobServiceClient
from openai import AsyncAzureOpenAI
from azure.identity import get_bearer_token_provider, ManagedIdentityCredential as SyncMI

import redis.asyncio as aioredis
import asyncpg

from app.core.config import settings

logger = logging.getLogger(__name__)

# ── Singletons ────────────────────────────────────────────────────────────────
credential: ManagedIdentityCredential = None
kv_client: SecretClient = None
search_client: SearchClient = None
search_index_client: SearchIndexClient = None
blob_service_client: BlobServiceClient = None
openai_client: AsyncAzureOpenAI = None
redis_client: aioredis.Redis = None
pg_pool: asyncpg.Pool = None


async def init_clients():
    global credential, kv_client, search_client, search_index_client
    global blob_service_client, openai_client, redis_client, pg_pool

    logger.info("Initialising ManagedIdentityCredential (client_id=%s)", settings.azure_client_id)
    credential = ManagedIdentityCredential(client_id=settings.azure_client_id)

    # Key Vault
    kv_client = SecretClient(vault_url=settings.keyvault_uri, credential=credential)
    pg_password = (await kv_client.get_secret(settings.kv_secret_pg_password)).value
    redis_key   = (await kv_client.get_secret(settings.kv_secret_redis_key)).value

    # Azure AI Search (AAD)
    search_client = SearchClient(
        endpoint=settings.azure_search_endpoint,
        index_name=settings.azure_search_index_name,
        credential=credential,
    )
    search_index_client = SearchIndexClient(
        endpoint=settings.azure_search_endpoint,
        credential=credential,
    )

    # Blob Storage (AAD)
    account_url = settings.blob_uri.rsplit("/", 1)[0]
    blob_service_client = BlobServiceClient(account_url=account_url, credential=credential)

    # Azure OpenAI (AAD)
    sync_credential = SyncMI(client_id=settings.azure_client_id)
    token_provider = get_bearer_token_provider(
        sync_credential, "https://cognitiveservices.azure.com/.default"
    )
    openai_client = AsyncAzureOpenAI(
        azure_endpoint=settings.azure_openai_endpoint,
        azure_ad_token_provider=token_provider,
        api_version=settings.azure_openai_api_version,
    )

    # Redis
    redis_client = await aioredis.from_url(
        f"rediss://{settings.redis_host}:{settings.redis_ssl_port}",
        password=redis_key,
        decode_responses=True,
    )

    # PostgreSQL
    pg_pool = await asyncpg.create_pool(
        host=settings.postgres_host,
        database=settings.postgres_db,
        user=settings.postgres_user,
        password=pg_password,
        ssl="require",
        min_size=2,
        max_size=10,
    )

    logger.info("All Azure clients initialised successfully.")


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
