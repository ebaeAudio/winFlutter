# AI Commands / Assistant — Setup

This repo supports an “AI Commands” assistant that translates typed input into a small **allowlisted** command list via a **Supabase Edge Function**, then executes those commands deterministically on the Today screen.

## What’s included

- **Edge Function**: `supabase/functions/assistant/index.ts`
  - Auth required (uses the caller’s JWT)
  - Optional Origin allowlist (`ASSISTANT_ALLOWED_ORIGINS`)
  - Per-user RPM limiting (`ASSISTANT_RPM`)
  - OpenAI translation when configured (`OPENAI_API_KEY`), otherwise heuristic fallback
- **Flutter**:
  - Assistant UI on Today
  - Deterministic executor (date context, safe matching, delete confirmation)
  - Local habits (so `habit.*` commands are visible and usable)

## Supabase CLI (local serve)

- **Command**:

```bash
supabase functions serve assistant --no-verify-jwt
```

- **What it does**: runs the edge function locally so the Flutter client can call it via `Supabase.instance.client.functions.invoke('assistant', ...)`.

> Note: In production you should verify JWTs. Locally, `--no-verify-jwt` is convenient during development.

## Deploy

- **Command**:

```bash
supabase functions deploy assistant
```

- **What it does**: deploys the `assistant` edge function to your Supabase project.

## Required function environment variables

Set these in Supabase (Function secrets / environment):

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Optional (recommended):

- `ASSISTANT_ALLOWED_ORIGINS`: comma-separated origin allowlist (ex: `https://app.example.com,http://localhost:5173`)
- `ASSISTANT_RPM`: per-user requests per minute (default `20`)
- `ASSISTANT_MAX_TRANSCRIPT_CHARS`: input limit (default `2000`)
- `ASSISTANT_OPENAI_TIMEOUT_MS`: OpenAI timeout (default `12000`)
- `ASSISTANT_DEBUG`: `true` to include a `debug` field in responses (never includes secrets)

To enable LLM translation:

- `OPENAI_API_KEY`
- `OPENAI_MODEL` (default `gpt-4o-mini`)

## Flutter configuration

Flutter uses `SUPABASE_URL` / `SUPABASE_ANON_KEY` from either:

- `assets/env` (git-ignored), or
- `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

When `DEMO_MODE=true`, the app stays local and the assistant uses the heuristic translator (no edge function calls).


