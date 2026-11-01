# Field Guide 08 - Claude Code auth profiles

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

`config/settings/settings.fragment.json` (v3) routes Claude Code through
OpenCode Console onto an OpenCode **Go** subscription - the flat-rate model
plan - with no Anthropic account and no Anthropic credential:

```json
"ANTHROPIC_BASE_URL": "https://opencode.ai/inference/go/anthropic",
"ANTHROPIC_AUTH_TOKEN": "oc_sk_...",        â† real key, provisioned in Stage 6
"ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-5.3",
"ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5.3-flash",
"ANTHROPIC_DEFAULT_HAIKU_MODEL": "mimo-v2.6-flash",
"model": "glm-5.3-flash",
"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
```

The base URL is the one OpenCode's own harness documentation prescribes for a
Go subscription (`opencode.ai/v2/docs/console/harnesses/claude-code`). The
non-Go paid route is `https://opencode.ai/inference/anthropic` (pay per
token); both accept any Console model, and Console translates wire formats for
models that do not speak Anthropic Messages natively.

The default is carried by the three alias slots, not by an `ANTHROPIC_MODEL`
hard pin. Sonnet is the daily driver slot, Opus the deep-work slot, Haiku the
slot Claude Code also uses for background tasks. `/model` still switches
freely at runtime, and picking a model there saves it as the `model` default -
which is why the fragment ships `"model": "glm-5.3-flash"` outside
`overrideKeys`: the bundle sets the first default and never overwrites the
user's later pick on update runs.

The provisioned key is a personal OpenCode Console API key (`oc_sk_...`,
created under https://opencode.ai/console). Stage 6 (`install/opencode-key-setup.ps1`)
asks for it, writes it into the live `settings.json`, and verifies it against
the Console models endpoint - a GET that spends no tokens, unlike an inference
call. The key never enters the bundle repository.

The key's canonical copy is machine-local: `%USERPROFILE%\.config\opencode\key`,
one plain-text line. Rotation is one command - `install\opencode-key-setup.ps1 -Sync`
verifies the key first (a failing verification writes nothing at all), then
patches only `env.ANTHROPIC_AUTH_TOKEN` in Windows `~/.claude/settings.json`
and WSL `/root/.claude/settings.json`, rewriting nothing else in either file.
The WSL lane is skipped with a printed reason when its settings file is absent
rather than half-created. First-time provisioning (the Stage 6 prompt) stores
the canonical copy as part of writing the key; after that, rotating means
replacing one line in that file and running `-Sync`. Never pass a key on a
command line: the script takes it from the canonical file or an interactive
prompt, and the WSL patch receives it on stdin.

## The traps, each of which cost real time

**The base URL must not end in `/v1`.** Claude Code appends `/v1/messages`
itself. A base that already carries `/v1` produces a doubled path and a 404
HTML page that surfaces as `There's an issue with the selected model`. Run
`claude --debug` and read the request path before touching anything else.

**The carrier is `ANTHROPIC_AUTH_TOKEN`, and on Go it must be a real key.**
Console validates the `Authorization` bearer. Fragment v2 shipped a
placeholder because the Zen free route demanded no credential at all; the Go
route does, and the placeholder now fails with a 400/401. `ANTHROPIC_API_KEY`
(x-api-key) must stay absent. `install/opencode-key-setup.ps1` provisions the real
key. If a claude.ai login exists on the machine, run `/logout` first so that
OAuth identity is never sent to the gateway.

**No `ANTHROPIC_MODEL` hard pin.** Fragment v2 pinned the model; that makes
every `/model` pick inert in new sessions. v3 removed the pin, and the merge
now deletes `env.ANTHROPIC_MODEL` and the retired discovery flag from live
settings on version bump via the fragment's `deleteKeys` list - the same
version gate that `apply_overrides` uses, because the merge can only overwrite
keys that still exist in the fragment, never delete.

**A model outside the catalog needs `behavesAs`.** Without it every invocation
prints `[claude-code:unrecognized_model]` to stderr - a warning, not a
failure, but error-shaped output any harness capturing stderr will flag. Every
`modelPicker` row ships `behavesAs` pointing at a built-in model the running
Claude Code version knows, and v3 makes its absence a smoke-test failure
instead of a skip. `behavesAs` needs v2.1.257+, `modelPicker` v2.1.242+, and
`modelPicker` is read from user or managed settings only, so a cloned
repository cannot relabel the picker.

**Do not ship a 1M-context assumption.** The gateway rejects boxed model IDs
(`glm-5.3-flash[1m]` measured 400 `Model is unavailable`), and newer Claude
Code versions send that suffix when `CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000`
is forced globally - the previous fragment did not ship the override, and v3
keeps it out. A laptop that wants a bigger assumed window sets it locally,
per machine, after checking the model's real limit.

## Reverting to a Claude.ai or Console login

Delete the gateway keys from `~/.claude/settings.json` - `env.ANTHROPIC_*`,
the alias slots, `model`, and `modelPicker` - and re-run the installer. It
will detect the absence of `ANTHROPIC_BASE_URL` and fall back to prompting for
the browser login. A fresh `install.ps1 -Update` after reverting the live file
re-ships the gateway profile, because the fragment version gate still sees an
older stored version; delete or bump `_hbFragmentVersion` if reverting for
good.
