param(
    [string]$PythonVersion = "3",
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

function Resolve-PythonSpec {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PythonRequest
    )

    if ($DryRun) {
        Write-Host "+ uv python install $PythonRequest --managed-python"
    }
    else {
        uv python install $PythonRequest --managed-python
    }

    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        if ($DryRun) {
            return [PSCustomObject]@{
                Version = "x.x.x"
                Path    = "python3"
            }
        }
        throw "uv is not available while resolving Python version."
    }

    $pythonEntries = uv python list $PythonRequest --managed-python --only-installed --output-format json | ConvertFrom-Json
    if (-not $pythonEntries) {
        if ($DryRun) {
            return [PSCustomObject]@{
                Version = "x.x.x"
                Path    = "python3"
            }
        }
        throw "Could not resolve managed Python version."
    }

    if ($pythonEntries -isnot [System.Array]) {
        $pythonEntries = @($pythonEntries)
    }

    $first = $pythonEntries | Select-Object -First 1
    if (-not $first.version -or -not $first.path) {
        if ($DryRun) {
            return [PSCustomObject]@{
                Version = "x.x.x"
                Path    = "python3"
            }
        }
        throw "Could not resolve managed Python version and path."
    }

    return [PSCustomObject]@{
        Version = $first.version
        Path    = $first.path
    }
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
        "PYTHON_VENV_LAST_ACTION=setup"
    ) | Set-Content -Path $EnvFile -Encoding UTF8
}

Invoke-Step -Display "New-Item -ItemType Directory -Path '$AssetsBaseDir' -Force" -Action {
    New-Item -ItemType Directory -Path $AssetsBaseDir -Force | Out-Null
}
Import-DotEnv -Path $EnvFile
if ($env:PYTHON_VENV_ASSETS_DIR) {
    $candidateAssets = [System.IO.Path]::GetFullPath($env:PYTHON_VENV_ASSETS_DIR)
    if ($candidateAssets -ne $AssetsBaseDir) {
        $AssetsBaseDir = $candidateAssets
        $EnvFile = Join-Path $AssetsBaseDir ".env"
        Invoke-Step -Display "New-Item -ItemType Directory -Path '$AssetsBaseDir' -Force" -Action {
            New-Item -ItemType Directory -Path $AssetsBaseDir -Force | Out-Null
        }
        Import-DotEnv -Path $EnvFile
    }
}

if (Get-Command uv -ErrorAction SilentlyContinue) {
    if ($DryRun) {
        Write-Host "+ uv --version"
    }
    else {
        uv --version
    }
}
else {
    Write-Host "uv not found. Installing uv for Windows..."
    Invoke-Step -Display 'powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"' -Action {
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    }

    if (-not $DryRun) {
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $env:Path = "$userPath;$machinePath"

        if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
            throw "uv install finished but uv is still not on PATH. Restart your shell and rerun."
        }
    }
}

$pythonSpec = Resolve-PythonSpec -PythonRequest $PythonVersion
$pythonVersionTag = "v$($pythonSpec.Version)"
$pythonVersionDir = Join-Path $AssetsBaseDir $pythonVersionTag
$venvDir = Join-Path $pythonVersionDir ".venv"
$srcDir = Join-Path $pythonVersionDir "src"
$projectDir = $pythonVersionDir
Write-Host "Python request: $PythonVersion"
Write-Host "Python version: $pythonVersionTag"
Write-Host "Venv path: $venvDir"
Invoke-Step -Display "New-Item -ItemType Directory -Path '$pythonVersionDir' -Force" -Action {
    New-Item -ItemType Directory -Path $pythonVersionDir -Force | Out-Null
}
Invoke-Step -Display "New-Item -ItemType Directory -Path '$srcDir' -Force" -Action {
    New-Item -ItemType Directory -Path $srcDir -Force | Out-Null
}

if ($DryRun) {
    Write-Host "+ if (-not (Test-Path '$projectDir\\pyproject.toml')) { uv --directory '$projectDir' init --bare --python '$($pythonSpec.Path)' }"
}
else {
    if (-not (Test-Path (Join-Path $projectDir "pyproject.toml"))) {
        Invoke-Step -Display "uv --directory '$projectDir' init --bare --python '$($pythonSpec.Path)'" -Action {
            uv --directory $projectDir init --bare --python $pythonSpec.Path
        }
    }
}
Write-Host "Project directory: $projectDir"
Write-Host "Source directory: $srcDir"

if ($DryRun) {
    Write-Host "+ if (-not (Test-Path '$venvDir')) { uv venv --python '$($pythonSpec.Path)' '$venvDir' }"
}
else {
    if (Test-Path $venvDir) {
        Write-Host "Venv already exists. Skip create: $venvDir"
    }
    else {
        Invoke-Step -Display "uv venv --python '$($pythonSpec.Path)' '$venvDir'" -Action {
            uv venv --python $pythonSpec.Path $venvDir
        }
    }
}

Invoke-Step -Display "uv --project '$projectDir' sync --python '$($pythonSpec.Path)'" -Action {
    uv --project $projectDir sync --python $pythonSpec.Path
}
Write-DotEnv -VersionTag $pythonVersionTag -ProjectDir $projectDir -VenvDir $venvDir -PythonBin $pythonSpec.Path

Write-Host "Done."
Write-Host "Activate with: $venvDir\Scripts\Activate.ps1"
