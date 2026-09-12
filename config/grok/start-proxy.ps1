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
