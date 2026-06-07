"""Prompts for reporting agent."""

REPORT_GENERATION_PROMPT = """Generate an intelligence report based on:

Threats: {threats}
Key Findings: {findings}
Risk Summary: {risk_summary}

Structure:
1. Executive Summary (2-3 paragraphs)
2. Threat Overview (numbers, types, severity)
3. Key Findings (main discoveries)
4. Threat Actors (if identified)
5. Affected Systems/Organizations
6. Indicators of Compromise
7. Recommendations
8. References

Keep technical but accessible. Use clear formatting.
"""

EXECUTIVE_SUMMARY_PROMPT = """Create an executive summary for:

Total Threats: {total}
Critical Threats: {critical_count}
High Risk Threats: {high_count}
Key Actors: {actors}
Recommendations: {recommendations}

Summary should be 2-3 paragraphs, high-level, for decision makers.
"""
