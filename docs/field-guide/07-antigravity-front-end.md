# 07 — Antigravity as a front end

Antigravity CLI (`agy`) is Google's terminal agent. It replaced consumer Gemini CLI on 18 June 2026. ntm already has `--agy`. This chapter is only how it sits on the **same** brain as Claude and Grok.

Read 01–05 and `config/rules/harness-shared.md` first.

## What changes, what does not

Does **not** change: planning loop, `~/.claude/` skills/rules, flywheel, WSL hybrid.

Does change:

- You run `agy`, not `gemini`
- Antigravity has no `compat.claude` flag. The adapter is junctions (skills + rules + agents) onto `~/.claude`
- ntm worker flag is `--agy=N:<model-id>`. Always pass the id. Bare `--agy=N` pins Gemini 3.7 Flash High. `--gmi` is leftover Gemini CLI
- Do **not** put agy behind CLIProxy (account-ban risk). The WSL shim `/usr/local/bin/agy` execs the Windows `agy.exe` so Google OAuth stays on the Windows account

## Where it looks

| Thing | Canonical | Adapter |
|-------|-----------|---------|
| Skills | `~/.claude/skills/` | junction `~/.gemini/antigravity-cli/skills` |
| Rules | `~/.claude/rules/` | junction `~/.gemini/antigravity-cli/rules` |
| Keybindings | `config/antigravity/keybindings.json` | copied `~/.gemini/antigravity-cli/keybindings.json` |
| Project contract | repo `AGENTS.md` | none |
| Auth / TUI | Antigravity keyring / first `agy` login | none |

Do not copy the skills tree. If you already have a real folder at `~/.gemini/antigravity-cli/skills`, move it aside and re-run `install\install-antigravity.ps1`.

## Keybindings & Voice Dictation (Wispr Flow)

Voice dictation (Wispr Flow) and clipboard paste in `agy` on Windows encounter two distinct layers:

1. **`edit.paste` key interception:** By default, `agy.exe` binds `ctrl+v` to `edit.paste` (`KeyPaste`), which routes to `handlePasteMedia` (iTerm2 image upload). On non-iTerm2 Windows terminals (WezTerm, Windows Terminal), this handler errors out and swallows `ctrl+v`. Deploying `keybindings.json` moves `edit.paste` to `alt+v` so `ctrl+v` is not swallowed.
2. **Bracketed paste drop:** Bubbletea's renderer in `agy` sends `\x1b[?2004h` (Bracketed Paste Mode). However, `PromptModel.Update` in `agy.exe` only handles `*tea.KeyMsg` and completely drops `tea.PasteMsg`. When terminal emulators (like WezTerm) paste clipboard text wrapped in `\x1b[200~...\x1b[201~`, `agy` silently drops the entire paste!
3. **Unbracketed stream solution:** `agy` includes built-in `PromptModel.absorbUnbracketedPasteNewline` specifically designed to handle raw character streams. WezTerm's `paste_unbracketed` callback uses `getclip.exe` (a 4.5KB C# P/Invoke helper in `~/.local/agy/bin`) and `pane:send_text(stdout)` to stream clipboard text directly as runes. This makes Wispr Flow, `Ctrl+V`, `Shift+Insert`, and right-click paste work seamlessly across `agy`, Grok CLI, PowerShell, and WSL.

## Commands

| Gemini CLI (legacy) | Antigravity |
|---------------------|-------------|
| `gemini` | `agy` |
| ntm `--gmi` | ntm `--agy=N:<model-id>` |
| `~/.gemini/settings.json` | `~/.gemini/antigravity-cli/settings.json` |

List live ids with `agy models` before spawn. Common ids: `gemini-3.7-flash-high`, `gemini-3.1-pro-high`, `claude-sonnet-4-6`, `claude-opus-4-6-thinking`, `gpt-oss-120b-medium`.
