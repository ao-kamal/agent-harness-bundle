$env:ANTHROPIC_BASE_URL = 'https://api.kimi.com/coding/'
$env:ANTHROPIC_AUTH_TOKEN = (Get-Content -Raw ($env:USERPROFILE + '/.config/kimi/key')).Trim()
$env:ANTHROPIC_MODEL = 'kimi-for-coding'
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = 'kimi-for-coding'
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = 'kimi-for-coding'
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = 'kimi-for-coding'
$env:ANTHROPIC_SMALL_FAST_MODEL = 'kimi-for-coding'
$env:CLAUDE_CODE_SUBAGENT_MODEL = 'kimi-for-coding'
$env:CLAUDE_CODE_AUTO_COMPACT_WINDOW = '262144'
Write-Host 'Kimi env active in this tab -> api.kimi.com/coding (model kimi-for-coding).' -ForegroundColor Cyan
Write-Host 'Run:  claude    |  resume:  claude -c   or   claude --resume' -ForegroundColor Cyan
