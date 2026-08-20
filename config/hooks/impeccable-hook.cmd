@echo off
setlocal
REM Impeccable PostToolUse/Stop wrapper. Grok on Windows runs hooks in PowerShell,
REM so bash `[ ! -f ... ] || node` fails with "At line:1 char:2".
REM Always exit 0 if the script is missing.
if defined CLAUDE_PROJECT_DIR if exist "%CLAUDE_PROJECT_DIR%\.claude\skills\impeccable\scripts\hook.mjs" (
  node "%CLAUDE_PROJECT_DIR%\.claude\skills\impeccable\scripts\hook.mjs"
  exit /b 0
)
if exist "%USERPROFILE%\.claude\skills\impeccable\scripts\hook.mjs" (
  node "%USERPROFILE%\.claude\skills\impeccable\scripts\hook.mjs"
  exit /b 0
)
exit /b 0
