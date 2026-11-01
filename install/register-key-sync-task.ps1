# register-key-sync-task.ps1 - wires opencode-key-setup.ps1 -Sync -Auto
# into a scheduled task so key rotation propagates unattended.
#
# Trigger set: at logon, plus a 5-minute repetition - because the sync
# only does real work when OpenCode's login store actually carries a
# different active key than the cache, a tick costs one read-only sqlite
# peek and exits alone. No resident process: this mirrors the bundle's
# own Cass Watch Daemon registration shape (hidden wscript VBS launcher,
# AtLogOn trigger) without a forever-running watcher for a monthly event.
#
# Uninstaller pairing: uninstall.ps1 removes 'OpenCode Key Sync' and the
# launcher VBS it registered.

$ErrorActionPreference = 'Stop'

$TaskName = 'OpenCode Key Sync'
$SetupScript = Join-Path $PSScriptRoot 'opencode-key-setup.ps1'
$VbsPath = Join-Path $env:USERPROFILE '.local\bin\opencode-key-sync-hidden.vbs'

if (-not (Test-Path $SetupScript)) {
    Write-Host "Expected $SetupScript next to this script - not found." -ForegroundColor Red
    exit 1
}

$binDir = Split-Path $VbsPath -Parent
if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Path $binDir -Force | Out-Null }

# Hidden launcher: wscript keeps the powershell window invisible at logon
# and on every tick. Double quotes inside the VBS string are doubled, the
# same way the bundle's cass-watch-hidden.vbs is built.
$vbs = @"
CreateObject("Wscript.Shell").Run "powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File ""$SetupScript"" -Sync -Auto", 0, False
"@
[System.IO.File]::WriteAllText($VbsPath, $vbs, (New-Object System.Text.UTF8Encoding($false)))

$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$VbsPath`""
$logon = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$repeat = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($logon, $repeat) -Force | Out-Null
Write-Host "Registered '$TaskName': at logon + every 5 minutes, launcher $VbsPath, runs $SetupScript -Sync -Auto." -ForegroundColor Green
