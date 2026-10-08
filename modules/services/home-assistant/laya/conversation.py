"""Laya conversation agent: fast local intent routing, everything else escalated."""

from __future__ import annotations

import logging
from typing import Literal

from homeassistant.components import conversation
from homeassistant.components.homeassistant.exposed_entities import async_should_expose
from homeassistant.const import MATCH_ALL
from homeassistant.core import HomeAssistant
from homeassistant.helpers import (
    area_registry as ar,
    device_registry as dr,
    entity_registry as er,
    intent,
)
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from . import LayaConfigEntry
from .client import LayaError
from .const import CONF_COMPOUND, CONF_CONFIDENCE, CONF_FALLBACK_AGENT, DOMAIN
from .pipeline import (
    DEFAULT_COMPOUND,
    DEFAULT_CONFIDENCE,
    Area,
    Entity,
    Home,
    Planner,
    slots,
    translation_source,
)

_LOGGER = logging.getLogger(__name__)


async def async_setup_entry(
    hass: HomeAssistant,
    entry: LayaConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    async_add_entities([LayaConversationEntity(entry)])


def _aliases(aliases) -> tuple[str, ...]:
    # The registry may hold a COMPUTED_NAME sentinel next to real strings.
    return tuple(a for a in aliases or () if isinstance(a, str))


def _build_home(hass: HomeAssistant) -> Home:
    area_reg = ar.async_get(hass)
    entity_reg = er.async_get(hass)
    device_reg = dr.async_get(hass)

    entities = []
    for state in hass.states.async_all():
        if not async_should_expose(hass, conversation.DOMAIN, state.entity_id):
            continue
        entry = entity_reg.async_get(state.entity_id)
        area_id = entry.area_id if entry else None
        if entry and not area_id and entry.device_id:
            device = device_reg.async_get(entry.device_id)
            area_id = device.area_id if device else None
        entities.append(
            Entity(
                entity_id=state.entity_id,
                name=state.name,
                area_id=area_id,
                aliases=_aliases(entry.aliases) if entry else (),
            )
        )

    areas = tuple(
        Area(area_id=a.id, name=a.name, aliases=_aliases(a.aliases))
        for a in area_reg.async_list_areas()
    )
    registered = frozenset(h.intent_type for h in intent.async_get(hass))
    return Home(tuple(entities), areas, registered)


class LayaConversationEntity(
    conversation.ConversationEntity, conversation.AbstractConversationAgent
):
    _attr_has_entity_name = True
    _attr_name = None

    def __init__(self, entry: LayaConfigEntry) -> None:
        self._entry = entry
        self._attr_unique_id = entry.entry_id

    @property
    def supported_languages(self) -> list[str] | Literal["*"]:
        return MATCH_ALL

    async def async_added_to_hass(self) -> None:
        await super().async_added_to_hass()
        conversation.async_set_agent(self.hass, self._entry, self)

    async def async_will_remove_from_hass(self) -> None:
        conversation.async_unset_agent(self.hass, self._entry)
        await super().async_will_remove_from_hass()

    async def _async_handle_message(
        self,
        user_input: conversation.ConversationInput,
        chat_log: conversation.ChatLog,
    ) -> conversation.ConversationResult:
        home = _build_home(self.hass)
        options = self._entry.options
        data = self._entry.runtime_data
        source = translation_source(user_input.language)
        text, language = user_input.text, source or "en"
        if data.translator:
            text, language = await data.translator.async_to_english(user_input.text, source)
        planner = Planner(
            home,
            text,
            confidence=options.get(CONF_CONFIDENCE, DEFAULT_CONFIDENCE),
            compound=options.get(CONF_COMPOUND, DEFAULT_COMPOUND),
            original=user_input.text,
        )

        try:
            round2 = planner.round2(await data.client.async_predict(text, planner.round1()))
            if round2 is not None:
                planner.finish(await data.client.async_predict(text, round2))
        except LayaError as err:
            return await self._escalate(user_input, f"laya unavailable: {err}")

        decision = planner.decision
        _LOGGER.debug("%r (%s: %r) -> %s", user_input.text, language, text, decision)
        if decision.escalate:
            return await self._escalate(user_input, decision.escalate)

        try:
            response = await intent.async_handle(
                self.hass,
                DOMAIN,
                decision.intent,
                slots(decision, home),
                user_input.text,
                user_input.context,
                user_input.language,
                assistant=conversation.DOMAIN,
                device_id=user_input.device_id,
                satellite_id=user_input.satellite_id,
                conversation_agent_id=self.entity_id,
            )
        except intent.IntentError as err:
            return await self._escalate(user_input, f"{decision.intent} failed: {err}")

        # Service-call handlers act but say nothing; Assist's default agent
        # renders its speech from templates we do not have.
        if (
            response.response_type == intent.IntentResponseType.ACTION_DONE
            and not response.speech
        ):
            response.async_set_speech("Feito." if language == "pt" else "Done.")

        return conversation.ConversationResult(
            response=response, conversation_id=user_input.conversation_id
        )

    async def _escalate(
        self, user_input: conversation.ConversationInput, reason: str
    ) -> conversation.ConversationResult:
        fallback = self._entry.options.get(CONF_FALLBACK_AGENT)
        _LOGGER.debug("escalating %r to %s: %s", user_input.text, fallback, reason)
        if fallback and fallback != self.entity_id:
            return await conversation.async_converse(
                self.hass,
                # Always what was said, never the translation: the LLM reads
                # Portuguese fine and the translation loses names.
                user_input.text,
                user_input.conversation_id,
                user_input.context,
                language=user_input.language,
                agent_id=fallback,
                device_id=user_input.device_id,
                satellite_id=user_input.satellite_id,
            )

        response = intent.IntentResponse(language=user_input.language)
        response.async_set_error(
            intent.IntentResponseErrorCode.NO_INTENT_MATCH,
            "Sorry, I did not understand that.",
        )
        return conversation.ConversationResult(
            response=response, conversation_id=user_input.conversation_id
        )
