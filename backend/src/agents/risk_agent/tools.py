"""Tools for risk assessment."""

import logging
from typing import Any

logger = logging.getLogger(__name__)


class RiskAssessmentTools:
    """Tools for threat risk assessment."""

    # CVSS score ranges
    CVSS_TO_SEVERITY = {
        (0, 3.9): "low",
        (4, 6.9): "medium",
        (7, 8.9): "high",
        (9, 10): "critical",
    }

    @staticmethod
    def calculate_cvss_risk(cvss_score: float) -> dict[str, Any]:
        """Calculate risk from CVSS score."""
        severity = "unknown"
        for (min_score, max_score), sev in RiskAssessmentTools.CVSS_TO_SEVERITY.items():
            if min_score <= cvss_score <= max_score:
                severity = sev
                break

        return {
            "cvss_score": cvss_score,
            "severity": severity,
            "base_risk_score": cvss_score,
        }

    @staticmethod
    def assess_exploitation_likelihood(
        exploit_available: bool,
        exploit_maturity: str,
        in_the_wild: bool,
        active_campaigns: int = 0,
    ) -> float:
        """Assess likelihood of exploitation (0-1)."""
        likelihood = 0.0

        # Base likelihood from exploit availability
        if in_the_wild:
            likelihood += 0.4
        elif exploit_available:
            likelihood += 0.2

        # Maturity bonus
        if exploit_maturity == "functional":
            likelihood += 0.3
        elif exploit_maturity == "proof-of-concept":
            likelihood += 0.2

        # Active campaigns bonus
        likelihood += min(active_campaigns * 0.1, 0.3)

        return min(likelihood, 1.0)

    @staticmethod
    def assess_impact(
        affected_count: int, criticality: str = "medium", data_accessible: bool = False
    ) -> float:
        """Assess potential impact (0-1)."""
        impact = 0.0

        # Base impact from affected system count
        if affected_count > 1000000:
            impact = 0.9
        elif affected_count > 100000:
            impact = 0.7
        elif affected_count > 1000:
            impact = 0.5
        elif affected_count > 0:
            impact = 0.3

        # Criticality factor
        if criticality == "critical":
            impact = min(impact * 1.2, 1.0)
        elif criticality == "high":
            impact = min(impact * 1.1, 1.0)

        # Data access factor
        if data_accessible:
            impact = min(impact + 0.2, 1.0)

        return impact

    @staticmethod
    def calculate_threat_score(
        severity: float,
        likelihood: float,
        impact: float,
        threat_actor_capability: float = 0.5,
    ) -> float:
        """Calculate overall threat score (0-10)."""
        # Weight the factors
        base_score = (severity * 0.4) + (likelihood * 0.3) + (impact * 0.3)

        # Factor in threat actor capability
        final_score = base_score * (0.5 + threat_actor_capability)

        return min(final_score * 10, 10.0)

    @staticmethod
    def determine_risk_level(score: float) -> str:
        """Determine risk level from score."""
        if score >= 9:
            return "critical"
        elif score >= 7:
            return "high"
        elif score >= 4:
            return "medium"
        else:
            return "low"

    @staticmethod
    def generate_recommendation(
        threat_type: str, risk_level: str, factors: list
    ) -> str:
        """Generate mitigation recommendation."""
        recommendations = {
            "critical": [
                "IMMEDIATE ACTION REQUIRED",
                "Deploy emergency patch or workaround",
                "Increase monitoring and logging",
                "Brief executive stakeholders",
                "Prepare incident response team",
            ],
            "high": [
                "Plan urgent patching/mitigation",
                "Enable advanced monitoring",
                "Assess exposure in environment",
                "Notify system owners",
                "Develop mitigation strategy",
            ],
            "medium": [
                "Schedule patching within 30 days",
                "Enable baseline monitoring",
                "Document exposure",
                "Track for exploitation evidence",
                "Standard remediation process",
            ],
            "low": [
                "Standard patching schedule",
                "Monitor for exploitation",
                "Note in vulnerability tracking",
                "Routine remediation",
            ],
        }

        recs = recommendations.get(risk_level, [])
        return " | ".join(recs)
