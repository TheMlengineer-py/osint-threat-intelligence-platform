"""Reporting agent implementation."""

import logging
from datetime import datetime
from typing import Any
from uuid import uuid4

from src.agents.base_agent import AgentState, BaseAgent
from src.agents.reporting_agent.tools import ReportGenerationTools

logger = logging.getLogger(__name__)


class ReportingAgent(BaseAgent):
    """Agent for generating intelligence reports."""

    def __init__(self, llm: Any, name: str = "ReportingAgent"):
        """Initialize reporting agent."""
        super().__init__(llm, name)
        self.tools = ReportGenerationTools()

    async def execute(self, state: AgentState) -> AgentState:
        """Execute report generation logic."""
        self._log_execution(
            "START", {"items_to_report": len(state.data.get("risk_assessed_items", []))}
        )

        try:
            risk_assessed_items = state.data.get("risk_assessed_items", [])

            if not risk_assessed_items:
                self._add_message(state, "agent", "No items to report on")
                return state

            # Calculate report metadata
            critical_count = len(
                [t for t in risk_assessed_items if t.get("risk_level") == "critical"]
            )
            high_count = len(
                [t for t in risk_assessed_items if t.get("risk_level") == "high"]
            )
            medium_count = len(
                [t for t in risk_assessed_items if t.get("risk_level") == "medium"]
            )

            # Extract key actors
            key_actors = set()
            for item in risk_assessed_items:
                entities = item.get("entities", [])
                for entity in entities:
                    if entity.get("type") in ["ORG", "threat_actor"]:
                        key_actors.add(entity.get("value"))

            # Generate sections
            executive_summary = self.tools.generate_executive_summary(
                total_threats=len(risk_assessed_items),
                critical_count=critical_count,
                high_count=high_count,
                key_actors=list(key_actors)[:5],
                main_findings=self._extract_main_findings(risk_assessed_items),
            )

            findings = self.tools.generate_findings_section(risk_assessed_items)
            ioc_section = self.tools.generate_ioc_section(risk_assessed_items)
            recommendations = self.tools.generate_recommendations_section(
                risk_assessed_items
            )

            # Format complete report
            report_id = str(uuid4())
            metadata = {
                "report_id": report_id,
                "total_threats": len(risk_assessed_items),
                "critical_count": critical_count,
                "high_count": high_count,
                "medium_count": medium_count,
                "period": "Recent",
                "generated_at": datetime.now().isoformat(),
            }

            formatted_report = self.tools.format_report(
                title="OSINT Threat Intelligence Report",
                executive_summary=executive_summary,
                findings=findings,
                ioc_section=ioc_section,
                recommendations=recommendations,
                metadata=metadata,
            )

            # Store report in state
            state.data["generated_report"] = formatted_report
            state.data["report_metadata"] = metadata
            state.data["report_id"] = report_id

            self._add_message(
                state, "agent", f"Generated intelligence report (ID: {report_id})"
            )
            self._log_execution(
                "COMPLETE",
                {
                    "report_id": report_id,
                    "threats_included": len(risk_assessed_items),
                    "critical_count": critical_count,
                },
            )

        except Exception as e:
            self._add_error(state, f"Report generation failed: {str(e)}")
            logger.exception("Reporting agent exception")

        return state

    @staticmethod
    def _extract_main_findings(threats: list) -> list:
        """Extract main findings from threats."""
        findings = []

        # Count by type
        threat_types = {}
        for threat in threats:
            ttype = threat.get("threat_type", "unknown")
            threat_types[ttype] = threat_types.get(ttype, 0) + 1

        for ttype, count in threat_types.items():
            findings.append(f"{count} {ttype} threat(s) detected")

        return findings[:5]
