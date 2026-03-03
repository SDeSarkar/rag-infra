import logging
from typing import Any

import app.core.clients as clients

logger = logging.getLogger(__name__)


async def query_incident_history(service_name: str, limit: int = 10) -> list[dict]:
    """Query recent incidents for a given service from PostgreSQL."""
    async with clients.pg_pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT id, service, severity, title, started_at, resolved_at, summary
            FROM incidents
            WHERE service = $1
            ORDER BY started_at DESC
            LIMIT $2
            """,
            service_name,
            limit,
        )
    return [dict(r) for r in rows]


async def query_service_dependencies(service_name: str) -> list[dict]:
    """Query service dependency graph from PostgreSQL."""
    async with clients.pg_pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT upstream, downstream, dependency_type
            FROM service_dependencies
            WHERE upstream = $1 OR downstream = $1
            """,
            service_name,
        )
    return [dict(r) for r in rows]


async def log_agent_interaction(session_id: str, agent: str, query: str, answer: str):
    """Persist agent interaction to PostgreSQL for audit."""
    async with clients.pg_pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO agent_interactions (session_id, agent, query, answer, created_at)
            VALUES ($1, $2, $3, $4, NOW())
            """,
            session_id, agent, query, answer,
        )
