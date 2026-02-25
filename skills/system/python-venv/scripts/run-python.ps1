param(
    [string]$PythonVersion = "",
    [string]$ScriptPath = "",
    [string]$ModuleName = "",
    [string]$Code = "",
    [string]$CodeBase64 = "",
    [string]$GeneratedScriptName = "generated.py",
    [switch]$DryRun,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
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

function Test-IsAbsolutePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::IsPathRooted($Path)
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
        [string]$VenvDir
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
        "PYTHON_VENV_ACTIVE_PYTHON_BIN=$(Join-Path $VenvDir 'Scripts\python.exe')"
        "PYTHON_VENV_LAST_ACTION=run-python"
    ) | Set-Content -Path $EnvFile -Encoding UTF8
}

function Resolve-ExecutionMode {
    $modeCount = 0
    $mode = ""

    if (-not [string]::IsNullOrWhiteSpace($ScriptPath)) {
        $modeCount++
        $mode = "script"
    }
    if (-not [string]::IsNullOrWhiteSpace($ModuleName)) {
        $modeCount++
        $mode = "module"
    }
    if (-not [string]::IsNullOrWhiteSpace($Code)) {
        $modeCount++
        $mode = "code-text"
    }
    if (-not [string]::IsNullOrWhiteSpace($CodeBase64)) {
        $modeCount++
        $mode = "code-base64"
    }

    if ($modeCount -eq 0) {
        throw "Exactly one execution mode is required: -ScriptPath, -ModuleName, -CodeBase64, or -Code."
    }
    if ($modeCount -gt 1) {
        throw "-ScriptPath, -ModuleName, -CodeBase64, and -Code are mutually exclusive."
    }

    return $mode
}

function Resolve-ScriptPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath
    )

    if (Test-IsAbsolutePath -Path $InputPath) {
        return [System.IO.Path]::GetFullPath($InputPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $InputPath))
}

function Validate-ModuleName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($Name -notmatch '^[A-Za-z_][A-Za-z0-9_\.]*$') {
        throw "Invalid -ModuleName '$Name'. Use a dotted Python module path (example: markitdown)."
    }
}

function Validate-GeneratedScriptName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "-GeneratedScriptName is required when using -CodeBase64 or -Code."
    }

    if ($Name.Contains("/") -or $Name.Contains("\") -or $Name.StartsWith(".") -or $Name.Contains("..")) {
        throw "Invalid -GeneratedScriptName '$Name'. Use a safe filename under src/ (example: generated.py)."
    }

    if (-not $Name.EndsWith(".py")) {
        throw "-GeneratedScriptName must end with .py: $Name"
    }
}

function Write-TextToFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    [System.IO.File]::WriteAllText($OutputPath, $Text, [System.Text.Encoding]::UTF8)
}

function Decode-Base64ToFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Base64Content,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $normalized = ($Base64Content -replace '\s', '')
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        throw "-CodeBase64 requires non-empty base64 content."
    }

    try {
        $bytes = [Convert]::FromBase64String($normalized)
    }
    catch {
        throw "Failed to decode -CodeBase64: $($_.Exception.Message)"
    }

    [System.IO.File]::WriteAllBytes($OutputPath, $bytes)
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

$executionMode = Resolve-ExecutionMode

$normalizedRequest = Resolve-NormalizedRequest -Request $PythonVersion
$versionTag = Resolve-VersionFromUv -NormalizedRequest $normalizedRequest
$projectDir = Join-Path $AssetsBaseDir $versionTag
$venvDir = Join-Path $projectDir ".venv"
$pyprojectPath = Join-Path $projectDir "pyproject.toml"
$srcDir = Join-Path $projectDir "src"

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
Write-Host "Project directory: $projectDir"

if ($executionMode -eq "script") {
    $scriptPathResolved = Resolve-ScriptPath -InputPath $ScriptPath
    if (-not $scriptPathResolved.EndsWith(".py")) {
        throw "-ScriptPath must point to a .py file: $scriptPathResolved"
    }
    if (-not $DryRun -and -not (Test-Path $scriptPathResolved)) {
        throw "Script file not found: $scriptPathResolved"
    }

    Write-Host "Execution mode: script"
    Write-Host "Script path: $scriptPathResolved"

    if ($DryRun) {
        if ($ScriptArgs.Count -gt 0) {
            Write-Host "+ uv --project '$projectDir' run python '$scriptPathResolved' $($ScriptArgs -join ' ')"
        }
        else {
            Write-Host "+ uv --project '$projectDir' run python '$scriptPathResolved'"
        }
        Write-Host "+ write $EnvFile"
        exit 0
    }

    uv --project $projectDir run python $scriptPathResolved @ScriptArgs
}
elseif ($executionMode -eq "module") {
    Validate-ModuleName -Name $ModuleName

    Write-Host "Execution mode: module"
    Write-Host "Module: $ModuleName"

    if ($DryRun) {
        if ($ScriptArgs.Count -gt 0) {
            Write-Host "+ uv --project '$projectDir' run python -m '$ModuleName' $($ScriptArgs -join ' ')"
        }
        else {
            Write-Host "+ uv --project '$projectDir' run python -m '$ModuleName'"
        }
        Write-Host "+ write $EnvFile"
        exit 0
    }

    uv --project $projectDir run python -m $ModuleName @ScriptArgs
}
elseif ($executionMode -eq "code-base64") {
    Validate-GeneratedScriptName -Name $GeneratedScriptName
    $generatedScriptPath = Join-Path $srcDir $GeneratedScriptName

    Write-Host "Execution mode: generated-code"
    Write-Host "Generated script path: $generatedScriptPath"

    if ($DryRun) {
        Write-Host "+ write script to '$generatedScriptPath' from base64"
        if ($ScriptArgs.Count -gt 0) {
            Write-Host "+ uv --project '$projectDir' run python '$generatedScriptPath' $($ScriptArgs -join ' ')"
        }
        else {
            Write-Host "+ uv --project '$projectDir' run python '$generatedScriptPath'"
        }
        Write-Host "+ write $EnvFile"
        exit 0
    }

    if (-not (Test-Path $srcDir)) {
        New-Item -ItemType Directory -Path $srcDir -Force | Out-Null
    }

    Decode-Base64ToFile -Base64Content $CodeBase64 -OutputPath $generatedScriptPath
    uv --project $projectDir run python $generatedScriptPath @ScriptArgs
}
else {
    if ([string]::IsNullOrWhiteSpace($Code)) {
        throw "-Code requires non-empty Python code."
    }

    Validate-GeneratedScriptName -Name $GeneratedScriptName
    $generatedScriptPath = Join-Path $srcDir $GeneratedScriptName

    Write-Host "Execution mode: generated-code"
    Write-Host "Generated script path: $generatedScriptPath"

    if ($DryRun) {
        Write-Host "+ write script to '$generatedScriptPath' from -Code"
        if ($ScriptArgs.Count -gt 0) {
            Write-Host "+ uv --project '$projectDir' run python '$generatedScriptPath' $($ScriptArgs -join ' ')"
        }
        else {
            Write-Host "+ uv --project '$projectDir' run python '$generatedScriptPath'"
        }
        Write-Host "+ write $EnvFile"
        exit 0
    }

    if (-not (Test-Path $srcDir)) {
        New-Item -ItemType Directory -Path $srcDir -Force | Out-Null
    }

    Write-TextToFile -Text $Code -OutputPath $generatedScriptPath
    uv --project $projectDir run python $generatedScriptPath @ScriptArgs
}

Write-DotEnv -VersionTag $versionTag -ProjectDir $projectDir -VenvDir $venvDir
Write-Host "Done."
