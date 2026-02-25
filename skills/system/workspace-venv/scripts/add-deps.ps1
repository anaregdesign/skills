param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceDir,
    [Parameter(Mandatory = $true)]
    [string[]]$Packages,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $PSCommandPath
$SkillDir = Split-Path -Parent $ScriptDir

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

function Resolve-VenvDir {
    $venvBase = Join-Path $SkillDir "venv"
    $activeVenv = $env:VIRTUAL_ENV

    if ($activeVenv) {
        $activeFull = [System.IO.Path]::GetFullPath($activeVenv)
        $activeVersionDir = Split-Path -Parent $activeFull
        $activeTag = Split-Path -Leaf $activeVersionDir
        if (
            $activeFull -like "$venvBase*" -and
            $activeTag -match '^v\d+\.\d+\.\d+$' -and
            (Test-Path $activeFull)
        ) {
            return [PSCustomObject]@{
                VersionTag = $activeTag
                Path       = $activeFull
            }
        }
    }

    if (-not (Test-Path $venvBase)) {
        throw "No venv directory found at $venvBase. Run setup-windows.ps1 first."
    }

    $versionDirs = Get-ChildItem -Path $venvBase -Directory -Filter "v*" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -match '^v\d+\.\d+\.\d+$' -and
            (Test-Path (Join-Path $_.FullName ".venv"))
        } |
        Sort-Object { [version]($_.Name.Substring(1)) } -Descending

    $selected = $versionDirs | Select-Object -First 1
    if (-not $selected) {
        throw "No venv matching vX.Y.Z/.venv found under $venvBase. Run setup-windows.ps1 first."
    }

    return [PSCustomObject]@{
        VersionTag = $selected.Name
        Path       = Join-Path $selected.FullName ".venv"
    }
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "uv is not available. Run setup-windows.ps1 first."
}

$venvSpec = Resolve-VenvDir
Write-Host "Python version: $($venvSpec.VersionTag)"
Write-Host "Venv path: $($venvSpec.Path)"

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
Invoke-Step -Display "UV_PROJECT_ENVIRONMENT='$($venvSpec.Path)' uv sync" -Action {
    $previousProjectEnv = $env:UV_PROJECT_ENVIRONMENT
    $env:UV_PROJECT_ENVIRONMENT = $venvSpec.Path
    try {
        uv sync
    }
    finally {
        if ($null -ne $previousProjectEnv) {
            $env:UV_PROJECT_ENVIRONMENT = $previousProjectEnv
        }
        else {
            Remove-Item Env:UV_PROJECT_ENVIRONMENT -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "Done."
