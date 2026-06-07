"""Supervisor agent implementation."""

import logging
from typing import Any

from src.agents.base_agent import AgentState, BaseAgent

logger = logging.getLogger(__name__)


class SupervisorAgent(BaseAgent):
    """Supervisor agent for orchestrating other agents."""

    def __init__(self, llm: Any, name: str = "SupervisorAgent"):
        """Initialize supervisor agent."""
        super().__init__(llm, name)
        self.subordinate_agents = {}

    def register_agent(self, agent_name: str, agent: Any) -> None:
        """Register a subordinate agent."""
        self.subordinate_agents[agent_name] = agent
        self.logger.info(f"Registered agent: {agent_name}")

    async def execute(self, state: AgentState) -> AgentState:
        """Execute supervisor logic."""
        self._log_execution("START", {"request": state.data.get("request")})

        try:
            # Route task
            routing_decision = await self._route_task(state)
            state.data["routing"] = routing_decision

            # Execute based on routing
            if routing_decision["action"] == "route":
                state = await self._delegate_to_agent(
                    state, routing_decision["target_agent"], routing_decision["task"]
                )
            elif routing_decision["action"] == "escalate":
                self._add_error(
                    state, f"Task escalated: {routing_decision['reasoning']}"
                )

            self._log_execution("COMPLETE", routing_decision)

        except Exception as e:
            self._add_error(state, f"Supervisor execution failed: {str(e)}")
            logger.exception("Supervisor agent exception")

        return state

    async def _route_task(self, state: AgentState) -> dict[str, Any]:
        """Route task to appropriate agent."""
        request = state.data.get("request", "")

        # Simple routing logic
        if "collect" in request.lower() or "gather" in request.lower():
            return {
                "action": "route",
                "target_agent": "collection_agent",
                "task": request,
                "priority": "high",
                "reasoning": "Task requires data collection",
            }
        elif "classify" in request.lower() or "analyze" in request.lower():
            return {
                "action": "route",
                "target_agent": "classification_agent",
                "task": request,
                "priority": "high",
                "reasoning": "Task requires threat classification",
            }
        elif "risk" in request.lower() or "assess" in request.lower():
            return {
                "action": "route",
                "target_agent": "risk_agent",
                "task": request,
                "priority": "high",
                "reasoning": "Task requires risk assessment",
            }
        elif "report" in request.lower() or "generate" in request.lower():
            return {
                "action": "route",
                "target_agent": "reporting_agent",
                "task": request,
                "priority": "high",
                "reasoning": "Task requires report generation",
            }
        else:
            return {
                "action": "escalate",
                "target_agent": None,
                "task": request,
                "priority": "medium",
                "reasoning": "Unable to route - unclear request",
            }

    async def _delegate_to_agent(
        self, state: AgentState, agent_name: str, task: str
    ) -> AgentState:
        """Delegate task to subordinate agent."""
        if agent_name not in self.subordinate_agents:
            self._add_error(state, f"Agent not registered: {agent_name}")
            return state

        agent = self.subordinate_agents[agent_name]

        # Create subtask state
        subtask_state = AgentState(
            data={"task": task, **state.data},
            messages=state.messages,
            metadata=state.metadata,
        )

        # Execute agent
        result_state = await agent.execute(subtask_state)

        # Merge results
        state.data.update(result_state.data)
        state.messages.extend(result_state.messages)
        state.errors.extend(result_state.errors)

        return state
