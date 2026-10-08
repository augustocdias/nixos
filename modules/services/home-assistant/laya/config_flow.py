"""Config and options flow for Laya."""

from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant.config_entries import (
    ConfigEntry,
    ConfigFlow,
    ConfigFlowResult,
    OptionsFlow,
)
from homeassistant.core import callback
from homeassistant.helpers import selector
from homeassistant.helpers.aiohttp_client import async_get_clientsession

from .client import LayaClient, LayaError
from .const import (
    CONF_COMPOUND,
    CONF_CONFIDENCE,
    CONF_FALLBACK_AGENT,
    CONF_TRANSLATE_URL,
    CONF_URL,
    DEFAULT_TRANSLATE_URL,
    DEFAULT_URL,
    DOMAIN,
)
from .pipeline import DEFAULT_COMPOUND, DEFAULT_CONFIDENCE


class LayaConfigFlow(ConfigFlow, domain=DOMAIN):
    VERSION = 1

    async def async_step_user(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        errors: dict[str, str] = {}
        if user_input is not None:
            client = LayaClient(async_get_clientsession(self.hass), user_input[CONF_URL])
            try:
                await client.async_validate()
            except LayaError:
                errors["base"] = "cannot_connect"
            else:
                return self.async_create_entry(title="Laya", data=user_input)

        return self.async_show_form(
            step_id="user",
            data_schema=vol.Schema(
                {
                    vol.Required(CONF_URL, default=DEFAULT_URL): selector.TextSelector(
                        selector.TextSelectorConfig(type=selector.TextSelectorType.URL)
                    ),
                    vol.Optional(
                        CONF_TRANSLATE_URL, default=DEFAULT_TRANSLATE_URL
                    ): selector.TextSelector(
                        selector.TextSelectorConfig(type=selector.TextSelectorType.URL)
                    ),
                }
            ),
            errors=errors,
        )

    @staticmethod
    @callback
    def async_get_options_flow(config_entry: ConfigEntry) -> OptionsFlow:
        return LayaOptionsFlow()


def _slider() -> selector.NumberSelector:
    return selector.NumberSelector(
        selector.NumberSelectorConfig(
            min=0.0, max=1.0, step=0.05, mode=selector.NumberSelectorMode.SLIDER
        )
    )


class LayaOptionsFlow(OptionsFlow):
    async def async_step_init(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        if user_input is not None:
            return self.async_create_entry(title="", data=user_input)

        options = self.config_entry.options
        return self.async_show_form(
            step_id="init",
            data_schema=vol.Schema(
                {
                    vol.Optional(
                        CONF_FALLBACK_AGENT,
                        description={"suggested_value": options.get(CONF_FALLBACK_AGENT)},
                    ): selector.ConversationAgentSelector(),
                    vol.Optional(
                        CONF_CONFIDENCE,
                        default=options.get(CONF_CONFIDENCE, DEFAULT_CONFIDENCE),
                    ): _slider(),
                    vol.Optional(
                        CONF_COMPOUND,
                        default=options.get(CONF_COMPOUND, DEFAULT_COMPOUND),
                    ): _slider(),
                }
            ),
        )
