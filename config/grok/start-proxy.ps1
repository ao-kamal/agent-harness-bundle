# Spawns opencode-proxy.cjs detached via WMI if port 5210 is not listening.
$port = 5210
$conn = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
if (-not $conn) {
    $proxyScript = Join-Path $env:USERPROFILE '.grok\opencode-proxy.cjs'
    if (Test-Path $proxyScript) {
        Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
            CommandLine = "node `"$proxyScript`""
        } | Out-Null
    }
}
