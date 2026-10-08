"""Minimal client for laya.serve's `/v1/systemone` endpoint.

No auth: the server is LAN-only and can only answer questions, never act.
"""

from __future__ import annotations

import asyncio
from typing import Any

import aiohttp

from homeassistant.exceptions import HomeAssistantError

from .const import HEAD_MAX_LEN, MODEL, REQUEST_TIMEOUT


class LayaError(HomeAssistantError):
    """Server unreachable or returned an error."""


class LayaClient:
    def __init__(self, session: aiohttp.ClientSession, url: str) -> None:
        self._session = session
        self._url = url.rstrip("/") + "/v1/systemone"

    async def async_predict(
        self, state: str, questions: dict[str, Any], timeout: float = REQUEST_TIMEOUT
    ) -> dict[str, Any]:
        body = {
            "state": state,
            "questions": questions,
            "model": MODEL,
            "head_max_len": HEAD_MAX_LEN,
        }
        try:
            async with self._session.post(
                self._url, json=body, timeout=aiohttp.ClientTimeout(total=timeout)
            ) as resp:
                if resp.status != 200:
                    raise LayaError(f"HTTP {resp.status}: {await resp.text()}")
                data = await resp.json()
        except (aiohttp.ClientError, asyncio.TimeoutError) as err:
            raise LayaError(str(err)) from err
        return data.get("answers") or {}

    async def async_validate(self) -> None:
        """One real request: proves reachability and a loaded model."""
        await self.async_predict(
            "ping",
            {"q": {"type": "noul", "instructions": "Is this a test?"}},
            timeout=60,
        )


class Translator:
    """LibreTranslate: anything not English is translated to English.

    Failures return the text unchanged: worst case the model escalates.
    """

    def __init__(self, session: aiohttp.ClientSession, url: str) -> None:
        self._session = session
        self._url = url.rstrip("/") + "/translate"

    async def async_to_english(self, text: str, source: str | None = None) -> tuple[str, str]:
        """(English text, language code). `source` skips detection."""
        if source == "en":
            return text, source
        try:
            async with self._session.post(
                self._url,
                json={"q": text, "source": source or "auto", "target": "en"},
                timeout=aiohttp.ClientTimeout(total=REQUEST_TIMEOUT),
            ) as resp:
                if resp.status != 200:
                    return text, source or "en"
                data = await resp.json()
        except (aiohttp.ClientError, asyncio.TimeoutError):
            return text, source or "en"
        language = source or (data.get("detectedLanguage") or {}).get("language") or "en"
        if language == "en":
            return text, language
        return data.get("translatedText") or text, language
