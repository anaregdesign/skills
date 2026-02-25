param(
    [string]$PythonVersion = "",
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

function Resolve-VersionTag {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    $normalized = $Version
    if ($normalized.StartsWith("v")) {
        $normalized = $normalized.Substring(1)
    }

    if ($normalized -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid -PythonVersion '$Version'. Use exact version like 3.12.10."
    }

    return "v$normalized"
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

function Write-ClearedDotEnv {
    if ($DryRun) {
        Write-Host "+ write $EnvFile"
        return
    }

    @(
        "PYTHON_VENV_SKILL_DIR=$SkillDir"
        "PYTHON_VENV_ASSETS_DIR=$AssetsBaseDir"
        "PYTHON_VENV_LAST_ACTION=remove"
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

$versionTag = Resolve-VersionTag -Version $PythonVersion
$targetDir = Join-Path $AssetsBaseDir $versionTag
$targetVenv = Join-Path $targetDir ".venv"

Write-Host "Python version: $versionTag"
Write-Host "Target path: $targetDir"

if (-not (Test-Path $targetDir)) {
    Write-Host "Nothing to remove. Directory not found: $targetDir"
    exit 0
}

if ($env:VIRTUAL_ENV) {
    $active = [System.IO.Path]::GetFullPath($env:VIRTUAL_ENV).TrimEnd('\\', '/')
    $target = [System.IO.Path]::GetFullPath($targetVenv).TrimEnd('\\', '/')
    if ($active -eq $target) {
        throw "Target environment is currently active: $active. Deactivate it first."
    }
}
elseif ($env:PYTHON_VENV_ACTIVE_VENV_DIR) {
    $remembered = [System.IO.Path]::GetFullPath($env:PYTHON_VENV_ACTIVE_VENV_DIR).TrimEnd('\\', '/')
    $target = [System.IO.Path]::GetFullPath($targetVenv).TrimEnd('\\', '/')
    if ($remembered -eq $target) {
        Write-Host "Note: $EnvFile indicates this version was last active in another process."
    }
}

Invoke-Step -Display "Remove-Item -Path '$targetDir' -Recurse -Force" -Action {
    Remove-Item -Path $targetDir -Recurse -Force
}

if ($env:PYTHON_VENV_ACTIVE_VERSION -eq $versionTag) {
    Write-ClearedDotEnv
}

Write-Host "Done. Removed $targetDir"
