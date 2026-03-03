import logging
from typing import Any

from app.core.config import settings
from app.services.rag_service import retrieve_context
from app.agents.tools.postgres_tool import query_incident_history, log_agent_interaction
from app.agents.tools.redis_tool import get_conversation_history, append_to_history
from app.agents.tools.sandbox_tool import execute_code
import app.core.clients as clients

logger = logging.getLogger(__name__)

SRE_SYSTEM_PROMPT = """
You are an expert SRE (Site Reliability Engineer) AI assistant.
Your responsibilities:
- Analyze incidents and alerts based on historical data and runbooks.
- Suggest root cause analysis (RCA) and remediation steps.
- Help with on-call triage, runbook lookup, and postmortem drafting.
- Answer questions about service dependencies and SLOs/SLIs.
- Execute diagnostic code snippets safely when needed.

Always:
- Ground your answers in retrieved context from the knowledge base.
- Cite sources when referencing runbooks or past incidents.
- Be concise, structured (use numbered steps for procedures).
- Never reveal secrets, connection strings, or internal credentials.
"""


async def run_sre_agent(session_id: str, user_message: str) -> dict[str, Any]:
    logger.info("SRE agent: session=%s query='%s'", session_id, user_message[:80])

    # 1) Retrieve conversation history from Redis
    history = await get_conversation_history(session_id)

    # 2) Retrieve relevant context from AI Search
    context, sources = await retrieve_context(user_message, top_k=5)

    # 3) Retrieve recent incidents from Postgres (if service name mentioned)
    incidents = []
    tool_calls = []
    try:
        words = user_message.lower().split()
        for word in words:
            if len(word) > 4:
                rows = await query_incident_history(word, limit=3)
                if rows:
                    incidents = rows
                    tool_calls.append(f"query_incident_history(service={word})")
                    break
    except Exception as exc:
        logger.warning("Postgres incident lookup failed: %s", exc)

    # 4) Build messages
    messages = [{"role": "system", "content": SRE_SYSTEM_PROMPT}]

    if context:
        messages.append({
            "role": "system",
            "content": f"Relevant knowledge base context:\n\n{context}"
        })

    if incidents:
        incident_text = "\n".join(
            f"- [{r['severity']}] {r['title']} at {r['started_at']}: {r.get('summary', '')}"
            for r in incidents
        )
        messages.append({
            "role": "system",
            "content": f"Recent incidents:\n{incident_text}"
        })

    # Add conversation history
    messages.extend(history[-10:])
    messages.append({"role": "user", "content": user_message})

    # 5) Call Azure OpenAI (AAD auth via Managed Identity)
    response = await clients.openai_client.chat.completions.create(
        model=settings.azure_openai_deployment,
        messages=messages,
        temperature=0.2,
        max_tokens=1500,
    )

    answer = response.choices[0].message.content

    # 6) Persist to Redis + Postgres
    await append_to_history(session_id, "user", user_message)
    await append_to_history(session_id, "assistant", answer)

    try:
        await log_agent_interaction(session_id, "sre", user_message, answer)
    except Exception as exc:
        logger.warning("Failed to log SRE interaction to Postgres: %s", exc)

    return {
        "answer": answer,
        "sources": sources,
        "tool_calls": tool_calls,
    }
