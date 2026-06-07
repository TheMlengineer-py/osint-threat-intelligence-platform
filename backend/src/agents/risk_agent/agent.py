"""Risk assessment agent implementation."""

import logging
from typing import Any

from src.agents.base_agent import AgentState, BaseAgent
from src.agents.risk_agent.tools import RiskAssessmentTools

logger = logging.getLogger(__name__)


class RiskAgent(BaseAgent):
    """Agent for assessing threat risk."""

    def __init__(self, llm: Any, name: str = "RiskAgent"):
        """Initialize risk agent."""
        super().__init__(llm, name)
        self.tools = RiskAssessmentTools()

    async def execute(self, state: AgentState) -> AgentState:
        """Execute risk assessment logic."""
        self._log_execution(
            "START", {"items_to_assess": len(state.data.get("classified_items", []))}
        )

        try:
            classified_items = state.data.get("classified_items", [])
            risk_assessed_items = []

            for item in classified_items:
                # Calculate risk components
                threat_type = item.get("threat_type", "unknown")
                severity = item.get("severity", "low")
                iocs = item.get("iocs", {})

                # Base severity score from classification
                severity_scores = {
                    "low": 2.5,
                    "medium": 5.0,
                    "high": 8.0,
                    "critical": 9.5,
                }
                severity_score = severity_scores.get(severity, 5.0)

                # Assess exploitation likelihood
                exploit_available = len(iocs) > 0
                likelihood = self.tools.assess_exploitation_likelihood(
                    exploit_available=exploit_available,
                    exploit_maturity="proof-of-concept",
                    in_the_wild=False,
                    active_campaigns=0,
                )

                # Assess impact
                impact = self.tools.assess_impact(
                    affected_count=1000, criticality="medium", data_accessible=False
                )

                # Calculate overall threat score
                threat_score = self.tools.calculate_threat_score(
                    severity_score, likelihood, impact
                )

                # Determine risk level
                risk_level = self.tools.determine_risk_level(threat_score)

                # Generate recommendation
                recommendation = self.tools.generate_recommendation(
                    threat_type, risk_level, []
                )

                # Add risk assessment to item
                risk_assessed_item = {
                    **item,
                    "threat_score": round(threat_score, 2),
                    "risk_level": risk_level,
                    "likelihood": round(likelihood, 2),
                    "impact": round(impact, 2),
                    "recommendation": recommendation,
                }

                risk_assessed_items.append(risk_assessed_item)

            state.data["risk_assessed_items"] = risk_assessed_items

            self._add_message(
                state, "agent", f"Assessed risk for {len(risk_assessed_items)} items"
            )
            self._log_execution(
                "COMPLETE", {"assessed_count": len(risk_assessed_items)}
            )

        except Exception as e:
            self._add_error(state, f"Risk assessment failed: {str(e)}")
            logger.exception("Risk agent exception")

        return state
