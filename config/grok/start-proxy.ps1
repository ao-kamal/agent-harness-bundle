# Spawns opencode-proxy.cjs detached via WMI if port 5210 is not listening.
$port = 5210
$conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if (-not $conn) {
    $proxyScript = Join-Path $env:USERPROFILE '.grok\opencode-proxy.cjs'
    if (Test-Path $proxyScript) {
        $nodeExe = (Get-Command node -ErrorAction SilentlyContinue).Source
        if (-not $nodeExe) { $nodeExe = "C:\Program Files\nodejs\node.exe" }
        Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
            CommandLine = "`"$nodeExe`" `"$proxyScript`""
        } | Out-Null
    }
}

# Auto-cancel stale blocked/interrupted workflows from past sessions to prevent turn-gate hangs
$reconcileScript = @"
const fs = require('fs'), path = require('path');
try {
  const actPath = path.join(process.env.USERPROFILE, '.grok', 'active_sessions.json');
  if (fs.existsSync(actPath)) {
    const acts = JSON.parse(fs.readFileSync(actPath, 'utf8'));
    for (const a of acts) {
      const dirs = [
        path.join(process.env.USERPROFILE, '.grok', 'sessions', a.cwd.replace(/:/g, '%3A').replace(/\\/g, '%5C'), a.session_id, 'workflows'),
        path.join(process.env.USERPROFILE, '.grok', 'sessions', encodeURIComponent(a.cwd).replace(/%/g, '%25'), a.session_id, 'workflows')
      ];
      for (const wfDir of dirs) {
        if (fs.existsSync(wfDir)) {
          for (const w of fs.readdirSync(wfDir)) {
            const sf = path.join(wfDir, w, 'state.json');
            if (fs.existsSync(sf)) {
              try {
                const d = JSON.parse(fs.readFileSync(sf, 'utf8'));
                if (d.state && (d.state.status === 'blocked' || d.state.status === 'interrupted')) {
                  d.state.status = 'cancelled';
                  delete d.state.pause_message;
                  d.state.history = d.state.history || [];
                  d.state.history.push({ event: 'workflow_cancelled', detail: 'startup_reconcile', at: new Date().toISOString() });
                  fs.writeFileSync(sf, JSON.stringify(d, null, 2));
                }
              } catch(e) {}
            }
          }
        }
      }
    }
  }
} catch(e) {}
"@
$nodeExe = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $nodeExe) { $nodeExe = "C:\Program Files\nodejs\node.exe" }
if ($nodeExe -and (Test-Path $nodeExe)) {
    & $nodeExe -e $reconcileScript 2>$null
}
