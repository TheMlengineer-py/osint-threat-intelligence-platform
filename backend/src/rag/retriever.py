"""
ChromaDB retriever — manages the vector collection and semantic search.
Upsert new threat documents and retrieve top-K similar ones for RAG.
Falls back gracefully when ChromaDB is not installed.
"""

try:
    import chromadb
    from chromadb.config import Settings as ChromaSettings

    _CHROMADB_AVAILABLE = True
except ImportError:
    chromadb = None  # type: ignore[assignment]
    ChromaSettings = None  # type: ignore[assignment,misc]
    _CHROMADB_AVAILABLE = False

from src.core.config.settings import settings
from src.core.logging.logger import logger
from src.rag.embedder import embedder


class Retriever:
    """ChromaDB-backed semantic search over ingested OSINT documents."""

    def __init__(self):
        self._client = None
        self._collection = None

    def _get_client(self):
        if not _CHROMADB_AVAILABLE:
            raise RuntimeError("ChromaDB not available in this environment")
        if self._client is None:
            self._client = chromadb.HttpClient(
                host=settings.chroma_host,
                port=settings.chroma_port,
                settings=ChromaSettings(anonymized_telemetry=False),
            )
        return self._client

    def _get_collection(self):
        if self._collection is None:
            client = self._get_client()
            self._collection = client.get_or_create_collection(
                name=settings.chroma_collection,
                metadata={"hnsw:space": "cosine"},
            )
            logger.info(
                "ChromaDB collection ready",
                collection=settings.chroma_collection,
                docs=self._collection.count(),
            )
        return self._collection

    def upsert(self, doc_id: str, text: str, metadata: dict | None = None) -> str:
        """Embed and upsert a single document. Returns the doc_id."""
        col = self._get_collection()
        vec = embedder.embed(text)
        col.upsert(
            ids=[doc_id],
            embeddings=[vec],
            documents=[text[:10_000]],
            metadatas=[metadata or {}],
        )
        return doc_id

    def upsert_batch(self, docs: list[dict]) -> list[str]:
        """Batch upsert. Args: docs: List of {"id", "text", "metadata"}."""
        col = self._get_collection()
        ids = [d["id"] for d in docs]
        texts = [d["text"][:10_000] for d in docs]
        metas = [d.get("metadata", {}) for d in docs]
        vecs = embedder.embed_batch(texts)
        col.upsert(ids=ids, embeddings=vecs, documents=texts, metadatas=metas)
        return ids

    def search(
        self,
        query: str,
        n_results: int = 10,
        where: dict | None = None,
    ) -> list[dict]:
        """Semantic search — returns top-K results sorted by cosine similarity."""
        if not _CHROMADB_AVAILABLE:
            return []
        col = self._get_collection()
        count = col.count()
        if count == 0:
            return []
        kwargs: dict = {
            "query_embeddings": [embedder.embed(query)],
            "n_results": min(n_results, count),
            "include": ["documents", "metadatas", "distances"],
        }
        if where:
            kwargs["where"] = where
        res = col.query(**kwargs)
        output: list[dict] = []
        if res["ids"]:
            for i, doc_id in enumerate(res["ids"][0]):
                dist = res["distances"][0][i] if res["distances"] else 1.0
                output.append(
                    {
                        "id": doc_id,
                        "text": res["documents"][0][i] if res["documents"] else "",
                        "metadata": res["metadatas"][0][i] if res["metadatas"] else {},
                        "similarity": round(1 - dist, 4),
                    }
                )
        return output

    def stats(self) -> dict:
        if not _CHROMADB_AVAILABLE:
            return {"collection": settings.chroma_collection, "count": 0}
        try:
            return {
                "collection": settings.chroma_collection,
                "count": self._get_collection().count(),
            }
        except Exception as exc:
            logger.warning("ChromaDB stats error", error=str(exc))
            return {"collection": settings.chroma_collection, "count": 0}


retriever = Retriever()
