"""Classification agent implementation."""

import logging
from typing import Any

from src.agents.base_agent import AgentState, BaseAgent
from src.agents.classification_agent.tools import ClassificationTools

logger = logging.getLogger(__name__)


class ClassificationAgent(BaseAgent):
    """Agent for classifying threats and extracting entities."""

    def __init__(self, llm: Any, name: str = "ClassificationAgent"):
        """Initialize classification agent."""
        super().__init__(llm, name)
        self.tools = ClassificationTools()

    async def execute(self, state: AgentState) -> AgentState:
        """Execute classification logic."""
        self._log_execution(
            "START", {"items_to_classify": len(state.data.get("collected_items", []))}
        )

        try:
            collected_items = state.data.get("collected_items", [])
            classified_items = []

            for item in collected_items:
                content = item.get("content", "") or item.get("title", "")

                # Extract entities
                entities = self.tools.extract_entities(content)

                # Extract IOCs
                iocs = self.tools.extract_iocs(content)

                # Classify threat type
                threat_classification = self.tools.classify_threat_type(content)

                # Map MITRE techniques
                mitre_techniques = self.tools.map_mitre_techniques(content)

                # Assess severity
                severity = self.tools.assess_severity(
                    content, threat_classification["threat_type"]
                )

                classified_item = {
                    **item,
                    "threat_type": threat_classification["threat_type"],
                    "threat_confidence": threat_classification["confidence"],
                    "severity": severity,
                    "entities": entities,
                    "iocs": iocs,
                    "mitre_techniques": mitre_techniques,
                }

                classified_items.append(classified_item)

            state.data["classified_items"] = classified_items
            state.data["classification_count"] = len(classified_items)

            self._add_message(
                state, "agent", f"Classified {len(classified_items)} items"
            )
            self._log_execution("COMPLETE", {"classified_count": len(classified_items)})

        except Exception as e:
            self._add_error(state, f"Classification failed: {str(e)}")
            logger.exception("Classification agent exception")

        return state
