"""Laya: local System One conversation agent backed by a laya.serve endpoint."""

from __future__ import annotations

from homeassistant.config_entries import ConfigEntry
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant
from homeassistant.helpers.aiohttp_client import async_get_clientsession

from dataclasses import dataclass

from .client import LayaClient, Translator
from .const import CONF_TRANSLATE_URL, CONF_URL

PLATFORMS = (Platform.CONVERSATION,)


@dataclass
class LayaData:
    client: LayaClient
    translator: Translator | None


type LayaConfigEntry = ConfigEntry[LayaData]


async def async_setup_entry(hass: HomeAssistant, entry: LayaConfigEntry) -> bool:
    session = async_get_clientsession(hass)
    translate_url = entry.data.get(CONF_TRANSLATE_URL)
    entry.runtime_data = LayaData(
        LayaClient(session, entry.data[CONF_URL]),
        Translator(session, translate_url) if translate_url else None,
    )
    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    entry.async_on_unload(entry.add_update_listener(_async_reload))
    return True


async def async_unload_entry(hass: HomeAssistant, entry: LayaConfigEntry) -> bool:
    return await hass.config_entries.async_unload_platforms(entry, PLATFORMS)


async def _async_reload(hass: HomeAssistant, entry: LayaConfigEntry) -> None:
    await hass.config_entries.async_reload(entry.entry_id)
