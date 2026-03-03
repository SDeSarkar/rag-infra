from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Azure Identity
    azure_client_id: str

    # Azure AI Search
    azure_search_endpoint: str
    azure_search_index_name: str = "agentic-rag-index"

    # Azure OpenAI
    azure_openai_endpoint: str
    azure_openai_deployment: str = "gpt-4o"
    azure_openai_embedding_deployment: str = "text-embedding-ada-002"
    azure_openai_api_version: str = "2024-05-01-preview"

    # Blob Storage
    blob_uri: str

    # Key Vault
    keyvault_uri: str
    kv_secret_pg_password: str = "Postgres-AdminPassword"
    kv_secret_redis_key: str = "Redis-PrimaryKey"

    # PostgreSQL
    postgres_host: str
    postgres_db: str
    postgres_user: str

    # Redis
    redis_host: str
    redis_ssl_port: int = 6380

    # App Insights (optional)
    applicationinsights_connection_string: str = ""

    # Entra ID
    entra_tenant_id: str = ""
    entra_audience: str = "api://agentic-rag"


settings = Settings()
