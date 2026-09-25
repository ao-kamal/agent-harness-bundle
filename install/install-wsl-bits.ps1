# install-wsl-bits.ps1
#
# Install the WSL core from Microsoft's official GitHub release using BITS,
# then enable the Windows features and (optionally) install Ubuntu. The
# official asset digest is verified before msiexec runs. The calling process
# is kept awake for the duration; no reboot is forced.

[CmdletBinding()]
param(
    [string]$Version = '2.7.14',
    [switch]$InstallDistro
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if (-not ('HarnessAwake' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class HarnessAwake {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint flags);
}
'@
}

$script:Awake = $false
function Enter-InstallAwake {
    # ES_CONTINUOUS | ES_SYSTEM_REQUIRED: keep the system awake while the
    # synchronous BITS/DISM/MSI operations run, then restore the prior state.
    $ES_CONTINUOUS = [uint32]2147483648
    $ES_SYSTEM_REQUIRED = [uint32]1
    [HarnessAwake]::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED) | Out-Null
    $script:Awake = $true
}
function Exit-InstallAwake {
    if ($script:Awake) {
        $ES_CONTINUOUS = [uint32]2147483648
        [HarnessAwake]::SetThreadExecutionState($ES_CONTINUOUS) | Out-Null
        $script:Awake = $false
    }
}

function Invoke-DismFeature {
    param([string]$Name)
    Write-Host "Enabling Windows feature: $Name"
    $p = Start-Process -FilePath 'dism.exe' -ArgumentList @(
        '/online', '/enable-feature', "/featurename:$Name", '/all', '/norestart'
    ) -Wait -PassThru
    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) {
        throw "DISM failed for $Name (exit $($p.ExitCode))"
    }
    if ($p.ExitCode -eq 3010) {
        Write-Warning "$Name requires a Windows reboot before it can be used."
    }
}

try {
    Enter-InstallAwake
    Import-Module BitsTransfer -ErrorAction Stop

    $assetName = "wsl.$Version.0.x64.msi"
    $assetUrl = "https://github.com/microsoft/WSL/releases/download/$Version/$assetName"
    $expectedHash = 'db084e536279a59e90a26ec598d8aa8a4dff8309f41d078fd06242953ac1ebcd'
    $expectedSize = 258990080
    $tmpDir = Join-Path $env:TEMP 'harness-wsl-bits'
    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
    $msi = Join-Path $tmpDir $assetName

    $validExisting = $false
    if (Test-Path -LiteralPath $msi -PathType Leaf) {
        $item = Get-Item -LiteralPath $msi
        $hash = (Get-FileHash -LiteralPath $msi -Algorithm SHA256).Hash.ToLower()
        if ($item.Length -eq $expectedSize -and $hash -eq $expectedHash) {
            $validExisting = $true
            Write-Host "Existing BITS MSI is complete and verified: $msi"
        } else {
            Remove-Item -LiteralPath $msi -Force
        }
    }

    if (-not $validExisting) {
        Write-Host "Downloading $assetUrl with BITS (retrying transient resets)..."
        Start-BitsTransfer -Source $assetUrl -Destination $msi -RetryInterval 60 -RetryTimeout 600 -ErrorAction Stop
    }

    $item = Get-Item -LiteralPath $msi
    $hash = (Get-FileHash -LiteralPath $msi -Algorithm SHA256).Hash.ToLower()
    if ($item.Length -ne $expectedSize) { throw "WSL MSI size mismatch: got $($item.Length), expected $expectedSize" }
    if ($hash -ne $expectedHash) { throw "WSL MSI SHA256 mismatch: got $hash" }
    Write-Host "WSL MSI verified: $expectedHash"

    Invoke-DismFeature 'Microsoft-Windows-Subsystem-Linux'
    Invoke-DismFeature 'VirtualMachinePlatform'

    Write-Host 'Installing the verified WSL MSI (no forced reboot)...'
    $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', $msi, '/quiet', '/norestart') -Wait -PassThru
    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) {
        throw "WSL MSI installation failed (exit $($p.ExitCode))"
    }
    if ($p.ExitCode -eq 3010) { Write-Warning 'WSL MSI requested a reboot; none was forced.' }

    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if (-not $wsl) {
        Write-Warning 'wsl.exe is not available yet; a Windows reboot is required before continuing.'
        exit 0
    }
    $versionText = (& $wsl.Source --version 2>&1 | Out-String)
    $versionClean = ($versionText -replace "`0", '')
    Write-Host ('WSL CLI: ' + (($versionClean -split "`r?`n")[0]))
    if ($versionClean -notmatch '\d+\.\d+') {
        Write-Warning 'WSL features are not active until Windows is rebooted; no reboot was forced.'
        exit 0
    }

    if ($InstallDistro) {
        $help = (& $wsl.Source --help 2>&1 | Out-String)
        $helpClean = ($help -replace "`0", '')
        $distroArgs = @('--install', '-d', 'Ubuntu', '--no-launch')
        if ($helpClean -match '--web-download') { $distroArgs += '--web-download' }
        Write-Host ('Installing Ubuntu with: wsl.exe ' + ($distroArgs -join ' '))
        $d = Start-Process -FilePath $wsl.Source -ArgumentList $distroArgs -Wait -PassThru
        if ($d.ExitCode -ne 0 -and $d.ExitCode -ne 3010) {
            throw "Ubuntu install failed (exit $($d.ExitCode))"
        }
    }

    Write-Host 'BITS WSL provisioning completed.'
    exit 0
}
catch {
    Write-Error $_
    exit 1
}
finally {
    Exit-InstallAwake
}
