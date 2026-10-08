"""Constants for the Laya conversation agent."""

from typing import Final

DOMAIN: Final = "laya"

CONF_URL: Final = "url"
CONF_TRANSLATE_URL: Final = "translate_url"
CONF_FALLBACK_AGENT: Final = "fallback_agent"
CONF_CONFIDENCE: Final = "confidence_threshold"
CONF_COMPOUND: Final = "compound_threshold"

DEFAULT_URL: Final = "http://macmini.local:8000"
DEFAULT_TRANSLATE_URL: Final = "http://macmini.local:5000"

# The only checkpoint the server loads; pinned so the router never picks.
MODEL: Final = "multilingual"
# Question+options budget per request, inside the checkpoint's 1024 tokens.
# The state is a single utterance, so it needs little of what is left.
HEAD_MAX_LEN: Final = 768
REQUEST_TIMEOUT: Final = 10
