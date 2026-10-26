# UI Prototype

Generate **several radically different UI variations** on a single route, switchable from a floating bottom bar. The user flips between variants in the browser, picks one (or steals bits from each), then throws the rest away.

If the question is about logic/state rather than what something looks like, this is the wrong branch. Use [LOGIC.md](LOGIC.md).

## When this is the right shape

- "What should this page look like?"
- "I want to see a few options for this dashboard before committing."
- "Try a different layout for the settings screen."
- Any time the user would otherwise spend a day picking between three vague mockups in their head.

## Two isolated preview shapes: prefer A when feasible

Both shapes live entirely under `<absolute-workspace>/prototypes/<slug>/`. Neither changes production routes or tracked application source. Reuse existing tools and components only where an isolated preview can consume them without changing their production wiring. Keep dependency installation, caches, and build output in the prototype directory.

### Sub-shape A: isolated preview of an existing page (preferred)

Preview the existing page’s context: header, sidebar, representative read-only data, and density. Render variations on the same **preview** route using `?variant=`. Consume real project components and read-only data where feasible. Preserve the intended host-page layout without modifying the actual host page or assuming production authentication is exercised.

### Sub-shape B: standalone preview (when integration is unavailable)

Create a clearly marked local preview with the same `?variant=` pattern and floating switcher. Explain which app components, data, authentication, and routing it does not exercise. Do not claim that a standalone page validates the real application integration.

Before choosing B, consider whether existing components can be consumed by an isolated preview. Do not edit production code merely to force A.

In both shapes the floating bottom bar is identical.

## Process

### 1. State the question and pick N

Default to **3 variants**. More than 5 stops being radically different and starts being noise, so cap there.

Write down the plan in one line, in the prototype's location or a top-of-file comment:

> "Three variants of the settings page, switchable via `?variant=`, on an isolated preview of `/settings`, not the production route."

This works whether the user is here to push back or not.

### 2. Generate radically different variants

Draft each variant. Hold each one to:

- The page's purpose and the data it has access to.
- The project's component library / styling system (TailwindCSS, shadcn, MUI, plain CSS, whatever).
- A clear exported component name, e.g. `VariantA`, `VariantB`, `VariantC`.

Variants must be **structurally different**: different layout, different information hierarchy, different primary affordance, not just different colours. Three slightly-tweaked card grids isn't a UI prototype, it's wallpaper. If two drafts come out too similar, redo one with explicit "do not use a card grid" guidance.

### 3. Wire them together

Create a single switcher component on the isolated preview route:

```tsx
// pseudo-code, adapt to the project's framework
const variant = searchParams.get('variant') ?? 'A';
return (
  <>
    {variant === 'A' && <VariantA {...data} />}
    {variant === 'B' && <VariantB {...data} />}
    {variant === 'C' && <VariantC {...data} />}
    <PrototypeSwitcher variants={['A','B','C']} current={variant} />
  </>
);
```

For sub-shape A (existing-page preview): keep available read-only data loading above the switcher within the preview. State any differences from production data or auth.

For sub-shape B (standalone preview): the local preview route mounts the same switcher. All route source stays in the workspace prototype directory.

### 4. Build the floating switcher

A small fixed-position bar at the bottom-centre of the screen with three pieces:

- **Left arrow**: cycles to the previous variant (wraps around).
- **Variant label**: shows the current variant key and, if the variant exports a name, that name too. e.g. `B (Sidebar layout)`.
- **Right arrow**: cycles forward (wraps around).

Behaviour:

- Clicking an arrow updates the URL search param (use the framework's router, e.g. `router.replace` on Next, `navigate` on React Router, etc) so the variant is shareable and reload-stable.
- Keyboard: `←` and `→` arrow keys also cycle. Don't intercept arrow keys when an `<input>`, `<textarea>`, or `[contenteditable]` is focused.
- Visually distinct from the page (e.g. high-contrast pill, subtle shadow) so it's obviously not part of the design being evaluated.
- Hidden in production builds: gate on `process.env.NODE_ENV !== 'production'` or an equivalent check, so a stray prototype merge can't ship the bar to users.

Put the switcher in a single shared component so both sub-shapes can reuse it. Locate it inside this prototype directory, not the project’s production shared UI.

### 5. Hand it over

Surface the URL (and the `?variant=` keys). The user will flip through whenever they get to it. The interesting feedback is usually **"I want the header from B with the sidebar from C"**, which is the actual design they want.

### 6. Capture the answer and clean up

Once a variant has won, record which variant and why in `<absolute-workspace>/prototypes/<slug>/result.md`. Retain all variants and the switcher beside it as the primary source; no branch capture or production edit is part of this workflow.

- **Sub-shape A**: record how the winner would fit the existing page, including integration limits.
- **Sub-shape B**: record the intended production placement and what the standalone preview could not exercise.

Only separately requested and approved production implementation may promote the winning design, with normal tests, error handling, and review. Do not leave experimental variants or switchers in tracked application code.

## Anti-patterns

- **Variants that differ only in colour or copy.** That's a tweak, not a prototype. Real variants disagree about structure.
- **Sharing too much code between variants.** A shared `<Header>` is fine; a shared `<Layout>` defeats the point. Each variant should be free to throw out the layout.
- **Wiring variants to real mutations.** Read-only prototypes are fine. If a variant needs to mutate, point it at a stub: the question is "what should this look like", not "does the backend work".
- **Promoting the prototype directly to production.** The variant code was written under prototype constraints (no tests, minimal error handling). Rewrite it properly when you fold it in.
