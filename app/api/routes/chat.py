from fastapi import APIRouter, Depends

from app.core.auth import get_current_user
from app.models.schemas import AgentType, ChatRequest, ChatResponse
from app.agents.sre_agent import run_sre_agent
from app.agents.engineering_agent import run_engineering_agent

router = APIRouter()


@router.post("", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    user: dict = Depends(get_current_user),
):
    if request.agent == AgentType.sre:
        result = await run_sre_agent(request.session_id, request.message)
    else:
        result = await run_engineering_agent(request.session_id, request.message)

    return ChatResponse(
        session_id=request.session_id,
        agent=request.agent,
        answer=result["answer"],
        sources=result.get("sources", []),
        tool_calls=result.get("tool_calls", []),
    )
