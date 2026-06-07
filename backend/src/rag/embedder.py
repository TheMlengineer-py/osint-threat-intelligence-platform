"""
Embedder stub — wraps a sentence-transformer or Ollama embedding model.
"""

from src.core.logging.logger import logger


class Embedder:
    def embed(self, text: str) -> list[float]:
        """Return a vector embedding for a single text."""
        try:
            import asyncio

            from src.llm.ollama_client import ollama_client

            loop = asyncio.new_event_loop()
            result = loop.run_until_complete(ollama_client.embed(text))
            loop.close()
            return result
        except Exception as e:
            logger.warning("Embedding failed, returning zero vector", error=str(e))
            return [0.0] * 384

    def embed_batch(self, texts: list[str]) -> list[list[float]]:
        """Return embeddings for a list of texts."""
        return [self.embed(t) for t in texts]


embedder = Embedder()
