"""Laya decision pipeline: System One questions in, one Home Assistant intent out.

Pure stdlib on purpose. The conversation entity and the offline eval harness
(`../laya-eval/eval.py`) both drive this module, so what gets measured is
exactly what runs in Home Assistant.

Laya only *chooses* among options it is given; it never writes text. So:

* there is no lexical pre-filtering of the utterance. The multilingual
  checkpoint matches a pt-BR request against English options itself, which is
  why nothing here knows any Portuguese;
* numbers cannot come from the model, they are read from the text, and the
  chosen intent decides what a number means (brightness, position, ...);
* every choice is kept small and concrete. Measured: a single flat choice over
  all intents collapses (pt-BR requests landed on the vacuum). Round 1 asks
  the kind of request and of device; round 2 offers only that kind's own verbs
  ("open"/"close" for blinds);
* the device is grounded in the text through names and aliases (see
  `Planner`), because the model confidently picked wrong rooms. Area-wide
  requests ("all the lights") are not handled: they escalate.

Anything uncertain, a question, or a multi-step request is escalated; the
caller hands the untouched utterance to the fallback (LLM) agent.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from typing import Any

# A choice's confidence is normalised for its option count, (N*p - 1) / (N - 1):
# 0 = uniform guess, 1 = certain. Without it a 0.4 means different things for
# 3 options and for 30.
DEFAULT_CONFIDENCE = 0.4
DEFAULT_COMPOUND = 0.7



@dataclass(frozen=True)
class Entity:
    entity_id: str
    name: str
    area_id: str | None = None
    aliases: tuple[str, ...] = ()

    @property
    def domain(self) -> str:
        return self.entity_id.split(".", 1)[0]


@dataclass(frozen=True)
class Area:
    area_id: str
    name: str
    aliases: tuple[str, ...] = ()


@dataclass(frozen=True)
class Home:
    entities: tuple[Entity, ...]
    areas: tuple[Area, ...]
    # Intent types Home Assistant has handlers for. Only these are offered.
    registered_intents: frozenset[str]

    def entity(self, entity_id: str) -> Entity | None:
        return next((e for e in self.entities if e.entity_id == entity_id), None)

    def area(self, area_id: str | None) -> Area | None:
        return next((a for a in self.areas if a.area_id == area_id), None)


# Intents whose required slot is read from the text: slot name, type.
NUMBER_SLOTS: dict[str, tuple[str, type]] = {
    "HassLightSet": ("brightness", int),
    "HassSetPosition": ("position", int),
    "HassClimateSetTemperature": ("temperature", float),
    "HassSetVolume": ("volume_level", int),
}

ON = "HassTurnOn"
OFF = "HassTurnOff"

# Per kind of device: what it is called, and its actions in its own words.
# Action intents only. Informational intents (state, weather, time) go to the
# fallback agent: their handlers return data, not speech.
KINDS: dict[str, tuple[str, dict[str, str]]] = {
    "light": (
        "lights or lamps",
        {ON: "Turn on", OFF: "Turn off", "HassLightSet": "Set the brightness"},
    ),
    "switch": ("switches, sockets or plugs", {ON: "Turn on", OFF: "Turn off"}),
    "cover": (
        "blinds, shades, shutters or curtains",
        {ON: "Open", OFF: "Close", "HassSetPosition": "Set to a position"},
    ),
    "lock": ("door locks", {ON: "Lock", OFF: "Unlock"}),
    "fan": ("fans", {ON: "Turn on", OFF: "Turn off"}),
    "climate": (
        "thermostats or heating",
        {ON: "Turn on", OFF: "Turn off", "HassClimateSetTemperature": "Set the temperature"},
    ),
    "media_player": (
        "speakers, TVs or music players",
        {
            "HassMediaPause": "Pause",
            "HassMediaUnpause": "Resume playing",
            "HassMediaNext": "Next song",
            "HassMediaPrevious": "Previous song",
            "HassSetVolume": "Set the volume",
            ON: "Turn on",
            OFF: "Turn off",
        },
    ),
    "vacuum": (
        "robot vacuum cleaners",
        {"HassVacuumStart": "Start cleaning", "HassVacuumReturnToBase": "Go back to the dock"},
    ),
    "valve": ("valves", {ON: "Open", OFF: "Close", "HassSetPosition": "Set to a position"}),
    "humidifier": ("humidifiers", {ON: "Turn on", OFF: "Turn off"}),
    "scene": ("scenes", {ON: "Activate"}),
    "script": ("scripts or routines", {ON: "Run"}),
    "automation": ("automations", {ON: "Enable", OFF: "Disable"}),
    "input_boolean": ("toggles", {ON: "Turn on", OFF: "Turn off"}),
}

# Switches often stand in for these ("mirror light", "outside lights"), so they
# stay candidates when one of these kinds is chosen.
SWITCH_STANDS_IN = frozenset({"light", "fan"})

# "22", "21,5" (pt decimal comma), "21.5". Not part of a word or longer number.
_NUMBER = re.compile(r"(?<![\w.,])(\d+(?:[.,]\d+)?)(?![\w])")


def translation_source(language: str | None) -> str | None:
    """The pipeline's language as a LibreTranslate source; None = detect.

    With one pipeline per language the request language is authoritative (HA
    sends the pipeline's STT language, which also overrides whisper's
    --language auto). "*" or nothing falls back to detection, which is
    unreliable on short phrases.
    """
    if not language or language == "*":
        return None
    return language.split("-")[0].split("_")[0].lower()


def parse_number(text: str) -> float | None:
    match = _NUMBER.search(text)
    return float(match.group(1).replace(",", ".")) if match else None


def _label(name: str, aliases: tuple[str, ...], suffix: str = "") -> str:
    seen: dict[str, str] = {}
    for item in (name, *aliases):
        seen.setdefault(item.casefold(), item)
    return ", ".join(seen.values()) + suffix


def choice(answers: dict[str, Any], qid: str) -> tuple[str | None, float]:
    """(chosen option, count-normalised confidence) of a choice answer."""
    answer = answers.get(qid) or {}
    picked = answer.get("choice")
    probabilities = answer.get("probabilities") or {}
    n = len(probabilities)
    if picked is None or n == 0:
        return picked, 0.0
    if n == 1:
        return picked, 1.0
    p = float(probabilities.get(picked, 0.0))
    return picked, max(0.0, (n * p - 1) / (n - 1))


def noul(answers: dict[str, Any], qid: str) -> float:
    return float((answers.get(qid) or {}).get("noul", 0.0))


@dataclass
class Decision:
    intent: str | None = None
    entity_id: str | None = None
    area_id: str | None = None
    domain: str | None = None
    number: float | int | None = None
    # Set means: do not act, hand the utterance to the fallback agent.
    escalate: str | None = None
    trace: list[str] = field(default_factory=list)


def _words(text: str) -> list[str]:
    """Casefolded, accent-free words; possessive 's dropped ("Tobias's" -> "tobias")."""
    text = unicodedata.normalize("NFKD", text.casefold())
    text = "".join(c for c in text if not unicodedata.combining(c))
    return re.findall(r"\w+", re.sub(r"['’]s\b", "", text))


