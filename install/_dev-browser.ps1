# Shared pinned-dev-browser helper. Dot-source from install.ps1 and install-grok.ps1.
# Requires $script:BundleRoot and Write-Info / Write-Ok / Write-Warn2.
#
# NEVER: npm install -g dev-browser@latest
# NEVER: dev-browser install-skill  (overwrites the harness skill x-harvest is written against)
# ALWAYS: copy payload/bin/dev-browser-windows-x64.exe over the npm package exe
# ALWAYS: `dev-browser install` for Playwright Chromium (x-harvest Stage 1)

function Ensure-PinnedDevBrowser {
    $dbSrc = Join-Path $script:BundleRoot 'payload\bin\dev-browser-windows-x64.exe'
    if (-not (Test-Path $dbSrc)) { throw "missing pinned dev-browser exe: $dbSrc" }

    $dbPkg = Join-Path $env:APPDATA 'npm\node_modules\dev-browser'
    $dbDst = Join-Path $dbPkg 'bin\dev-browser-windows-x64.exe'
    if (-not (Test-Path $dbPkg)) {
        Write-Info 'npm install -g dev-browser (shim only; exe is overwritten from payload)'
        npm install -g dev-browser --silent
    }
    $dbBin = Join-Path $dbPkg 'bin'
    if (-not (Test-Path $dbBin)) { New-Item -ItemType Directory -Path $dbBin -Force | Out-Null }
    Copy-Item $dbSrc $dbDst -Force
    Unblock-File $dbDst

    $dbVer = & dev-browser --version 2>&1 | Out-String
    if ($dbVer -notmatch 'ergo') {
        throw "dev-browser is not the pinned ergo build (got: $dbVer). Do not leave a stock npm binary in place."
    }
    Write-Ok ('dev-browser CLI: ' + $dbVer.Trim())

    Write-Info 'dev-browser install (Playwright Chromium; does NOT install-skill)'
    try {
        & dev-browser install
        Write-Ok 'dev-browser Chromium present'
    } catch {
        Write-Warn2 ('dev-browser install failed (' + $_ + ') - CLI is on PATH; Chromium may be missing until you re-run')
    }
}
