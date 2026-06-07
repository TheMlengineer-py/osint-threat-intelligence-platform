"""
NewsAPI collector — async, mirrors style of cisa_collector.py.
Requires NEWS_API_KEY in .env (free tier: 100 req/day).
"""

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta

import aiohttp

from src.core.config.settings import settings

logger = logging.getLogger(__name__)
_QUERIES = [
    "cybersecurity threat",
    "ransomware attack",
    "data breach",
    "malware campaign",
]


@dataclass
class NewsItem:
    title: str
    description: str
    source: str
    source_url: str
    published_date: datetime | None


class NewsAPICollector:
    BASE_URL = "https://newsapi.org/v2/everything"

    def __init__(self):
        self.api_key = settings.news_api_key
        self.timeout = aiohttp.ClientTimeout(total=20)

    async def collect_threat_news(
        self,
        days: int = 7,
        limit: int = 50,
        queries: list[str] | None = None,
    ) -> list[NewsItem]:
        if not self.api_key:
            logger.warning("NEWS_API_KEY not set — skipping NewsAPI")
            return []
        items = []
        from_date = (datetime.utcnow() - timedelta(days=days)).strftime("%Y-%m-%d")
        terms = queries or _QUERIES
        per_q = max(1, limit // len(terms))

        async with aiohttp.ClientSession(timeout=self.timeout) as session:
            for query in terms:
                try:
                    params = {
                        "q": query,
                        "from": from_date,
                        "sortBy": "publishedAt",
                        "language": "en",
                        "pageSize": min(per_q, 20),
                        "apiKey": self.api_key,
                    }
                    async with session.get(self.BASE_URL, params=params) as resp:
                        if resp.status != 200:
                            logger.error(f"NewsAPI {resp.status} for '{query}'")
                            continue
                        for art in (await resp.json()).get("articles", []):
                            title = art.get("title") or ""
                            if not title or title == "[Removed]":
                                continue
                            try:
                                pub = datetime.fromisoformat(
                                    art.get("publishedAt", "").replace("Z", "+00:00")
                                )
                            except Exception:
                                pub = datetime.utcnow()
                            items.append(
                                NewsItem(
                                    title=title[:500],
                                    description=(art.get("description") or "")[:1000],
                                    source=art.get("source", {}).get("name", "NewsAPI"),
                                    source_url=art.get("url", ""),
                                    published_date=pub,
                                )
                            )
                except Exception as e:
                    logger.error(f"NewsAPI error for '{query}': {e}")

        logger.info(f"NewsAPI: collected {len(items)} articles")
        return items[:limit]
