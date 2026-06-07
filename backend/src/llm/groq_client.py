"""
Groq API client — cloud LLM inference.
Replaces Ollama in production (set GROQ_API_KEY in .env).
Falls back to context-only mode if key not set.

Fix: suppress groq's internal httpx logging that conflicts with structlog.
"""

from dotenv import load_dotenv

load_dotenv()
import logging
import os

# ── Suppress groq/httpx internal loggers BEFORE importing groq ───────────────
# This prevents: Logger._log() got an unexpected keyword argument 'model'
for noisy_logger in ("groq", "groq._base_client", "httpx", "httpcore"):
    logging.getLogger(noisy_logger).setLevel(logging.WARNING)
    logging.getLogger(noisy_logger).propagate = False

import asyncio

import groq as groq_module

from src.core.logging.logger import logger as app_logger


class GroqClient:
    """Groq cloud LLM client with graceful fallback."""

    def __init__(self):
        self._client: groq_module.Groq | None = None
        self._api_key: str = os.getenv("GROQ_API_KEY", "")
        self._model: str = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")

    def _get_client(self) -> groq_module.Groq | None:
        if not self._api_key:
            return None
        if self._client is None:
            self._client = groq_module.Groq(api_key=self._api_key)
        return self._client

    @property
    def is_available(self) -> bool:
        return bool(self._api_key)

    @property
    def model_name(self) -> str:
        return self._model if self.is_available else "none"

    async def chat(
        self,
        messages: list[dict],
        temperature: float = 0.3,
        max_tokens: int = 1024,
    ) -> str:
        """
        Send a chat request to Groq.
        Returns fallback message if API key not set or on error.
        """
        client = self._get_client()
        if not client:
            return self._no_key_message()

        try:
            response = await asyncio.to_thread(
                client.chat.completions.create,
                model=self._model,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
            )
            return response.choices[0].message.content or ""

        except groq_module.AuthenticationError:
            app_logger.error("Groq authentication failed — check GROQ_API_KEY")
            return "❌ Groq authentication failed. Please verify your API key in backend/.env"

        except groq_module.RateLimitError:
            app_logger.warning("Groq rate limit reached")
            return "⚠ Groq rate limit reached. Free tier: 14,400 requests/day. Try again shortly."

        except groq_module.APIConnectionError:
            app_logger.warning("Groq connection error")
            return "⚠ Cannot reach Groq API. Check internet connection."

        except Exception as exc:
            app_logger.warning(f"Groq error (handled): {type(exc).__name__}")
            return f"⚠ LLM error — {type(exc).__name__}. Context documents are shown in Sources below."

    @staticmethod
    def _no_key_message() -> str:
        return (
            "**AI Copilot — Context Mode**\n\n"
            "No LLM key configured. To enable full AI responses, add your "
            "Groq API key to `backend/.env`:\n\n"
            "```\nGROQ_API_KEY=gsk_your_key_here\n```\n\n"
            "Get a free key at https://console.groq.com — 14,400 requests/day free.\n\n"
            "Relevant threat context is still retrieved from your OSINT database "
            "and shown in the Sources section below."
        )


groq_client = GroqClient()
