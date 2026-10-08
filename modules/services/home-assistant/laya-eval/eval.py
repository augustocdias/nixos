#!/usr/bin/env python3
"""Measure the Laya pipeline against a laya.serve endpoint, outside Home Assistant.

Runs the exact pipeline the HA component uses (`../laya/pipeline.py`) on the
utterances in cases.json, against a snapshot of your home (HOME.json). The
snapshot is not kept in the repo: dump it from HA into a temp file, shaped as

    {"entities": [{"entity_id", "name", "area_id", "aliases"}],
     "areas": [{"area_id", "name", "aliases"}], "registered_intents": [...]}

using exposed entities only, the state's name, and the area inherited from the
device when the entity has none (what the component itself reads).

    ./eval.py --selftest                                 # no server, no snapshot
    ./eval.py --home HOME.json --dry-run                 # prints round-1 questions
    ./eval.py --home HOME.json --url http://macmini.local:8000 [-v] [--only pt]

Outcomes per case:
    ok         acted exactly as expected, or escalated when it should
    escalated  handed to the fallback agent instead of acting (safe miss)
    WRONG      acted, but not as expected, or acted when it should escalate

WRONG is the number that matters: escalations cost latency, wrong actions
cost trust. Stdlib only, so it runs with any python3.
"""

from __future__ import annotations

import argparse
import json
import os
import statistics
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "laya"))

from const import HEAD_MAX_LEN, MODEL  # noqa: E402  (pure module, no HA imports)
from pipeline import Area, Entity, Home, Planner, slots, translation_source  # noqa: E402


def load_home(path: Path) -> Home:
    raw = json.loads(path.read_text())
    return Home(
        entities=tuple(
            Entity(e["entity_id"], e["name"], e.get("area_id"), tuple(e.get("aliases", ())))
            for e in raw["entities"]
        ),
        areas=tuple(
            Area(a["area_id"], a["name"], tuple(a.get("aliases", ()))) for a in raw["areas"]
        ),
        registered_intents=frozenset(raw["registered_intents"]),
    )


def make_predict(url: str, model: str = MODEL, head_max_len: int = HEAD_MAX_LEN):
    endpoint = url.rstrip("/") + "/v1/systemone"
    headers = {"Content-Type": "application/json"}

    def predict(text: str, questions: dict) -> dict:
        body = json.dumps(
            {"state": text, "questions": questions, "model": model, "head_max_len": head_max_len}
        ).encode()
        req = urllib.request.Request(endpoint, body, headers)
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return json.load(resp).get("answers") or {}
        except urllib.error.HTTPError as err:
            if err.code == 422:  # request does not fit the checkpoint: no answers -> escalates
                print(f"  422: {err.read().decode()[:160]}", file=sys.stderr)
                return {}
            sys.exit(f"HTTP {err.code} from {endpoint}: {err.read().decode()[:500]}")

    return predict