def _named(words: list[str], phrases: dict[Any, tuple[str, ...]]) -> set[Any]:
    """Ids whose name or alias occurs in `words` as a whole phrase.

    A match inside a longer match is dropped, so "quarto do Tobias" names
    Tobias's room and not also the bedroom ("quarto").
    """
    spans = []
    for oid, names in phrases.items():
        for name in names:
            w = _words(name)
            n = len(w)
            if n:
                spans += [(i, i + n, oid) for i in range(len(words) - n + 1) if words[i : i + n] == w]
    return {
        oid
        for s, e, oid in spans
        if not any(s2 <= s and e <= e2 and (s2, e2) != (s, e) for s2, e2, _ in spans)
    }


class Planner:
    """Drives one utterance through the two question rounds.

    Usage: `q1 = p.round1()`; `q2 = p.round2(answers1)`; if `q2` is not None,
    `p.finish(answers2)`. The outcome is `p.decision`.

    The model decides *what* (request, kind of device, action); *which device*
    is grounded in the text: a device must be named by its name or an alias,
    or be the only one of its kind in the room the text names (or the house).
    The model's own pick of a room or device is never trusted on its own:
    measured, it put "open Tobias's blinds" on the bedroom at 0.88.
    """

    def __init__(
        self,
        home: Home,
        text: str,
        confidence: float = DEFAULT_CONFIDENCE,
        compound: float = DEFAULT_COMPOUND,
        original: str | None = None,
    ) -> None:
        """`text` is what the model reads (English, possibly translated);
        `original` is what was said. Names and numbers are grounded in the
        original first: translation turns "luz da sala" into "the room light",
        but the alias "luz da sala" still names the living room light."""
        self.home = home
        self.text = text
        self.original = original or text
        self.confidence = confidence
        self.compound = compound
        self.decision = Decision()
        self._actions: dict[str, str] = {}
        self._candidates: list[Entity] = []
        # per question: option text -> id. Laya renders a choice option as
        # "key: description", so ids (HassTurnOn, light.x) never go in the key;
        # the model only ever reads human text.
        self._ids: dict[str, dict[str, str]] = {}
        # One pool, so a room word inside a device name ("Hallway Light")
        # does not also count as naming that room.
        phrases = {("e", e.entity_id): (e.name, *e.aliases) for e in home.entities} | {
            ("a", a.area_id): (a.name, *a.aliases) for a in home.areas
        }
        named = _named(_words(self.original), phrases) or _named(_words(text), phrases)
        self.named_entities = {i for k, i in named if k == "e"}
        self.named_areas = {i for k, i in named if k == "a"}

    def _choice(self, qid: str, instructions: str, options: dict[str, str]) -> dict[str, Any]:
        texts: dict[str, str] = {}
        for oid, text in options.items():
            texts[text if text not in texts else f"{text} [{oid}]"] = oid
        self._ids[qid] = texts
        return {"type": "choice", "instructions": instructions, "criteria": dict.fromkeys(texts)}

    def _pick(self, answers: dict[str, Any], qid: str) -> tuple[str | None, float]:
        text, conf = choice(answers, qid)
        return self._ids.get(qid, {}).get(text, text), conf

    def _actions_for(self, domain: str) -> dict[str, str]:
        return {
            i: label
            for i, label in KINDS[domain][1].items()
            if i in self.home.registered_intents
        }

    @property
    def kinds(self) -> list[str]:
        present = {e.domain for e in self.home.entities}
        return sorted(d for d in KINDS if d in present and self._actions_for(d))

    def round1(self) -> dict[str, dict[str, Any]]:
        return {
            "request": {
                "type": "choice",
                "instructions": "What kind of request is this?",
                "criteria": {
                    "command": "A command to control a device: turn on or off, open, "
                    "close, lock, set a level, play or pause, start cleaning",
                    "question": "A question, or a request for information",
                    "other": "Chit-chat or anything else",
                },
            },
            "kind": self._choice(
                "kind",
                "What kind of device is the request about?",
                {d: KINDS[d][0] for d in self.kinds},
            ),
            "compound": {
                "type": "noul",
                "instructions": "Does the request ask for two or more different actions?",
            },
        }

    def _escalate(self, reason: str) -> None:
        self.decision.escalate = reason
        return None

    def _confident(self, answers: dict[str, Any], qid: str) -> str | None:
        picked, conf = self._pick(answers, qid)
        self.decision.trace.append(f"{qid}={picked} ({conf:.2f})")
        if conf < self.confidence:
            self._escalate(f"low {qid} confidence {conf:.2f}")
            return None
        return picked

    def _ground(self, kind: str) -> list[Entity] | None:
        """The devices the text can mean, or None (escalated) when it is not clear."""
        domains = {kind} | ({"switch"} if kind in SWITCH_STANDS_IN else set())
        of_kind = [e for e in self.home.entities if e.domain in domains]
        named = [e for e in of_kind if e.entity_id in self.named_entities]
        self.decision.trace.append(
            f"named={sorted(self.named_entities)} rooms={sorted(self.named_areas)}"
        )
        if named:
            if self.named_areas:
                # The room in the text must hold the device: it decides between
                # two "Hallway Light"s, and vetoes "the downstairs bathroom
                # mirror light" matching the upstairs one's alias.
                named = [e for e in named if e.area_id in self.named_areas or e.area_id is None]
                if not named:
                    return self._escalate("the named device is in another room than the one named")
            return named
        if self.named_entities:
            return self._escalate(f"the named device is not one of the {KINDS[kind][0]}")
        if len(self.named_areas) > 1:
            return self._escalate("several rooms named")
        if self.named_areas:
            (area,) = self.named_areas
            of_kind = [e for e in of_kind if e.area_id == area]
        if len(of_kind) != 1:
            return self._escalate(f"{len(of_kind)} {KINDS[kind][0]} match and none is named")
        return of_kind

    def round2(self, answers: dict[str, Any]) -> dict[str, dict[str, Any]] | None:
        d = self.decision
        request = self._confident(answers, "request")
        if request is None:
            return None
        if request != "command":
            return self._escalate(f"request is {request}")
        compound = noul(answers, "compound")
        d.trace.append(f"compound={compound:.2f}")
        if compound >= self.compound:
            return self._escalate(f"compound {compound:.2f}")

        # A named device settles its own kind; the model is only asked when
        # nothing is named (it called "the kitchen light" a switch).
        named_kinds = {
            e.domain
            for e in self.home.entities
            if e.entity_id in self.named_entities
            and (not self.named_areas or e.area_id in self.named_areas or e.area_id is None)
        } & set(self.kinds)
        if len(named_kinds) == 1:
            (kind,) = named_kinds
            d.trace.append(f"kind={kind} (named)")
        else:
            kind = self._confident(answers, "kind")
            if kind is None:
                return None
        if kind not in self.kinds:
            return self._escalate(f"kind {kind}")
        d.domain = kind

        candidates = self._ground(kind)
        if candidates is None:
            return None
        self._actions = self._actions_for(kind)
        self._candidates = candidates

        labels = list(self._actions.items())
        questions = {
            "action": self._choice(
                "action", f"What should be done to the {KINDS[kind][0]}?", dict(labels)
            ),
            # Same question, options reversed. A real answer survives the
            # reorder; a guess (on vs off at 0.94, measured) tends not to.
            "action_check": self._choice(
                "action_check", f"What should be done to the {KINDS[kind][0]}?", dict(labels[::-1])
            ),
        }
        if len(candidates) > 1:
            questions["target"] = self._choice(
                "target",
                "Which device does the request mean?",
                {e.entity_id: self._entity_label(e) for e in candidates},
            )
        return questions

    def _entity_label(self, e: Entity) -> str:
        area = self.home.area(e.area_id)
        return _label(e.name, e.aliases, f" (in the {area.name})" if area else "")

    def finish(self, answers: dict[str, Any]) -> None:
        d = self.decision
        action = self._confident(answers, "action")
        if action is None:
            return
        check, _ = self._pick(answers, "action_check")
        d.trace.append(f"action_check={check}")
        if action not in self._actions or check != action:
            self._escalate(f"action {action} / {check}")
            return

        if len(self._candidates) == 1:
            target = self._candidates[0].entity_id
        else:
            target = self._confident(answers, "target")
            if target is None:
                return
            if target not in {e.entity_id for e in self._candidates}:
                self._escalate(f"target {target}")
                return
        d.entity_id = target
        d.domain = target.split(".", 1)[0]
        d.area_id = self.home.entity(target).area_id

        number = parse_number(self.original)
        if action in NUMBER_SLOTS:
            if number is None:
                self._escalate(f"{action} needs a number")
                return
            d.number = NUMBER_SLOTS[action][1](number)
        elif number is not None:
            # "dim to 20%" answered with "turn on": the number was not understood
            self._escalate(f"{action} takes no number, the text has {number:g}")
            return
        d.intent = action


def slots(decision: Decision, home: Home) -> dict[str, dict[str, Any]]:
    """Home Assistant intent slots for a non-escalated decision.

    Entities are addressed by name, as Assist does. The entity's own area is
    always sent with it: names are not unique (two "Hallway Light"s), the
    name+area pair usually is.
    """
    entity = home.entity(decision.entity_id)
    out: dict[str, Any] = {"name": entity.name, "domain": entity.domain}
    area = home.area(entity.area_id)
    if area:
        out["area"] = area.name
    if decision.intent in NUMBER_SLOTS and decision.number is not None:
        out[NUMBER_SLOTS[decision.intent][0]] = decision.number
    return {key: {"value": value} for key, value in out.items()}
