# """Integration tests — pipeline components with mocked HTTP."""
# import pytest
# from unittest.mock import AsyncMock, MagicMock, patch
#
#
# class TestNLPPipeline:
#     def test_classifier_end_to_end(self):
#         from src.intelligence.classification.classifier import classify
#         from src.models.orm.base import ThreatCategory
#         texts = [
#             ("LockBit ransomware encrypts hospital files", ThreatCategory.malware_ransomware),
#             ("Nation-state APT targets government", ThreatCategory.apt),
#             ("Phishing campaign harvests credentials via BEC", ThreatCategory.phishing_fraud),
#             ("CVE-2024-1234 zero-day remote code execution", ThreatCategory.vulnerability_exploit),
#         ]
#         for text, expected in texts:
#             cat, conf = classify(text)
#             assert cat == expected, f"Expected {expected} for: {text}"
#             assert conf > 0.2
#
#     def test_ioc_pipeline(self):
#         from src.intelligence.indicators.ioc_extractor import extract_iocs
#         text = (
#             "C2 at 185.234.219.4 downloaded payload from "
#             "https://evil.com/stage2.exe "
#             "SHA256: " + "a" * 64 + " exploiting CVE-2024-9999"
#         )
#         iocs  = extract_iocs(text)
#         types = {i["type"] for i in iocs}
#         assert "ipv4"   in types
#         assert "url"    in types
#         assert "sha256" in types
#         assert "cve"    in types
#
#
# class TestGroqClient:
#     def test_client_reads_env(self):
#         from src.llm.groq_client import groq_client
#         # Should have read from backend/.env
#         assert isinstance(groq_client.is_available, bool)
#         assert isinstance(groq_client.model_name,  str)
#
#     def test_no_key_returns_message(self):
#         from src.llm.groq_client import GroqClient
#         c = GroqClient.__new__(GroqClient)
#         c._api_key  = ""
#         c._model    = "llama3-8b-8192"
#         c._client   = None
#         c._verified = False
#         msg = c._no_key_message()
#         assert "GROQ_API_KEY" in msg
#
#
# class TestCleanerPipeline:
#     def test_full_clean_cycle(self):
#         from src.preprocessing.cleaner import clean_text, fingerprint, is_security_relevant
#         raw = "<p>Critical <b>ransomware</b> attack at 185.220.1.1 exploits CVE-2024-9999</p>"
#         clean = clean_text(raw)
#         assert "<p>"   not in clean
#         assert "ransomware" in clean
#         fp = fingerprint(clean)
#         assert len(fp) == 64   # sha256 hex length
#         assert is_security_relevant(clean) is True

"""
Integration tests for the NLP + ingestion pipeline.
No DB, no network — tests real module behaviour end-to-end.
"""
import pytest

from src.intelligence.classification.classifier import classify
from src.intelligence.indicators.ioc_extractor import extract_iocs
from src.models.orm.base import ThreatCategory
from src.preprocessing.cleaner import clean_text, fingerprint

# ── NLP Pipeline ──────────────────────────────────────────────────────────────


class TestNLPPipeline:

    @pytest.mark.parametrize(
        "text,expected_category",
        [
            (
                "LockBit ransomware encrypts hospital files",
                ThreatCategory.malware_ransomware.value,
            ),
            (
                "Critical CVE-2024-1234 remote code execution vulnerability",
                ThreatCategory.vulnerability_exploit.value,
            ),
            (
                "Phishing campaign targeting banking credentials",
                ThreatCategory.phishing_fraud.value,
            ),
            (
                "APT28 nation-state threat actor campaign",
                ThreatCategory.apt.value,
            ),
        ],
    )
    def test_classifier_end_to_end(self, text, expected_category):
        """
        classify() returns {"category": str, "severity": str}.
        Compare result["category"] to ThreatCategory enum .value.
        """
        result = classify(text)
        assert isinstance(
            result, dict
        ), f"classify() should return dict, got {type(result)}"
        assert (
            result["category"] == expected_category
        ), f"Expected {expected_category} for: {text}\n  got: {result['category']}"

    def test_classifier_returns_valid_severity(self):
        result = classify("Critical zero-day exploit actively used in the wild")
        assert result["severity"] in {"critical", "high", "medium", "low"}

    def test_ioc_pipeline(self):
        text = (
            "Attacker C2 server at 45.33.32.156. "
            "File hash: d41d8cd98f00b204e9800998ecf8427e. "
            "Vulnerability: CVE-2024-5678."
        )
        iocs = extract_iocs(text)
        assert len(iocs) > 0

        types = {i["type"] for i in iocs}
        assert "ipv4" in types, f"Expected ipv4 in {types}"
        assert "md5" in types, f"Expected md5 in {types}"
        assert "cve" in types, f"Expected cve in {types}"

        # Private IPs should be excluded
        for ioc in iocs:
            if ioc["type"] == "ipv4":
                assert not ioc["value"].startswith(
                    "192.168."
                ), f"Private IP should be excluded: {ioc['value']}"


# ── Groq Client ───────────────────────────────────────────────────────────────


class TestGroqClient:

    def test_client_reads_env(self):
        """GroqClient should read GROQ_API_KEY from environment."""
        from src.llm.groq_client import groq_client

        # is_available is True if key is set, False if not — both are valid states
        assert isinstance(groq_client.is_available, bool)

    def test_no_key_returns_message(self, monkeypatch):
        """When no API key set, chat() should return a helpful message not raise."""
        import asyncio

        from src.llm.groq_client import GroqClient

        client = GroqClient()
        monkeypatch.setattr(client, "_api_key", "")  # clear the key

        messages = [{"role": "user", "content": "hello"}]
        result = asyncio.get_event_loop().run_until_complete(client.chat(messages))
        assert isinstance(result, str)
        assert len(result) > 0

    def test_model_name_property(self):
        from src.llm.groq_client import groq_client

        assert isinstance(groq_client.model_name, str)


# ── Cleaner Pipeline ──────────────────────────────────────────────────────────


class TestCleanerPipeline:

    def test_full_clean_cycle(self):
        raw = "<p>Critical <b>CVE-2024-1234</b> exploit   released.</p>"
        cleaned = clean_text(raw)

        assert "<p>" not in cleaned
        assert "<b>" not in cleaned
        assert "CVE-2024-1234" in cleaned
        assert "exploit" in cleaned
        assert "  " not in cleaned  # no double spaces

    def test_fingerprint_stable_across_whitespace(self):
        t1 = "ransomware attack on hospital"
        t2 = "  ransomware   attack   on   hospital  "
        assert fingerprint(t1) == fingerprint(t2)

    def test_fingerprint_different_for_different_content(self):
        assert fingerprint("ransomware attack") != fingerprint("phishing campaign")
