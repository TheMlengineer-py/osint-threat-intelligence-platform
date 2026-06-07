"""
Entity extractor — optional spaCy NER.
Falls back gracefully when spaCy is not installed.
"""

import re
import logging

logger = logging.getLogger(__name__)

try:
    import spacy

    _SPACY_AVAILABLE = True
except ImportError:
    spacy = None  # type: ignore[assignment]
    _SPACY_AVAILABLE = False
    logger.warning("spaCy not available - entity extraction disabled")

_SPACY_TO_TYPE: dict[str, str] = {
    "PERSON": "PERSON",
    "ORG": "ORG",
    "GPE": "LOC",
    "LOC": "LOC",
    "FAC": "LOC",
    "NORP": "ORG",
}
_MITRE_RE = re.compile(r"\bT\d{4}(?:\.\d{3})?\b")


class EntityExtractor:
    def __init__(self):
        self._nlp = None

    def _model(self):
        if not _SPACY_AVAILABLE:
            return None
        if self._nlp is None:
            try:
                self._nlp = spacy.load("en_core_web_sm")
                logger.info("spaCy model loaded")
            except OSError:
                logger.warning("spaCy model not found; using blank model")
                self._nlp = spacy.blank("en")
        return self._nlp

    def extract_entities(self, text: str, max_chars: int = 100_000) -> list[dict]:
        nlp = self._model()
        if nlp is None:
            return []
        doc = nlp(text[:max_chars])
        seen: set = set()
        entities: list[dict] = []
        for ent in doc.ents:
            mapped = _SPACY_TO_TYPE.get(ent.label_)
            name = ent.text.strip()
            if not mapped or not name or name in seen or len(name) < 3:
                continue
            seen.add(name)
            entities.append({"name": name, "type": mapped, "confidence": 0.85})
        return entities

    def extract_mitre_techniques(self, text: str) -> list[dict]:
        seen: set = set()
        results: list[dict] = []
        for match in _MITRE_RE.finditer(text):
            tid = match.group(0)
            if tid not in seen:
                seen.add(tid)
                results.append({"technique_id": tid, "source": "text_match"})
        return results

    def extractive_summary(self, text: str, max_sentences: int = 3) -> str:
        nlp = self._model()
        if nlp is None:
            sentences = text.split(". ")
            return ". ".join(sentences[:max_sentences])
        doc = nlp(text[:50_000])
        sentences = list(doc.sents)
        if len(sentences) <= max_sentences:
            return text
        word_freq: dict[str, int] = {}
        for token in doc:
            w = token.text.lower()
            if token.is_alpha and not token.is_stop:
                word_freq[w] = word_freq.get(w, 0) + 1
        scores = {
            i: sum(word_freq.get(t.text.lower(), 0) for t in sent if t.is_alpha)
            for i, sent in enumerate(sentences)
        }
        top = sorted(scores, key=scores.get, reverse=True)[:max_sentences]
        top.sort()
        return " ".join(str(sentences[i]) for i in top)


entity_extractor = EntityExtractor()
