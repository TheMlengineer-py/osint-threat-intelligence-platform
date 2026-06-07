"""Collection agent implementation."""

import logging
from typing import Any

from src.agents.base_agent import AgentState, BaseAgent
from src.agents.collection_agent.tools import OSINTCollectionTools

logger = logging.getLogger(__name__)


class CollectionAgent(BaseAgent):
    """Agent for collecting OSINT data."""

    def __init__(self, llm: Any, name: str = "CollectionAgent"):
        """Initialize collection agent."""
        super().__init__(llm, name)
        self.tools = OSINTCollectionTools()

    async def execute(self, state: AgentState) -> AgentState:
        """Execute collection logic."""
        self._log_execution("START", {"task": state.data.get("task")})

        try:
            await self.tools.init_session()

            # Determine collection scope
            task = state.data.get("task", "")
            keywords = state.data.get(
                "keywords", ["threat", "malware", "vulnerability"]
            )

            # Collect from multiple sources
            collected_data = []

            # News
            news = await self.tools.fetch_news(keywords)
            collected_data.extend(news)
            self._add_message(state, "agent", f"Collected {len(news)} news items")

            # CISA advisories
            advisories = await self.tools.fetch_cisa_advisories()
            collected_data.extend(advisories)
            self._add_message(
                state, "agent", f"Collected {len(advisories)} CISA advisories"
            )

            # CVE data
            cves = await self.tools.fetch_cve_data(keywords)
            collected_data.extend(cves)
            self._add_message(state, "agent", f"Collected {len(cves)} CVE records")

            # Threat feeds
            feeds = await self.tools.fetch_threat_feeds()
            collected_data.extend(feeds)
            self._add_message(
                state, "agent", f"Collected {len(feeds)} threat feed items"
            )

            # Normalize data
            normalized = await self.tools.normalize_data(collected_data)
            state.data["collected_items"] = normalized
            state.data["collection_count"] = len(normalized)

            self._log_execution(
                "COMPLETE",
                {
                    "items_collected": len(normalized),
                    "sources": list(set(item["source"] for item in normalized)),
                },
            )

        except Exception as e:
            self._add_error(state, f"Collection failed: {str(e)}")
            logger.exception("Collection agent exception")
        finally:
            await self.tools.close_session()

        return state
