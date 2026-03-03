import asyncio
import logging
import traceback
from typing import Any

logger = logging.getLogger(__name__)

SANDBOX_TIMEOUT = 10  # seconds
ALLOWED_BUILTINS = {
    "print", "len", "range", "enumerate", "zip",
    "list", "dict", "set", "tuple", "str", "int",
    "float", "bool", "type", "isinstance", "min", "max", "sum",
}


async def execute_code(code: str) -> dict[str, Any]:
    """
    Execute untrusted Python code in a restricted sandbox.
    No file I/O, no imports, no network — pure computation only.
    """
    import builtins
    restricted_globals = {
        "__builtins__": {k: getattr(builtins, k) for k in ALLOWED_BUILTINS if hasattr(builtins, k)},
    }
    output_lines = []

    def _capture_print(*args, **kwargs):
        output_lines.append(" ".join(str(a) for a in args))

    restricted_globals["__builtins__"]["print"] = _capture_print

    try:
        loop = asyncio.get_event_loop()
        local_vars: dict = {}

        def _run():
            exec(compile(code, "<sandbox>", "exec"), restricted_globals, local_vars)

        await asyncio.wait_for(loop.run_in_executor(None, _run), timeout=SANDBOX_TIMEOUT)

        return {
            "status": "ok",
            "output": "\n".join(output_lines),
            "locals": {k: repr(v) for k, v in local_vars.items()},
        }
    except asyncio.TimeoutError:
        logger.warning("Sandbox execution timed out after %ds", SANDBOX_TIMEOUT)
        return {"status": "timeout", "output": f"Execution exceeded {SANDBOX_TIMEOUT}s limit"}
    except Exception as exc:
        logger.warning("Sandbox execution error: %s", exc)
        return {"status": "error", "output": traceback.format_exc(limit=5)}
