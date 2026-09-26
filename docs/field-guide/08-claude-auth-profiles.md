# Field Guide 08 — Claude Code auth profiles

Claude Code reaches a model one of two ways, and the bundle supports both. The
installer and the smoke test detect which one is in play from
`~/.claude/settings.json` and branch accordingly, because the two differ in
which files exist at all.

| | `claude-login` | `gateway` |
|---|---|---|
| Credential | browser login | env/config in `settings.json` |
| `~/.claude/.credentials.json` | present | **absent by design** |
| `~/.claude.json` `oauthAccount` | present | absent |
| Verified by | credentials file exists | **the model answers a probe** |
| Credentials symlink watcher | required | inert, skipped |

Asserting OAuth identity on a gateway install fails even when Claude Code is
working perfectly, because a gateway writes neither file. That mismatch is why
`smoke-test.sh` branches on `AUTH_MODE` rather than asserting one shape.

## The gateway profile shipped here

`config/settings/settings.fragment.json` ships a working profile that routes
Claude Code through OpenCode Zen onto a free model, with no Anthropic account
and no Anthropic credential:

```json
"ANTHROPIC_BASE_URL": "https://opencode.ai/zen",
"ANTHROPIC_AUTH_TOKEN": "zen-placeholder-bearer-ignored-by-gateway",
"ANTHROPIC_MODEL": "space-bunny-free",
"CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1",
"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
```

## Four traps, each of which cost real time

**The base URL must not end in `/v1`.** Claude Code appends `/v1/messages`
itself, exactly as the vendor's own verification curl shows
(`curl "$ANTHROPIC_BASE_URL/v1/messages"`). A base of `.../zen/v1` produces
`[API REQUEST] /zen/v1/v1/messages`, which the gateway answers with a 404 HTML
page from its own website. The visible symptom is
`There's an issue with the selected model`, which sends you hunting through the
model configuration when the fault is in the URL. Run `claude --debug` and read
the request path before touching anything else.

**`ANTHROPIC_AUTH_TOKEN`, not `ANTHROPIC_API_KEY`, and the token is not a
credential.** Zen validates the `x-api-key` header and ignores `Authorization`
entirely. Measured: no auth header returns 200; `Authorization: Bearer
sk-invalid` returns 200; `x-api-key: sk-invalid` returns 401 `AuthError`.
`ANTHROPIC_AUTH_TOKEN` maps to `Authorization: Bearer`, so it satisfies Claude
Code's own "is a credential active" gate while sending Zen a header it
disregards. The value is a placeholder and is named as one.

**`ANTHROPIC_MODEL` must be set.** Unset, Claude Code falls back to its built-in
default, which is a paid model, and the gateway answers `401 Missing API key` —
a different failure from the 404 above, pointing at auth rather than routing.

**A model outside the catalog needs `behavesAs`.** Without it every invocation
prints `[claude-code:unrecognized_model]` to stderr. It is a warning, not a
failure — the turn still returns `exit 0` with the right answer — but it is
error-shaped output, so any harness capturing stderr sees a spurious error. The
`modelPicker` row fixes it properly:

```json
"modelPicker": {
  "options": [
    { "model": "space-bunny-free", "label": "Space Bunny (free)",
      "description": "OpenCode Zen free stealth model, routed through the gateway",
      "behavesAs": "claude-opus-4-8" }
  ]
}
```

`behavesAs` needs v2.1.257+. Claude Code then applies that known model's
capabilities and effort defaults while still sending `space-bunny-free` in
requests. `modelPicker` is read from user or managed settings only, so a cloned
repository cannot relabel the picker.

## Reverting to a Claude.ai or Console login

Delete these six keys from `~/.claude/settings.json` — five in `env`, plus
`modelPicker` — and re-run the installer. It will detect the absence of
`ANTHROPIC_BASE_URL` and fall back to prompting for the browser login.

## The placeholder is free-models-only

The placeholder works because free models need no credential. A paid route
through the same gateway would still require a real key, and that was left
untested rather than spending credits to find out. Do not assume the placeholder
grants paid access.
