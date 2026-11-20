---
name: create-formal-verification-skill
description: Formally verify one property where a bug costs most and tests reach least, and generate a project-local skill to recheck it.
disable-model-invocation: true
---

[Shared workflow](WORKFLOW.md)

# Create a formal verification skill

A test checks the cases someone thought to write. Formal verification checks every case in a stated scope: every order of steps in a model, every input up to a bound, or every input. This skill finds the part of the repo where that matters most, verifies one property of it, and leaves a project-local skill at `<git-root>/.dev-skills/skills/verify-<area>/`, the folder where this project's personal skills live, so the next agent can check a change against that property. Write that skill for an agent who reads it cold, mid-change, and has never seen your work. The user must be able to trust the result and act on it without learning the verification language.

## Choose the target from the code

Answer from the codebase, and ask the user only what you cannot observe. If the user named an area or a bug, start there.

A good target is a promise the code makes, where a break harms users and tests rarely reach the case that breaks it: a race, a retry, a state machine, a parser, unsafe code. Choose the strongest such target in the repo, not the one that is easiest to verify.

## Let the question choose the tool

Pick the tool that answers the question at the lowest cost: a model checker, a proof assistant, an SMT-backed verifier, or another tool. Whether events can happen in a bad order usually suits a model checker over a small model of the design, and TLA+ is the default for that in any language. Whether the code itself behaves for every input, as with memory safety, overflow or a data-structure invariant, usually suits a verifier that runs on the code. If no verifier runs on this language, say so, and test the real code with generated inputs instead of a hand model of the function. A property that must hold at every size, where a bound is not enough, can need a proof.

Prefer a tool the repo's developers can install and run, and tell the user why you chose it. Name the install requirement and its package where one exists (the TLA+ tools are packaged as `tlaplus18` in nixpkgs), and ask the user to provide the tool rather than fetching it yourself.

## What makes it good

- **True to the code.** Every part of the model or proof points to code a reviewer can open. What the verification treats as one indivisible step is one indivisible step in the code. Names come from this repo.
- **Able to fail.** A check you have never seen fail proves nothing. Show each property failing on a broken variant of the code it guards, such as a removed check or a reordered step.
- **Findings stay findings.** When the current code breaks the property, report it with the counterexample in the code's terms. Keep the property and model as strict as the code's promise; change product code only when the user asks.
- **Honest about scope.** Say what is verified, under which bounds and assumptions, and what is left out. A pass covers the model or the bound, not the whole system.
- **Readable without the tool.** State the property and the harm in one plain sentence each. Show a counterexample as a numbered list of steps in the code's own words.
- **Cheap to rerun.** One command, a reproducible tool version, and a run short enough that the next agent uses it on every relevant change.
- **Kept in step with the code.** Record which files and functions each check covers, and the commit at which you last confirmed the verification describes them, so the next agent can see when the covered code changed.

## Show the state graph

When the check is a TLA+ model, show the person who owns the behavior how the system moves between states, with every state that breaks a rule marked. The TLA+ tools (`tlaplus18` in nixpkgs, which provides `tlc`) and `graphviz` are enough.

1. **Label states in the reader's words.** Write `Next` as a disjunction of named actions (`YouPressPlay \/ YouPressStop`), so each arrow carries a step name. Add an `ALIAS` to the config: a record whose fields describe the state the way the reader sees it ("Paying", "Lease held, write pending"), plus one field that names the rules the state breaks, such as `breaks |-> {r \in {"PaidOnce", "NoDoubleCharge"} : ~Holds(r)}`. Keep variable names out of labels.
2. **Dump the graph.** Run `tlc -continue -dump dot,actionlabels <out>/states -noGenerateSpecTE <Spec>.tla`. TLC writes `<out>/states.dot` with every reachable state, labelled by the `ALIAS`. With `-continue`, TLC reports "No error has been found" and exits 0 even when a rule broke: read the `Error: Invariant` lines in its output instead.
3. **Get each counterexample.** Run TLC once per broken rule without `-continue`, with a config that lists only that rule. It stops at the first violation, exits 12, and prints the path in `ALIAS` words with the action names. Write that path as numbered steps in the reader's words.
4. **Convert to Mermaid.** Rewrite `states.dot` as a Mermaid `stateDiagram-v2`: one state per node, labelled with its reader-facing `ALIAS` text, one arrow per edge, labelled with its action name in the words a user would say ("you press play"). Mark each state whose `breaks` field is not empty, and name the rules in a note beside it. TLC marks initial states with `style=filled`; start the diagram from them.
5. **Keep it readable.** Aim for about 20 arrows. When the graph is larger, coarsen the `ALIAS` so states that behave the same share one label, and rerun step 2. Keep every state on a counterexample path and every mark. If it is still too large, show only the counterexample paths and say that the full graph was omitted. `dot -Tsvg <out>/states.dot -o <out>/states.svg` renders the uncoarsened graph when the user wants it.

Put the model, configs and outputs in the verify skill's folder, and give the user the Mermaid chart, the counterexample steps, and the command that regenerates both.

## Generate the verify skill

Write the project-local skill with frontmatter that names the area and says when to use it; without frontmatter the skill never registers. From the skill alone, the next agent must be able to tell whether a change touches the verified code, run the check, tell a real bug from a modeling error, and update the verification when a change is intended. Put the coverage record and the sync commit in the skill, and tell the next agent to move the sync commit forward only after confirming the verification describes the code at the new commit. Use this repo's real commands, paths and nouns, and leave no placeholders. Keep model files and harnesses inside the skill folder. For a TLA+ model, include the state graph steps above so the next agent can regenerate the chart.

## Prove it before you hand off

Follow the generated skill once, as the next agent would, on a scratch change that breaks the property in the real code. It must catch the break. Then drop the scratch change and confirm the check is back where it started: passing, or failing only on the findings you will report. A verify skill that was never run is a draft. If the skill misses the break or a step does not run, fix the skill or the verification, not the scratch change.

## Hand off

Tell the user what you verified, which tool you used and why, the bounds, what the check found in plain words, how to run it, and what it does not cover. Suggest a second target only if you found a close one. Point the user at the `maintain-formal-verification-skill` skill for bringing the verification back in line after changes that did not recheck it.
