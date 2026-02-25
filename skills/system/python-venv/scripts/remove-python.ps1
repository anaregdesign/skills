param(
    [Parameter(Mandatory = $true)]
    [string]$PythonVersion,
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

$versionTag = Resolve-VersionTag -Version $PythonVersion
$assetsBaseDir = Join-Path $SkillDir "assets"
$targetDir = Join-Path $assetsBaseDir $versionTag
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

Invoke-Step -Display "Remove-Item -Path '$targetDir' -Recurse -Force" -Action {
    Remove-Item -Path $targetDir -Recurse -Force
}

Write-Host "Done. Removed $targetDir"
