"""
Async Ollama client.
Wraps the /api/chat endpoint with retry logic and a graceful fallback
message when Ollama is unavailable (e.g. model not yet pulled).
"""

import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

from src.core.config.settings import settings
from src.core.logging.logger import logger


class OllamaClient:

    @retry(
        stop=stop_after_attempt(2),
        wait=wait_exponential(multiplier=1, min=1, max=4),
        reraise=False,
    )
    async def chat(
        self,
        messages: list[dict],
        temperature: float = 0.3,
        max_tokens: int = 1024,
    ) -> str:
        """
        Send a chat completion request to Ollama.

        Args:
            messages: OpenAI-style message list [{"role": ..., "content": ...}].
            temperature: Sampling temperature (lower = more deterministic).
            max_tokens: Maximum tokens in the response.

        Returns:
            The assistant's reply as a string, or a fallback message on error.
        """
        payload = {
            "model": settings.ollama_model,
            "messages": messages,
            "stream": False,
            "options": {
                "temperature": temperature,
                "num_predict": max_tokens,
            },
        }

        try:
            async with httpx.AsyncClient(timeout=90.0) as client:
                response = await client.post(
                    f"{settings.ollama_host}/api/chat",
                    json=payload,
                )
                response.raise_for_status()
                data = response.json()
                return data["message"]["content"]

        except httpx.ConnectError:
            logger.warning("Ollama service unreachable", host=settings.ollama_host)
            return self._fallback()
        except httpx.TimeoutException:
            logger.warning("Ollama request timed out")
            return "The LLM request timed out. Please try again or reduce the query complexity."
        except Exception as exc:
            logger.error("Ollama error", error=str(exc))
            return self._fallback()

    @staticmethod
    def _fallback() -> str:
        return (
            "**Note — Local LLM Unavailable**\n\n"
            "Ollama is not yet running or the model hasn't been pulled. "
            "To activate the AI Copilot, run:\n\n"
            f"```\ndocker exec -it osint_ollama ollama pull {settings.ollama_model}\n```\n\n"
            "Relevant context documents are still shown in the Sources panel below."
        )

    async def is_available(self) -> bool:
        """Health-check the Ollama service."""
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                r = await client.get(f"{settings.ollama_host}/api/tags")
                return r.status_code == 200
        except Exception:
            return False


ollama_client = OllamaClient()
