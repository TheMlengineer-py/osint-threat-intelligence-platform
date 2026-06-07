"""
RAG Pipeline — orchestrates Retriever + LLM to answer analyst queries.
Steps:
    1. Embed the query
    2. Retrieve top-K documents from ChromaDB
    3. Build an augmented prompt (context + query)
    4. Generate a response via Ollama
    5. Return answer + source references + follow-up suggestions
"""

from src.llm.ollama_client import ollama_client
from src.rag.retriever import retriever

_SYSTEM_PROMPT = (
    "You are an expert OSINT Threat Intelligence Analyst assisting security teams.\n"
    "You have access to a curated knowledge base of threat reports, CVEs, MITRE ATT&CK "
    "techniques, and OSINT-collected data.\n\n"
    "When answering:\n"
    "- Be precise and factual. Reference threat actors, malware families, CVE IDs when relevant.\n"
    "- Provide actionable recommendations where appropriate.\n"
    "- Distinguish confirmed intelligence from analytical assessment.\n"
    "- If you cannot find relevant information in the provided context, say so clearly.\n"
    "- Focus strictly on cybersecurity and threat intelligence topics."
)

_FOLLOW_UP_TEMPLATES = [
    "What MITRE ATT&CK techniques are associated with this threat?",
    "Which sectors or industries are most at risk?",
    "What are the recommended mitigations or defensive measures?",
    "Are there known indicators of compromise (IOCs) I should monitor?",
]


class RAGPipeline:

    async def query(
        self,
        user_query: str,
        history: list[dict] | None = None,
        n_context_docs: int = 5,
    ) -> dict:
        # ── Step 1: Retrieve context ────────────────────────────────────────
        context_docs = retriever.search(user_query, n_results=n_context_docs)
        context_text = self._format_context(context_docs)

        # ── Step 2: Build messages ──────────────────────────────────────────
        messages = [{"role": "system", "content": _SYSTEM_PROMPT}]
        for msg in (history or [])[-6:]:
            messages.append({"role": msg["role"], "content": msg["content"]})
        augmented_query = (
            f"THREAT INTELLIGENCE CONTEXT:\n{context_text}\n\n"
            f"ANALYST QUERY: {user_query}"
        )
        messages.append({"role": "user", "content": augmented_query})

        # ── Step 3: Generate ────────────────────────────────────────────────
        answer = await ollama_client.chat(messages)

        # ── Step 4: Build source references ────────────────────────────────
        sources = [
            {
                "id": d["id"],
                "title": d["metadata"].get("title", "Threat Document"),
                "source_url": d["metadata"].get("source_url", ""),
                "similarity": d["similarity"],
                "detected_at": d["metadata"].get("detected_at", ""),
            }
            for d in context_docs[:3]
        ]

        return {
            "answer": answer,
            "sources": sources,
            "follow_up_questions": _FOLLOW_UP_TEMPLATES[:3],
            "context_doc_count": len(context_docs),
        }

    async def summarise_document(self, text: str) -> str:
        """Generate a 2-3 sentence summary of a threat document."""
        messages = [
            {"role": "system", "content": _SYSTEM_PROMPT},
            {
                "role": "user",
                "content": (
                    "Provide a concise 2-3 sentence threat intelligence summary highlighting: "
                    "threat type, key actors/IOCs, and immediate risk level.\n\n"
                    f"{text[:3000]}"
                ),
            },
        ]
        return await ollama_client.chat(messages)

    async def generate_report(self, threats: list[dict]) -> str:
        """Generate a full structured intelligence report from multiple threats."""
        threat_block = "\n\n".join(
            f"Threat {i+1}: {t.get('title','')}\n"
            f"  Category: {t.get('category','')}  Severity: {t.get('severity','')}  "
            f"Risk: {t.get('risk_score','')}\n"
            f"  Summary: {t.get('summary','')}"
            for i, t in enumerate(threats[:10])
        )
        messages = [
            {"role": "system", "content": _SYSTEM_PROMPT},
            {
                "role": "user",
                "content": (
                    "Generate a structured intelligence report with the following sections: "
                    "Executive Summary, Threat Landscape Overview, Key Findings, "
                    "Risk Assessment, and Recommended Actions.\n\n"
                    f"{threat_block}"
                ),
            },
        ]
        return await ollama_client.chat(messages)

    @staticmethod
    def _format_context(docs: list[dict]) -> str:
        if not docs:
            return "No relevant threat intelligence found in the knowledge base."
        parts = []
        for i, doc in enumerate(docs, 1):
            meta = doc.get("metadata", {})
            parts.append(
                f"[Source {i}] {meta.get('title', 'Threat Document')}\n"
                f"Severity: {meta.get('severity','?')} | Category: {meta.get('category','?')} | "
                f"Risk: {meta.get('risk_score','?')}\n"
                f"{doc.get('text','')[:800]}"
            )
        return "\n\n---\n\n".join(parts)


rag_pipeline = RAGPipeline()
