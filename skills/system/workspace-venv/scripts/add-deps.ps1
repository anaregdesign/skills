param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceDir,
    [Parameter(Mandatory = $true)]
    [string[]]$Packages,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Display,
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$Action
    )

    if ($DryRun) {
        Write-Host "+ $Display"
        return
    }

    & $Action
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "uv is not available. Run setup-windows.ps1 first."
}

if ($DryRun) {
    Write-Host "+ uv --version"
    Write-Host "+ Set-Location '$WorkspaceDir'"
    Write-Host "+ if (-not (Test-Path pyproject.toml)) { throw 'pyproject.toml not found' }"
}
else {
    uv --version
    Set-Location $WorkspaceDir
    if (-not (Test-Path pyproject.toml)) {
        throw "pyproject.toml not found in $WorkspaceDir"
    }
}

Invoke-Step -Display ("uv add " + ($Packages -join " ")) -Action {
    uv add @Packages
}
Invoke-Step -Display "uv lock" -Action { uv lock }
Invoke-Step -Display "uv sync" -Action { uv sync }

Write-Host "Done."
