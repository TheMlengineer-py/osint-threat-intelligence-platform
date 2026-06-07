"""
RSS Feed Collector for threat intelligence feeds
"""

import asyncio
import logging
from dataclasses import dataclass
from datetime import datetime

import feedparser

logger = logging.getLogger(__name__)


@dataclass
class RSSItem:
    """Represents an RSS feed item"""

    title: str
    description: str
    source: str
    published_date: str
    source_url: str
    feed_name: str

    def to_dict(self) -> dict:
        return {
            "title": self.title,
            "description": self.description,
            "source": self.source,
            "published_date": self.published_date,
            "source_url": self.source_url,
            "threat_type": "NEWS",
            "status": "NEW",
            "severity": "MEDIUM",
        }


class RSSCollector:
    """Collect threat intelligence from RSS feeds"""

    THREAT_FEEDS = {
        "CISA_Alerts": "https://www.cisa.gov/feed/alerts.xml",
        "Bleeping_Computer": "https://www.bleepingcomputer.com/feed/",
        "Dark_Reading": "https://www.darkreading.com/feed",
        "SecurityWeek": "https://www.securityweek.com/feed/",
    }

    def __init__(self):
        self.timeout = 30

    async def collect_from_all_feeds(self, limit: int = 50) -> list[RSSItem]:
        """Collect from all configured feeds"""
        all_items = []

        for feed_name, feed_url in self.THREAT_FEEDS.items():
            try:
                logger.info(f"Collecting from {feed_name}...")
                items = await self._collect_from_feed(feed_url, feed_name, limit)
                all_items.extend(items)
                await asyncio.sleep(0.5)
            except Exception as e:
                logger.error(f"Error collecting from {feed_name}: {e}")

        logger.info(f"Collected {len(all_items)} items from all feeds")
        return all_items

    async def _collect_from_feed(
        self, feed_url: str, feed_name: str, limit: int
    ) -> list[RSSItem]:
        """Collect items from a single RSS feed"""
        items = []

        try:
            loop = asyncio.get_event_loop()
            feed = await loop.run_in_executor(None, feedparser.parse, feed_url)

            if not feed.entries:
                logger.warning(f"No entries found in {feed_name}")
                return items

            for entry in feed.entries[:limit]:
                try:
                    item = RSSItem(
                        title=entry.get("title", "No title"),
                        description=entry.get("summary", ""),
                        source=feed_name,
                        published_date=entry.get(
                            "published", datetime.now().isoformat()
                        ),
                        source_url=entry.get("link", ""),
                        feed_name=feed_name,
                    )
                    items.append(item)
                except Exception as e:
                    logger.error(f"Error parsing entry from {feed_name}: {e}")
                    continue

            logger.debug(f"Collected {len(items)} items from {feed_name}")

        except Exception as e:
            logger.error(f"Error parsing feed {feed_name}: {e}")

        return items


if __name__ == "__main__":

    async def main():
        collector = RSSCollector()
        items = await collector.collect_from_all_feeds(limit=20)
        print(f"Collected {len(items)} items")
        for item in items[:5]:
            print(f"  [{item.source}] {item.title[:60]}")

    asyncio.run(main())