def make_translate(url: str):
    """Mirrors the component's Translator. `source` is the case's lang, as the
    pipeline (one per language) would send it; English is passed through."""
    endpoint = url.rstrip("/") + "/translate"

    def translate(text: str, source: str) -> str:
        if source == "en":
            return text
        body = json.dumps({"q": text, "source": source, "target": "en"}).encode()
        req = urllib.request.Request(endpoint, body, {"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.load(resp)
        return data.get("translatedText") or text

    return translate


def run(home: Home, text: str, predict, translate=None, lang: str = "en", **thresholds) -> Planner:
    english = translate(text, lang) if translate else text
    planner = Planner(home, english, original=text, **thresholds)
    round2 = planner.round2(predict(english, planner.round1()))
    if round2 is not None:
        planner.finish(predict(english, round2))
    return planner


def grade(case: dict, planner: Planner) -> str:
    d = planner.decision
    if case.get("escalate"):
        return "ok" if d.escalate else "WRONG"
    if d.escalate:
        return "escalated"
    if d.intent != case["intent"]:
        return "WRONG"
    if "number" in case and d.number != case["number"]:
        return "WRONG"
    if "entity" in case:
        wanted = case["entity"] if isinstance(case["entity"], list) else [case["entity"]]
        return "ok" if d.entity_id in wanted else "WRONG"
    return "WRONG"  # area-wide cases: acting on any single device is wrong


def describe(planner: Planner) -> str:
    d = planner.decision
    if d.escalate:
        return f"escalate: {d.escalate}"
    target = d.entity_id
    number = f" = {d.number}" if d.number is not None else ""
    return f"{d.intent} {target}{number}"


SELFTEST_HOME = Home(
    entities=tuple(
        Entity(i, n, a, tuple(al))
        for i, n, a, al in (
            ("light.kitchen_light", "Kitchen Light", "kitchen", ["luz da cozinha"]),
            ("light.kitchen_peninsula_lights", "Peninsula Lights", "kitchen", []),
            ("cover.kitchen_blinds_cover_0", "Kitchen Blinds", "kitchen", []),
            ("light.bedroom_light", "Bedroom Light", "bedroom", ["luz do quarto"]),
            ("cover.bedroom_blinds_cover_0", "Bedroom Blinds", "bedroom", ["persiana do quarto"]),
            ("cover.tobias_blinds_cover_0", "Tobias's Blinds", "tobias", ["persiana do quarto do Tobias"]),
            ("light.hallway_1_light", "Hallway Light", "hallway", []),
            ("light.stairs_light", "Hallway Light", "stairs", []),
            ("cover.office_blinds_cover_0", "Office Blinds", "office", []),
            ("light.tv_rack_light", "TV Rack Light", "living_room", []),
            ("vacuum.s7_max_ultra", "S7 Max Ultra", "living_room", []),
        )
    ),
    areas=tuple(
        Area(i, n, tuple(al))
        for i, n, al in (
            ("kitchen", "Kitchen", ["cozinha"]),
            ("bedroom", "Bedroom", ["quarto"]),
            ("tobias", "Tobias's Room", ["quarto do Tobias"]),
            ("hallway", "Hallway", []),
            ("stairs", "Stairs", ["escada"]),
            ("office", "Office", ["escritório"]),
            ("living_room", "Living Room", ["sala"]),
        )
    ),
    registered_intents=frozenset(
        {"HassTurnOn", "HassTurnOff", "HassLightSet", "HassSetPosition",
         "HassVacuumStart", "HassVacuumReturnToBase"}
    ),
)


def selftest(home: Home = SELFTEST_HOME) -> None:
    """Pipeline logic against canned answers; no server or snapshot involved."""

    def ans(choice: str, *others: str, p: float = 0.9) -> dict:
        others = [o for o in others if o != choice]
        rest = (1 - p) / max(len(others), 1)
        return {"choice": choice, "probabilities": {**{o: rest for o in others}, choice: p}}

    def round1(request="command", kind="light", compound=0.1):
        return {
            "request": ans(request, "question", "other"),
            "kind": ans(kind, "cover", "switch"),
            "compound": {"noul": compound},
        }

    def round2(action, target=None, check=None, *others):
        out = {"action": ans(action, "HassTurnOff", "HassTurnOn"),
               "action_check": ans(check or action, "HassTurnOff", "HassTurnOn")}
        if target:
            out["target"] = ans(target, *others)
        return out

    def as_texts(p, answers):
        """Canned answers name ids; the server answers with option texts."""
        out = {}
        for qid, a in answers.items():
            texts = {oid: t for t, oid in p._ids.get(qid, {}).items()}
            if "choice" in a:
                a = {"choice": texts.get(a["choice"], a["choice"]),
                     "probabilities": {texts.get(k, k): v for k, v in a["probabilities"].items()}}
            out[qid] = a
        return out

    def plan(text, r1, r2=None, original=None):
        p = Planner(home, text, original=original)
        p.round1()
        q2 = p.round2(as_texts(p, r1))
        if q2 is not None and r2 is not None:
            p.finish(as_texts(p, r2))
        return p, q2

    # a device alias pins the target: no target question, pt words irrelevant
    p, q2 = plan("liga a luz da cozinha", round1(), round2("HassTurnOn"))
    assert "target" not in q2, q2
    d = p.decision
    assert not d.escalate and d.entity_id == "light.kitchen_light", d
    assert slots(d, home) == {
        "name": {"value": "Kitchen Light"},
        "domain": {"value": "light"},
        "area": {"value": "Kitchen"},
    }

    # names are grounded in what was said, the model reads the translation:
    # "luz da sala" -> "the room light" still pins the living room light
    p, _ = plan("turn off the room light", round1(), round2("HassTurnOff"), original="desliga a luz da sala")
    assert p.decision.entity_id == "light.tv_rack_light", p.decision  # "sala" = living room, its only light
    p, _ = plan("turn off the ladder light", round1(), round2("HassTurnOff"), original="desliga a luz da escada")
    assert p.decision.entity_id == "light.stairs_light", p.decision
    # a name only the translation carries still counts when the original has none
    p, _ = plan("turn on the kitchen light", round1(), round2("HassTurnOn"), original="liga a lâmpada de cima da copa")
    assert p.decision.entity_id == "light.kitchen_light", p.decision

    # the longest name wins: "quarto do Tobias" is not the bedroom
    p, _ = plan("abre a persiana do quarto do Tobias", round1(kind="cover"), round2("HassTurnOn"))
    assert p.decision.entity_id == "cover.tobias_blinds_cover_0", p.decision
    p, _ = plan("open Tobias's blinds", round1(kind="cover"), round2("HassTurnOn"))
    assert p.decision.entity_id == "cover.tobias_blinds_cover_0", p.decision

    # covers speak their own verbs
    _, q2 = plan("close the kitchen blinds", round1(kind="cover"))
    assert q2["action"]["criteria"].keys() >= {"Close", "Open"}

    # duplicate names: the named room picks one; with no room named the model must
    p, q2 = plan("turn off the hallway light in the stairs", round1(), round2("HassTurnOff"))
    assert p.decision.entity_id == "light.stairs_light", p.decision
    p, q2 = plan("turn off the hallway light", round1(),
                 round2("HassTurnOff", "light.hallway_1_light", None, "light.stairs_light"))
    assert set(p._ids["target"].values()) == {"light.hallway_1_light", "light.stairs_light"}
    assert p.decision.entity_id == "light.hallway_1_light"
    assert slots(p.decision, home)["area"] == {"value": "Hallway"}

    # number read from the text, decimal comma; the action decides the slot
    p, _ = plan("coloca a persiana do escritório em 30,5%", round1(kind="cover"), round2("HassSetPosition"))
    assert p.decision.entity_id == "cover.office_blinds_cover_0" and p.decision.number == 30, p.decision
    assert slots(p.decision, home)["position"] == {"value": 30}

    # numbers must fit the action, both ways
    p, _ = plan("dim the TV rack light", round1(), round2("HassLightSet"))
    assert p.decision.escalate and "needs a number" in p.decision.escalate
    p, _ = plan("dim the TV rack light to 20%", round1(), round2("HassTurnOn"))
    assert p.decision.escalate and "takes no number" in p.decision.escalate

    # the reversed-order check must agree
    p, _ = plan("apaga a luz da cozinha", round1(), round2("HassTurnOn", check="HassTurnOff"))
    assert p.decision.escalate and "action" in p.decision.escalate

    # unnamed device: one of its kind in the named room passes, several escalate
    p, _ = plan("liga a luz da escada", round1(), round2("HassTurnOn"))
    assert p.decision.entity_id == "light.stairs_light", p.decision
    p, q2 = plan("turn on the light in the kitchen", round1())
    assert q2 is None and "none is named" in p.decision.escalate
    # ...or the only one in the house
    p, _ = plan("start the robot", round1(kind="vacuum"), round2("HassVacuumStart"))
    assert p.decision.entity_id == "vacuum.s7_max_ultra", p.decision

    # a device named in one room and a different room named: veto
    p, q2 = plan("turn on the kitchen light in the bedroom", round1())
    assert q2 is None and "another room" in p.decision.escalate

    # a named device settles the kind, whatever the model said
    p, _ = plan("turn on the kitchen light", round1(kind="cover"), round2("HassTurnOn"))
    assert p.decision.entity_id == "light.kitchen_light", p.decision

    # "all" is not handled: no named device and several candidates -> escalate
    p, q2 = plan("turn off all the lights", round1())
    assert q2 is None and p.decision.escalate

    # questions, chit-chat, compound requests and low confidence escalate
    for kwargs in ({"request": "question"}, {"request": "other"}, {"compound": 0.9}):
        p, q2 = plan("turn on the kitchen light", round1(**kwargs))
        assert q2 is None and p.decision.escalate, kwargs
    r1 = round1()
    r1["kind"] = ans("light", "cover", "switch", "lock", p=0.3)
    p, q2 = plan("turn on the light in the kitchen", r1)
    assert q2 is None and "low kind" in p.decision.escalate

    # the pipeline's language decides the translation source
    assert translation_source("pt-BR") == "pt" and translation_source("en") == "en"
    assert translation_source("*") is None and translation_source(None) is None

    print("selftest ok")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--url", default=os.environ.get("LAYA_URL", "http://macmini.local:8000"))
    ap.add_argument("--home", type=Path, help="snapshot of the home (see above); not needed for --selftest")
    ap.add_argument("--cases", type=Path, default=HERE / "cases.json")
    ap.add_argument("--only", help="run only cases of this lang (en/pt)")
    ap.add_argument("--translate", metavar="URL", help="LibreTranslate endpoint; non-English cases are translated first")
    ap.add_argument("--model", default=MODEL, help=f"checkpoint (default {MODEL}); the server must have it loaded")
    ap.add_argument("--head-max-len", type=int, default=HEAD_MAX_LEN, help="option budget; english needs <512")
    ap.add_argument("--confidence", type=float)
    ap.add_argument("--compound", type=float)
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("-v", "--verbose", action="store_true", help="print the decision trace")
    args = ap.parse_args()

    if args.selftest:
        selftest()
        return
    if not args.home:
        ap.error("--home is required")
    home = load_home(args.home)
    if args.dry_run:
        q = Planner(home, "").round1()
        print(json.dumps(q, indent=1, ensure_ascii=False))
        for qid, question in q.items():
            print(f"{qid}: {len(question.get('criteria', {})) or 'noul'} options", file=sys.stderr)
        return

    cases = [c for c in json.loads(args.cases.read_text()) if not args.only or c["lang"] == args.only]
    thresholds = {k: v for k, v in (("confidence", args.confidence), ("compound", args.compound)) if v is not None}
    predict = make_predict(args.url, args.model, args.head_max_len)
    translate = make_translate(args.translate) if args.translate else None

    tally: dict[str, dict[str, int]] = {}
    latencies: list[float] = []
    for case in cases:
        start = time.perf_counter()
        planner = run(home, case["text"], predict, translate, case["lang"], **thresholds)
        latencies.append((time.perf_counter() - start) * 1000)
        outcome = grade(case, planner)
        tally.setdefault(case["lang"], {}).setdefault(outcome, 0)
        tally[case["lang"]][outcome] += 1
        print(f"{outcome:9} {latencies[-1]:6.0f}ms  {case['text']!r:52} -> {describe(planner)}")
        if args.verbose or outcome == "WRONG":
            print(f"{'':18}trace: {'; '.join(planner.decision.trace)}")

    print()
    for lang, counts in sorted(tally.items()):
        total = sum(counts.values())
        print(
            f"{lang}: {counts.get('ok', 0)}/{total} ok, "
            f"{counts.get('escalated', 0)} escalated, {counts.get('WRONG', 0)} WRONG"
        )
    print(f"latency: median {statistics.median(latencies):.0f}ms, max {max(latencies):.0f}ms")


if __name__ == "__main__":
    main()
