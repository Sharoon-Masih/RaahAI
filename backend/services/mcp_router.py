# backend/services/mcp_router.py
# ============================================================
# MCP Router — FastAPI acts as the tool execution gateway.
# Agents call these functions; this module routes to the right
# MCP integration (Firebase, Sheets, Maps, Gemini).
# NO agent bypasses this layer.
# ============================================================

from __future__ import annotations

import logging
from typing import Any, Optional

logger = logging.getLogger(__name__)


class MCPRouter:
    """
    Central routing hub for all MCP tool calls within the pipeline.
    Maps logical tool names → concrete implementations.

    Tool Registry:
      firebase   → backend/services/firebase_service.py
      gemini     → backend/services/gemini_service.py (future)
      sheets     → backend/services/sheets_service.py (future)
      maps       → backend/services/maps_service.py (future)
    """

    def __init__(self) -> None:
        self._registry: dict[str, Any] = {}

    def register(self, tool_name: str, handler: Any) -> None:
        """Register a tool handler by name."""
        self._registry[tool_name] = handler
        logger.info(f"[MCPRouter] Registered tool: {tool_name}")

    def get(self, tool_name: str) -> Any:
        """
        Retrieve a registered tool handler.
        Raises KeyError if tool not registered — forces explicit registration.
        """
        if tool_name not in self._registry:
            raise KeyError(
                f"[MCPRouter] Tool '{tool_name}' is not registered. "
                f"Available tools: {list(self._registry.keys())}"
            )
        return self._registry[tool_name]

    def available_tools(self) -> list[str]:
        return list(self._registry.keys())

    async def route(self, tool_name: str, action: str, payload: dict) -> Any:
        """
        Dynamically route a tool call.
        Args:
            tool_name: e.g. "firebase", "gemini", "sheets"
            action: e.g. "write_case", "generate_sms"
            payload: dict of kwargs for the handler action
        Returns:
            Result from handler
        """
        handler = self.get(tool_name)
        method = getattr(handler, action, None)
        if method is None:
            raise AttributeError(
                f"[MCPRouter] Tool '{tool_name}' has no action '{action}'."
            )
        logger.debug(f"[MCPRouter] Routing: {tool_name}.{action}({list(payload.keys())})")
        return await method(**payload)


# Module-level singleton — initialized at app startup
mcp_router = MCPRouter()
