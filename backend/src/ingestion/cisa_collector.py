"""
CISA Cybersecurity Advisories Collector
Fetches latest CVE vulnerabilities from CISA/NVD
"""

import asyncio
import logging
from dataclasses import dataclass

import aiohttp

logger = logging.getLogger(__name__)


@dataclass
class CISAThreat:
    """Represents a CISA vulnerability"""

    cve_id: str
    title: str
    description: str
    severity: str
    cvss_score: float | None
    published_date: str
    source_url: str
    affected_products: list[str]

    def to_dict(self) -> dict:
        return {
            "external_id": self.cve_id,
            "title": self.title,
            "description": self.description,
            "severity": self.severity,
            "confidence_score": self.cvss_score or 0.0,
            "published_date": self.published_date,
            "source": "CISA",
            "source_url": self.source_url,
            "threat_type": "VULNERABILITY",
            "status": "NEW",
        }


class CISACollector:
    """Collect CVE data from CISA/NVD API"""

    BASE_URL = "https://services.nvd.nist.gov/rest/json/cves/2.0"

    def __init__(self, timeout: int = 30):
        self.timeout = aiohttp.ClientTimeout(total=timeout)

    async def collect_latest_threats(self, limit: int = 50) -> list[CISAThreat]:
        """Fetch latest CVE vulnerabilities"""
        threats = []

        try:
            async with aiohttp.ClientSession(timeout=self.timeout) as session:
                url = f"{self.BASE_URL}?resultsPerPage={limit}"

                async with session.get(url) as response:
                    if response.status == 200:
                        data = await response.json()

                        for vuln in data.get("vulnerabilities", []):
                            threat = self._parse_vulnerability(vuln)
                            if threat:
                                threats.append(threat)

                        logger.info(f"Collected {len(threats)} threats from CISA")
                    else:
                        logger.error(f"CISA API returned status {response.status}")

        except Exception as e:
            logger.error(f"Error fetching CISA data: {e}")

        return threats

    def _parse_vulnerability(self, vuln: dict) -> CISAThreat | None:
        """Parse a single CVE vulnerability"""
        try:
            vuln_data = vuln.get("cve", {})
            cve_id = vuln_data.get("id", "").strip()

            if not cve_id:
                return None

            metrics = vuln_data.get("metrics", {})
            cvss_v3 = metrics.get("cvssMetricV31", [{}])[0]
            severity = cvss_v3.get("cvssData", {}).get("baseSeverity", "UNKNOWN")
            cvss_score = cvss_v3.get("cvssData", {}).get("baseScore")

            descriptions = vuln_data.get("descriptions", [])
            description = (
                descriptions[0].get("value", "") if descriptions else "No description"
            )

            threat = CISAThreat(
                cve_id=cve_id,
                title=cve_id,
                description=description[:500],
                severity=severity,
                cvss_score=cvss_score,
                published_date=vuln_data.get("published", ""),
                source_url=f"https://nvd.nist.gov/vuln/detail/{cve_id}",
                affected_products=[],
            )

            return threat

        except Exception as e:
            logger.error(f"Error parsing vulnerability: {e}")
            return None


if __name__ == "__main__":

    async def main():
        collector = CISACollector()
        threats = await collector.collect_latest_threats(limit=10)
        print(f"Collected {len(threats)} threats")
        for threat in threats[:3]:
            print(f"  {threat.cve_id}: {threat.severity}")

    asyncio.run(main())
