import logging
from typing import Any

from app.core.config import settings
from app.services.rag_service import retrieve_context
from app.agents.tools.postgres_tool import query_service_dependencies, log_agent_interaction
from app.agents.tools.redis_tool import get_conversation_history, append_to_history
from app.agents.tools.sandbox_tool import execute_code
import app.core.clients as clients

logger = logging.getLogger(__name__)

ENGINEERING_SYSTEM_PROMPT = """
You are an expert Software Engineering AI assistant embedded in an engineering platform.
Your responsibilities:
- Answer architecture, design, and code-related questions.
- Review code snippets and suggest improvements.
- Explain service dependencies and integration patterns.
- Help with debugging, performance analysis, and best practices.
- Execute safe code snippets in a sandboxed environment.

Always:
- Ground answers in retrieved internal documentation.
- Cite sources (ADRs, RFCs, wiki pages) when relevant.
- Be precise and use concrete examples.
- Prefer idiomatic, production-ready code suggestions.
- Never output secrets, credentials, or connection strings.
"""


async def run_engineering_agent(session_id: str, user_message: str) -> dict[str, Any]:
    logger.info("Engineering agent: session=%s query='%s'", session_id, user_message[:80])

    # 1) Conversation history
    history = await get_conversation_history(session_id)

    # 2) RAG context from AI Search
    context, sources = await retrieve_context(user_message, top_k=5)

    # 3) Service dependency lookup
    dependencies = []
    tool_calls = []
    try:
        words = user_message.lower().split()
        for word in words:
            if len(word) > 4:
                rows = await query_service_dependencies(word)
                if rows:
                    dependencies = rows
                    tool_calls.append(f"query_service_dependencies(service={word})")
                    break
    except Exception as exc:
        logger.warning("Postgres dependency lookup failed: %s", exc)

    # 4) Code execution (if code block detected)
    sandbox_result = None
    if "```python" in user_message:
        start = user_message.find("```python") + 9
        end = user_message.find("```", start)
        if end > start:
            code_block = user_message[start:end].strip()
            sandbox_result = await execute_code(code_block)
            tool_calls.append("execute_code(sandbox)")

    # 5) Build messages
    messages = [{"role": "system", "content": ENGINEERING_SYSTEM_PROMPT}]

    if context:
        messages.append({
            "role": "system",
            "content": f"Relevant internal documentation:\n\n{context}"
        })

    if dependencies:
        dep_text = "\n".join(
            f"- {r['upstream']} → {r['downstream']} ({r['dependency_type']})"
            for r in dependencies
        )
        messages.append({
            "role": "system",
            "content": f"Service dependencies:\n{dep_text}"
        })

    if sandbox_result:
        messages.append({
            "role": "system",
            "content": f"Sandbox execution result:\nStatus: {sandbox_result['status']}\nOutput:\n{sandbox_result['output']}"
        })

    messages.extend(history[-10:])
    messages.append({"role": "user", "content": user_message})

    # 6) Azure OpenAI call
    response = await clients.openai_client.chat.completions.create(
        model=settings.azure_openai_deployment,
        messages=messages,
        temperature=0.3,
        max_tokens=2000,
    )

    answer = response.choices[0].message.content

    # 7) Persist
    await append_to_history(session_id, "user", user_message)
    await append_to_history(session_id, "assistant", answer)

    try:
        await log_agent_interaction(session_id, "engineering", user_message, answer)
    except Exception as exc:
        logger.warning("Failed to log engineering interaction to Postgres: %s", exc)

    return {
        "answer": answer,
        "sources": sources,
        "tool_calls": tool_calls,
    }
