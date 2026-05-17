# backend/services/gemini_service.py
# ============================================================
# Gemini API Service — Wrapper for all agent LLM calls.
# Agents call run_agent_prompt(); this module handles:
#   - API initialization (singleton)
#   - System prompt loading
#   - JSON extraction + retry logic
#   - Error handling (never raises — always returns fallback)
# ============================================================

from __future__ import annotations

import json
import logging
import re
from typing import Any, Optional

import google.generativeai as genai

from backend.config import settings

logger = logging.getLogger(__name__)

_initialized = False


def initialize_gemini() -> None:
    """Initialize Gemini API once at startup."""
    global _initialized
    if _initialized:
        return
    if not settings.GEMINI_API_KEY:
        logger.warning("GEMINI_API_KEY not set — Gemini calls will fail.")
        return
    genai.configure(api_key=settings.GEMINI_API_KEY)
    _initialized = True
    logger.info(f"Gemini initialized. Model: {settings.GEMINI_MODEL}")


def _extract_json(text: str) -> Optional[dict]:
    """
    Extract JSON from a Gemini response string.
    Handles:
      - Pure JSON response
      - JSON wrapped in ```json ... ``` blocks
      - JSON embedded in prose
    """
    # Strip markdown code fences
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text, flags=re.MULTILINE)
    text = re.sub(r"\s*```$", "", text, flags=re.MULTILINE)
    text = text.strip()

    # Try direct parse first
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Try to find JSON object in the text
    match = re.search(r"\{[\s\S]+\}", text)
    if match:
        try:
            return json.loads(match.group())
        except json.JSONDecodeError:
            pass

    return None


async def run_agent_prompt(
    system_prompt: str,
    user_message: str,
    temperature: float = 0.2,
    max_retries: int = 2,
) -> Optional[dict]:
    """
    Send a prompt to Gemini and return parsed JSON response.

    Args:
        system_prompt: The agent's system instructions
        user_message: The input for this specific call
        temperature: Lower = more deterministic (default 0.2 for pipeline agents)
        max_retries: Number of retry attempts on JSON parse failure

    Returns:
        Parsed dict from Gemini response, or None on total failure.
    """
    if not _initialized:
        initialize_gemini()

    model = genai.GenerativeModel(
        model_name=settings.GEMINI_MODEL,
        system_instruction=system_prompt,
        generation_config=genai.GenerationConfig(
            temperature=temperature,
            response_mime_type="application/json",
        ),
    )

    for attempt in range(1, max_retries + 1):
        try:
            response = model.generate_content(user_message)
            raw_text = response.text

            parsed = _extract_json(raw_text)
            if parsed is not None:
                return parsed

            logger.warning(
                f"Gemini returned non-JSON on attempt {attempt}. "
                f"Raw (first 200): {raw_text[:200]}"
            )

        except Exception as exc:
            logger.error(f"Gemini call failed on attempt {attempt}: {exc}")

    logger.error(f"Gemini failed after {max_retries} attempts. Returning None.")
    return None


async def run_intake_agent(raw_input: str) -> Optional[dict]:
    """
    Run the Intake Agent with the canonical system prompt.
    Returns a CaseObject dict or None on total failure.
    """
    # Import here to avoid circular deps
    from agents.intake.prompt import INTAKE_AGENT_SYSTEM_PROMPT

    return await run_agent_prompt(
        system_prompt=INTAKE_AGENT_SYSTEM_PROMPT,
        user_message=raw_input,
        temperature=0.1,  # Very low — deterministic extraction
    )
