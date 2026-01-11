# Frontend spec (Flutter UI) — how Claude/Cursor should build UI in this repo

This repo already has a simple design system foundation:

- Theme + typography + component theming: `lib/app/theme.dart`
- Standard screen layout (safe area, max width, consistent padding): `lib/ui/app_scaffold.dart`
- Spacing scale helpers: `lib/ui/spacing.dart` (`AppSpace`, `Gap`)
- Shared components: `lib/ui/components/`

Use these consistently so the app feels coherent across screens.

---

## Core principles

### 1) Build on Material 3 + existing theme

- Use `Theme.of(context).colorScheme` and `textTheme` (don’t hardcode colors unless you’re matching the existing theme implementation).
- Prefer `Card`, `FilledButton`, `OutlinedButton`, `SegmentedButton`, `TextField` etc. and let `ThemeData` style them.
- Keep surfaces calm: use `Card`/theme surfaces rather than heavy gradients/shadows.

### 2) Layout rhythm is non-negotiable

- Use `AppScaffold` for full screens unless there’s a strong reason not to.
- Use `AppSpace` and `Gap` for padding/gaps; avoid random values.
- Keep content readable on large screens by respecting the max width pattern in `AppScaffold`.

### 3) Accessibility and UX quality

- Touch targets: aim for >= 44x44 logical pixels.
- Contrast: don’t rely on low-opacity text over colored surfaces.
- Empty states: include a clear “what is this + what to do next” message (see `lib/ui/components/empty_state_card.dart`).
- Errors: show inline errors near the control and also use a `SnackBar` for action failures when appropriate.

### 4) Component boundaries

- If a widget is reused, move it into `lib/ui/components/`.
- Keep components “dumb” when possible (data in, callbacks out).
- Keep formatting decisions close to UI; keep business logic in feature/data layers.

---

## Implementation preferences (house style)

### Screen structure

- Screen files live under `lib/features/<feature>/...`.
- Screens should generally return:
  - `AppScaffold(title: ..., children: [...])`
  - Each section separated by `Gap.h12`/`Gap.h16` and a header (see `lib/ui/components/section_header.dart`).

### Copy and tone

- Default tone: short, direct, calm.
- Prefer “Do X” over “Please do X”.
- Use labels that match the domain language in `agentPrompt.md` (Must‑Win, Nice‑to‑Do, Habits, Reflection, Rollups).

### When adding new UI elements

- Prefer: add one small component + use it in the screen.
- Avoid: big screens with deeply nested widgets and duplicated styling.

---

## “Anthropic frontend spec” note (provenance)

Anthropic doesn’t publish a single canonical “personal spec” for Claude’s frontend output that you can rely on as an official artifact. You *can* copy any external prompt/skill you trust into this repo (e.g., as `docs/FRONTEND_SPEC_SOURCE.md`) and adapt it, but the source should be reviewed like any third-party dependency.


