"""
Language detection wrapper using langdetect.
Returns ISO 639-1 language codes; falls back to "unknown" on failure.
"""

from langdetect import LangDetectException, detect


def detect_language(text: str, sample_length: int = 500) -> str:
    """
    Detect the primary language of a document.

    Args:
        text: Input text.
        sample_length: Only sample the first N characters for speed.

    Returns:
        ISO 639-1 code (e.g. "en", "de", "fr") or "unknown".
    """
    try:
        return detect(text[:sample_length])
    except LangDetectException:
        return "unknown"
    except Exception:
        return "unknown"


def is_english(text: str) -> bool:
    """Convenience check — True if the text appears to be English."""
    return detect_language(text) == "en"
