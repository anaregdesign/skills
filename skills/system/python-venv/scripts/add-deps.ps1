param(
    [string]$PythonVersion = "",
    [Parameter(Mandatory = $true)]
    [string[]]$Packages,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ResolvedScriptPath = (Resolve-Path -LiteralPath $PSCommandPath).Path
$ScriptDir = Split-Path -Parent $ResolvedScriptPath
$DefaultSkillDir = Split-Path -Parent $ScriptDir
$SkillDir = if ($env:PYTHON_VENV_SKILL_DIR) { $env:PYTHON_VENV_SKILL_DIR } else { $DefaultSkillDir }
$SkillDir = [System.IO.Path]::GetFullPath($SkillDir)
$AssetsBaseDir = if ($env:PYTHON_VENV_ASSETS_DIR) { $env:PYTHON_VENV_ASSETS_DIR } else { Join-Path $SkillDir "assets" }
$AssetsBaseDir = [System.IO.Path]::GetFullPath($AssetsBaseDir)
$EnvFile = Join-Path $AssetsBaseDir ".env"

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

    $global:LASTEXITCODE = 0
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Step failed: $Display (exit code: $LASTEXITCODE)"
    }
}

function Resolve-NormalizedRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Request
    )

    $normalized = $Request
    if ($normalized.StartsWith("v")) {
        $normalized = $normalized.Substring(1)
    }

    if ($normalized -notmatch '^\d+(\.\d+){0,2}$') {
        throw "Invalid -PythonVersion '$Request'. Use one of: 3 / 3.12 / 3.12.10."
    }

    return $normalized
}

function Resolve-VersionFromUv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NormalizedRequest
    )

    $pythonEntries = uv python list $NormalizedRequest --managed-python --only-installed --output-format json | ConvertFrom-Json
    if (-not $pythonEntries) {
        throw "No uv-managed Python found for request '$NormalizedRequest'. Run setup-windows.ps1 first."
    }

    if ($pythonEntries -isnot [System.Array]) {
        $pythonEntries = @($pythonEntries)
    }

    $first = $pythonEntries | Select-Object -First 1
    if (-not $first.version) {
        throw "Could not resolve uv-managed Python version for request '$NormalizedRequest'."
    }

    return "v$($first.version)"
}

function Import-DotEnv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return
    }

    foreach ($line in Get-Content -Path $Path) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($line.TrimStart().StartsWith("#")) {
            continue
        }
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            Set-Item -Path "Env:$($Matches[1])" -Value $Matches[2]
        }
    }
}

function Write-DotEnv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VersionTag,
        [Parameter(Mandatory = $true)]
        [string]$ProjectDir,
        [Parameter(Mandatory = $true)]
        [string]$VenvDir,
        [Parameter(Mandatory = $true)]
        [string]$PythonBin
    )

    if ($DryRun) {
        Write-Host "+ write $EnvFile"
        return
    }

    @(
        "PYTHON_VENV_SKILL_DIR=$SkillDir"
        "PYTHON_VENV_ASSETS_DIR=$AssetsBaseDir"
        "PYTHON_VENV_ACTIVE_VERSION=$VersionTag"
        "PYTHON_VENV_ACTIVE_PROJECT_DIR=$ProjectDir"
        "PYTHON_VENV_ACTIVE_VENV_DIR=$VenvDir"
        "PYTHON_VENV_ACTIVE_PYTHON_BIN=$PythonBin"
        "PYTHON_VENV_LAST_ACTION=add-deps"
    ) | Set-Content -Path $EnvFile -Encoding UTF8
}

if (-not (Test-Path $AssetsBaseDir)) {
    New-Item -ItemType Directory -Path $AssetsBaseDir -Force | Out-Null
}
Import-DotEnv -Path $EnvFile
if ($env:PYTHON_VENV_ASSETS_DIR) {
    $candidateAssets = [System.IO.Path]::GetFullPath($env:PYTHON_VENV_ASSETS_DIR)
    if ($candidateAssets -ne $AssetsBaseDir) {
        $AssetsBaseDir = $candidateAssets
        $EnvFile = Join-Path $AssetsBaseDir ".env"
        if (-not (Test-Path $AssetsBaseDir)) {
            New-Item -ItemType Directory -Path $AssetsBaseDir -Force | Out-Null
        }
        Import-DotEnv -Path $EnvFile
    }
}

if ([string]::IsNullOrWhiteSpace($PythonVersion) -and $env:PYTHON_VENV_ACTIVE_VERSION) {
    $PythonVersion = $env:PYTHON_VENV_ACTIVE_VERSION
    Write-Host "Using PYTHON_VENV_ACTIVE_VERSION from $EnvFile: $PythonVersion"
}
if ([string]::IsNullOrWhiteSpace($PythonVersion)) {
    throw "-PythonVersion is required (or set PYTHON_VENV_ACTIVE_VERSION in $EnvFile)."
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "uv is not available. Run setup-windows.ps1 first."
}

$normalizedRequest = Resolve-NormalizedRequest -Request $PythonVersion
$versionTag = Resolve-VersionFromUv -NormalizedRequest $normalizedRequest
$projectDir = Join-Path $AssetsBaseDir $versionTag
$venvDir = Join-Path $projectDir ".venv"
$pyprojectPath = Join-Path $projectDir "pyproject.toml"
$pythonBin = Join-Path $venvDir "Scripts\python.exe"

if (-not (Test-Path $projectDir)) {
    throw "Project directory not found: $projectDir. Run setup-windows.ps1 first."
}
if (-not (Test-Path $venvDir)) {
    throw "Expected venv does not exist: $venvDir. Run setup-windows.ps1 first."
}
if (-not (Test-Path $pyprojectPath)) {
    throw "Project metadata not found: $pyprojectPath. Run setup-windows.ps1 first."
}

Write-Host "Python request: $PythonVersion"
Write-Host "Python version: $versionTag"
Write-Host "Venv path: $venvDir"
Write-Host "Project directory: $projectDir"

if ($DryRun) {
    Write-Host "+ uv --version"
}
else {
    uv --version
}

Invoke-Step -Display ("uv --project '$projectDir' add --python '$pythonBin' " + ($Packages -join " ")) -Action {
    uv --project $projectDir add --python $pythonBin @Packages
}
Invoke-Step -Display "uv --project '$projectDir' lock --python '$pythonBin'" -Action {
    uv --project $projectDir lock --python $pythonBin
}
Invoke-Step -Display "uv --project '$projectDir' sync --python '$pythonBin'" -Action {
    uv --project $projectDir sync --python $pythonBin
}
Write-DotEnv -VersionTag $versionTag -ProjectDir $projectDir -VenvDir $venvDir -PythonBin $pythonBin

Write-Host "Done."
