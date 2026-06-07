"""Tools for report generation."""

import logging
from datetime import datetime
from typing import Any

logger = logging.getLogger(__name__)


class ReportGenerationTools:
    """Tools for generating intelligence reports."""

    @staticmethod
    def generate_executive_summary(
        total_threats: int,
        critical_count: int,
        high_count: int,
        key_actors: list[str],
        main_findings: list[str],
    ) -> str:
        """Generate executive summary."""
        summary = f"""
EXECUTIVE SUMMARY

During the analysis period, {total_threats} distinct threats were identified and analyzed.
Of these, {critical_count} were classified as CRITICAL severity and {high_count} as HIGH severity,
requiring immediate attention and remediation.

Key threat actors identified include: {', '.join(key_actors) if key_actors else 'Unknown'}.

Primary findings indicate: {'; '.join(main_findings[:3]) if main_findings else 'General threat activity'}.

Immediate action is recommended for all CRITICAL and HIGH severity threats as detailed in this report.
        """
        return summary.strip()

    @staticmethod
    def generate_findings_section(threats: list[dict[str, Any]]) -> str:
        """Generate findings section."""
        findings = "KEY FINDINGS\n\n"

        # Group by severity
        critical = [t for t in threats if t.get("risk_level") == "critical"]
        high = [t for t in threats if t.get("risk_level") == "high"]
        medium = [t for t in threats if t.get("risk_level") == "medium"]

        if critical:
            findings += f"• {len(critical)} CRITICAL severity threat(s) identified\n"
        if high:
            findings += f"• {len(high)} HIGH severity threat(s) identified\n"
        if medium:
            findings += f"• {len(medium)} MEDIUM severity threat(s) identified\n"

        # Top threats
        findings += "\nTop Threats:\n"
        sorted_threats = sorted(
            threats, key=lambda x: x.get("threat_score", 0), reverse=True
        )
        for threat in sorted_threats[:5]:
            findings += f"  - {threat.get('title', 'Unknown')}: Score {threat.get('threat_score', 0)}\n"

        return findings

    @staticmethod
    def generate_ioc_section(threats: list[dict[str, Any]]) -> str:
        """Generate IOC section."""
        ioc_section = "INDICATORS OF COMPROMISE (IOCs)\n\n"

        all_iocs = {
            "ipv4": set(),
            "domains": set(),
            "urls": set(),
            "file_hashes": set(),
            "emails": set(),
        }

        for threat in threats:
            iocs = threat.get("iocs", {})
            all_iocs["ipv4"].update(iocs.get("ipv4", []))
            all_iocs["domains"].update(iocs.get("domains", []))
            all_iocs["urls"].update(iocs.get("urls", []))
            all_iocs["emails"].update(iocs.get("emails", []))

            # Collect hashes
            for hash_type in ["md5", "sha1", "sha256"]:
                all_iocs["file_hashes"].update(iocs.get(hash_type, []))

        if all_iocs["ipv4"]:
            ioc_section += f"IP Addresses: {', '.join(list(all_iocs['ipv4'])[:10])}\n\n"
        if all_iocs["domains"]:
            ioc_section += f"Domains: {', '.join(list(all_iocs['domains'])[:10])}\n\n"
        if all_iocs["urls"]:
            ioc_section += f"URLs: {', '.join(list(all_iocs['urls'])[:5])}\n\n"
        if all_iocs["file_hashes"]:
            ioc_section += (
                f"File Hashes: {', '.join(list(all_iocs['file_hashes'])[:5])}\n\n"
            )

        return ioc_section

    @staticmethod
    def generate_recommendations_section(threats: list[dict[str, Any]]) -> str:
        """Generate recommendations section."""
        recommendations = "RECOMMENDATIONS\n\n"

        # Critical actions
        critical = [t for t in threats if t.get("risk_level") == "critical"]
        if critical:
            recommendations += "IMMEDIATE ACTIONS (Critical Threats):\n"
            for threat in critical:
                recommendations += (
                    f"  • {threat.get('recommendation', 'See details above')}\n"
                )
            recommendations += "\n"

        # General recommendations
        recommendations += "GENERAL RECOMMENDATIONS:\n"
        recommendations += (
            "  • Deploy IOCs to all security tools (IDS/IPS, firewalls, EDR)\n"
        )
        recommendations += (
            "  • Increase threat intelligence sharing with relevant parties\n"
        )
        recommendations += "  • Review and update incident response procedures\n"
        recommendations += (
            "  • Conduct security awareness training on identified threats\n"
        )
        recommendations += (
            "  • Monitor for exploitation attempts and suspicious activity\n"
        )
        recommendations += "  • Coordinate with external stakeholders as needed\n"

        return recommendations

    @staticmethod
    def format_report(
        title: str,
        executive_summary: str,
        findings: str,
        ioc_section: str,
        recommendations: str,
        metadata: dict[str, Any],
    ) -> str:
        """Format complete report."""
        report = f"""
{'=' * 80}
INTELLIGENCE REPORT
{'=' * 80}

Title: {title}
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
Report ID: {metadata.get('report_id', 'N/A')}

{'-' * 80}
{executive_summary}
{'-' * 80}

{findings}

{'-' * 80}
{ioc_section}
{'-' * 80}

{recommendations}

{'-' * 80}
REPORT METADATA

Total Threats Analyzed: {metadata.get('total_threats', 0)}
Critical Threats: {metadata.get('critical_count', 0)}
Report Period: {metadata.get('period', 'N/A')}
Analyst: Automated Intelligence Platform
{'=' * 80}
        """
        return report.strip()
