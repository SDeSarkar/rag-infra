import json
import logging
from typing import Optional

import app.core.clients as clients

logger = logging.getLogger(__name__)
HISTORY_TTL = 3600  # 1 hour


async def get_conversation_history(session_id: str) -> list[dict]:
    raw = await clients.redis_client.get(f"session:{session_id}:history")
    if not raw:
        return []
    return json.loads(raw)


async def append_to_history(session_id: str, role: str, content: str):
    history = await get_conversation_history(session_id)
    history.append({"role": role, "content": content})
    # Keep last 20 turns
    history = history[-20:]
    await clients.redis_client.setex(
        f"session:{session_id}:history",
        HISTORY_TTL,
        json.dumps(history),
    )


async def cache_set(key: str, value: str, ttl: int = 300):
    await clients.redis_client.setex(key, ttl, value)


async def cache_get(key: str) -> Optional[str]:
    return await clients.redis_client.get(key)
