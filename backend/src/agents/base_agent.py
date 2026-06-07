"""
Base agent class for all agentic AI workflows.
No external LLM framework dependency — works with any callable LLM.
"""

import json
import logging
from abc import ABC, abstractmethod
from datetime import datetime
from typing import Any

from pydantic import BaseModel

logger = logging.getLogger(__name__)


class AgentState(BaseModel):
    """State object passed between agent nodes."""

    data: dict[str, Any] = {}
    messages: list[dict[str, str]] = []
    errors: list[str] = []
    metadata: dict[str, Any] = {}
    timestamp: datetime = datetime.now()

    class Config:
        arbitrary_types_allowed = True


class BaseAgent(ABC):
    """Base class for all agents."""

    def __init__(self, llm: Any = None, name: str = "BaseAgent"):
        self.llm = llm
        self.name = name
        self.logger = logging.getLogger(f"agents.{name}")

    @abstractmethod
    async def execute(self, state: AgentState) -> AgentState:
        """Execute agent logic."""
        pass

    def _log_execution(self, step: str, details: dict[str, Any]) -> None:
        self.logger.info(f"{self.name} - {step}: {json.dumps(details, default=str)}")

    def _add_message(self, state: AgentState, role: str, content: str) -> None:
        state.messages.append(
            {
                "role": role,
                "content": content,
                "timestamp": datetime.now().isoformat(),
            }
        )

    def _add_error(self, state: AgentState, error: str) -> None:
        state.errors.append(error)
        self.logger.error(f"{self.name} - Error: {error}")
