---
name: unslop
description: 'Use when writing or editing prose that outlives the chat: docs, PR and commit bodies, code comments, issues, tickets, or messages to third parties.'
---

# Unslop

Edit text to remove AI patterns. Scan for the patterns below, then rewrite. Preserve meaning and match the intended tone.

These rules remove AI tells from chat and saved prose alike. Caveman, always loaded, sets the voice and owns the rules on ceremony, filler, hedging, sentence length and plain words; this list holds only what it does not cover.

## Patterns to detect and fix

### Content

1. **Superficial -ing phrases.** "highlighting...", "ensuring...", "reflecting...", "showcasing...", "fostering...". Delete or expand with real sources.
1. **Vague attributions.** "Experts believe", "Industry reports suggest", "Some critics argue". Name the source or delete.

### Language

1. **AI vocabulary.** Additionally, crucial, delve, enduring, enhance, fostering, garner, interplay, intricate, landscape (abstract), pivotal, showcase, tapestry (abstract), testament, underscore, vibrant. Replace with plain words.
1. **Fancy ways to say "is".** "serves as", "stands as", "boasts", "features". Say "is" or "has".
1. **"Not just X, but Y."** State the point directly instead.
1. **Rule of three.** Don't force ideas into groups of three. Use the natural number.
1. **Synonym cycling.** Protagonist, main character, central figure, hero all in one paragraph. Pick one, repeat it.
1. **False ranges.** "from X to Y" where X and Y aren't on a meaningful scale. List topics directly.

### Style

1. **Em dash overuse.** Avoid em dashes entirely. Use periods or commas only (no parentheses, no en dashes, no hyphen-as-dash substitutes). If a thought needs separation, end the sentence or use a comma.
1. **Colon overuse.** Colons are fine before a list or example, not as mid-sentence connectors. "If you're coming from traditional automation: instead of registering event handlers, you describe conditions" adds nothing with the colon. Rewrite to let the point stand on its own without comparison framing. "Describing when the scheduler should fire works best as plain English." Same meaning, no crutch punctuation.
1. **Boldface overuse.** Don't bold every proper noun or acronym.
1. **Inline-header lists.** The tell is a bold label and colon that restates the line: "**Performance:** Performance improved...". Convert those to prose. A bold lead-in that ends in a period, names the item, and is followed by genuinely new detail ("**Schema in TypeScript.** Tables live in one file.") is fine, not a tell.
1. **Title case headings.** Use sentence case.
1. **Decorative emojis.** Remove from headings and bullets.
1. **Curly quotes.** Use straight quotes.

### Filler

1. **Generic conclusions.** "The future looks bright." State specific plans or facts.

### Jargon

1. **Abstract metaphor nouns.** Substrate (base), wedge, wedge in (add), vector (way, method), locus, vantage, nexus, primitive as a noun, harness as a metaphor, surface as in "API surface", bedrock, scaffolding as a metaphor, modality, paradigm, gold-plating (more than the job needs), ratchet as a metaphor (the mechanism's real name, or a limit that only tightens), evacuate for moving code (move out), endgame (the last phase), north star, flywheel. These read as technical but usually have a plainer concrete word. Pick the concrete word.

### Plain speech

1. **Say what it does, not how it feels.** "the database stays close at hand", "SQL you can read", "types that follow your schema" name a feeling. The fix names the mechanism or a number: "`.toSQL()` returns the exact string sent to the database", "a column rename fails the build". Ask what the sentence tells the reader to do or know, then write that. If you can't restate it as a concrete instruction, fact, or number, cut it. One more check: if the sentence could appear unchanged in another project's docs, it says nothing about this one. Cut it.
1. **Active voice.** Prefer it. Catch "is/are/was/were + past participle" and name the actor: "queries are validated" becomes "the compiler validates queries", "the file is parsed by the loader" becomes "the loader parses the file". Passive is fine only when the actor is unknown or genuinely doesn't matter.
1. **Cut adverbs, or use a stronger verb.** "runs quickly" becomes "is fast" or the number, and "significantly improves" becomes the measured delta. An adverb propping up a weak verb means the verb is wrong.
1. **Mannered prose.** Metaphor or flourish where a literal phrase exists: aphorisms ("wire it or delete it"), rhetorical fragments for effect, personified code ("the plan holds it"), figurative verbs ("rides along", "stands on"), stock framing phrases. "A dial worth turning" becomes "a parameter worth varying". Say what you mean. Rule 17 covers the metaphor nouns.
