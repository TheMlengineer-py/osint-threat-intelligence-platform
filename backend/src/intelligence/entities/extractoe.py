"""
Entity extractor using spaCy NER.
Maps spaCy labels to the platform's EntityType enum values.
Also extracts MITRE ATT&CK technique IDs (T1xxx pattern).
"""

import re

import spacy

from src.core.logging.logger import logger

# spaCy → platform entity type mapping
_SPACY_TO_TYPE: dict[str, str] = {
    "PERSON": "PERSON",
    "ORG": "ORG",
    "GPE": "LOC",
    "LOC": "LOC",
    "FAC": "LOC",
    "NORP": "ORG",  # nationalities / political groups → ORG
}

_MITRE_RE = re.compile(r"\bT\d{4}(?:\.\d{3})?\b")


class EntityExtractor:
    """Lazy-loaded spaCy NER extractor."""

    def __init__(self):
        self._nlp: spacy.Language | None = None

    def _model(self) -> spacy.Language:
        if self._nlp is None:
            try:
                self._nlp = spacy.load("en_core_web_sm")
                logger.info("spaCy model loaded", model="en_core_web_sm")
            except OSError:
                logger.warning("spaCy model not found; falling back to blank model")
                self._nlp = spacy.blank("en")
        return self._nlp

    def extract_entities(self, text: str, max_chars: int = 100_000) -> list[dict]:
        """
        Run NER and return unique entities.

        Returns:
            List of {"name", "type", "confidence"} dicts.
        """
        nlp = self._model()
        doc = nlp(text[:max_chars])

        seen: set = set()
        entities: list[dict] = []

        for ent in doc.ents:
            mapped = _SPACY_TO_TYPE.get(ent.label_)
            name = ent.text.strip()
            if not mapped or not name or name in seen:
                continue
            # Skip overly short tokens that are usually false positives
            if len(name) < 3:
                continue
            seen.add(name)
            entities.append({"name": name, "type": mapped, "confidence": 0.85})

        return entities

    def extract_mitre_techniques(self, text: str) -> list[dict]:
        """
        Extract MITRE ATT&CK technique IDs from text.

        Returns:
            List of {"technique_id": "T1059.001", "source": "text_match"}.
        """
        seen: set = set()
        results: list[dict] = []
        for match in _MITRE_RE.finditer(text):
            tid = match.group(0)
            if tid not in seen:
                seen.add(tid)
                results.append({"technique_id": tid, "source": "text_match"})
        return results

    def extractive_summary(self, text: str, max_sentences: int = 3) -> str:
        """
        Simple TF-based extractive summarisation.
        Used as fallback when Ollama is unavailable.
        """
        nlp = self._model()
        doc = nlp(text[:50_000])
        sentences = list(doc.sents)
        if len(sentences) <= max_sentences:
            return text

        word_freq: dict[str, int] = {}
        for token in doc:
            w = token.text.lower()
            if token.is_alpha and not token.is_stop:
                word_freq[w] = word_freq.get(w, 0) + 1

        scores: dict[int, float] = {
            i: sum(word_freq.get(t.text.lower(), 0) for t in sent if t.is_alpha)
            for i, sent in enumerate(sentences)
        }

        top = sorted(scores, key=scores.get, reverse=True)[:max_sentences]
        top.sort()
        return " ".join(str(sentences[i]) for i in top)


# Module-level singleton
entity_extractor = EntityExtractor()
