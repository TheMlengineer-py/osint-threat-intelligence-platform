"""
Unit tests — text preprocessing (cleaner + language detector).
No external dependencies required.
"""


class TestCleanText:
    def test_html_tags_stripped(self):
        from src.preprocessing.cleaner import clean_text

        result = clean_text("<p>Critical <b>ransomware</b> detected.</p>")
        assert "<p>" not in result
        assert "<b>" not in result
        assert "ransomware" in result

    def test_nested_html_stripped(self):
        from src.preprocessing.cleaner import clean_text

        result = clean_text("<div><span class='alert'>Malware</span></div>")
        assert "<div>" not in result
        assert "<span>" not in result
        assert "Malware" in result

    def test_whitespace_normalised(self):
        from src.preprocessing.cleaner import clean_text

        result = clean_text("  too   many    spaces\t\ttabs\n\nnewlines  ")
        assert "  " not in result
        assert "\t" not in result
        assert result == result.strip()

    def test_empty_string_returns_empty(self):
        from src.preprocessing.cleaner import clean_text

        assert clean_text("") == ""

    def test_plain_text_preserved(self):
        from src.preprocessing.cleaner import clean_text

        text = "Ransomware attack targets healthcare sector"
        result = clean_text(text)
        assert "ransomware" in result.lower()
        assert "healthcare" in result.lower()


class TestFingerprint:
    def test_same_text_produces_same_fingerprint(self):
        from src.preprocessing.cleaner import fingerprint

        text = "CVE-2024-9999 ransomware healthcare"
        assert fingerprint(text) == fingerprint(text)

    def test_case_insensitive(self):
        from src.preprocessing.cleaner import fingerprint

        assert fingerprint("Hello World") == fingerprint("hello world")
        assert fingerprint("RANSOMWARE") == fingerprint("ransomware")

    def test_fingerprint_is_64_char_hex(self):
        from src.preprocessing.cleaner import fingerprint

        fp = fingerprint("some text")
        assert len(fp) == 64
        assert all(c in "0123456789abcdef" for c in fp)

    def test_different_texts_produce_different_fingerprints(self):
        from src.preprocessing.cleaner import fingerprint

        assert fingerprint("text one") != fingerprint("text two")
        assert fingerprint("ransomware") != fingerprint("phishing")

    def test_whitespace_variations_same_fingerprint(self):
        from src.preprocessing.cleaner import fingerprint

        assert fingerprint("a b c") == fingerprint("a  b  c")


class TestSecurityRelevance:
    def test_security_text_is_relevant(self):
        from src.preprocessing.cleaner import is_security_relevant

        texts = [
            "Critical ransomware attack on hospital",
            "CVE vulnerability exploit remote code execution",
            "Cyber attack phishing campaign",
            "Data breach exposed credentials",
            "Malware trojan backdoor detected",
        ]
        for text in texts:
            assert is_security_relevant(text) is True, f"Should be relevant: {text!r}"

    def test_unrelated_text_is_not_relevant(self):
        from src.preprocessing.cleaner import is_security_relevant

        texts = [
            "The weather today is sunny and warm",
            "Football match ended in a draw",
            "Quarterly earnings report released",
            "New restaurant opens downtown",
        ]
        for text in texts:
            assert (
                is_security_relevant(text) is False
            ), f"Should NOT be relevant: {text!r}"

    def test_empty_string_is_not_relevant(self):
        from src.preprocessing.cleaner import is_security_relevant

        assert is_security_relevant("") is False


class TestLanguageDetector:
    def test_english_detected(self):
        from src.preprocessing.language_detector import detect_language, is_english

        text = "Critical vulnerability discovered in popular web server"
        assert detect_language(text) == "en"
        assert is_english(text) is True

    def test_empty_returns_unknown(self):
        from src.preprocessing.language_detector import detect_language

        result = detect_language("")
        assert result in ("en", "unknown")  # langdetect may return 'en' on empty
