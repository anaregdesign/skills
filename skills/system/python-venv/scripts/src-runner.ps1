param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Script,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

$ErrorActionPreference = "Stop"
$RunnerDir = Split-Path -Parent $PSCommandPath
$ProjectDir = Split-Path -Parent $RunnerDir
$VenvDir = Join-Path $ProjectDir ".venv"
$PythonBin = Join-Path $VenvDir "Scripts\python.exe"

if (-not (Test-Path $VenvDir)) {
    throw "Project venv not found: $VenvDir. Run setup/switch script for this Python version first."
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "uv is not available. Run setup script first."
}

if ([System.IO.Path]::IsPathRooted($Script)) {
    $scriptPath = $Script
}
else {
    $scriptPath = Join-Path $RunnerDir $Script
}
$scriptPath = [System.IO.Path]::GetFullPath($scriptPath)

if (-not (Test-Path $scriptPath)) {
    throw "Script not found: $scriptPath"
}

$previousProjectEnv = $env:UV_PROJECT_ENVIRONMENT
$previousVirtualEnv = $env:VIRTUAL_ENV
$env:UV_PROJECT_ENVIRONMENT = $VenvDir

try {
    if ($null -ne $previousVirtualEnv) {
        Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue
    }
    uv --project $ProjectDir run --python $PythonBin python $scriptPath @ScriptArgs
}
finally {
    if ($null -ne $previousVirtualEnv) {
        $env:VIRTUAL_ENV = $previousVirtualEnv
    }
    else {
        Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue
    }

    if ($null -ne $previousProjectEnv) {
        $env:UV_PROJECT_ENVIRONMENT = $previousProjectEnv
    }
    else {
        Remove-Item Env:UV_PROJECT_ENVIRONMENT -ErrorAction SilentlyContinue
    }
}
