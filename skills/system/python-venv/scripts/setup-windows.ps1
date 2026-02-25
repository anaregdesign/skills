param(
    [string]$PythonVersion = "3",
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

$assetsBaseDir = Join-Path $SkillDir "assets"

Invoke-Step -Display "New-Item -ItemType Directory -Path '$assetsBaseDir' -Force" -Action {
    New-Item -ItemType Directory -Path $assetsBaseDir -Force | Out-Null
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
$pythonVersionDir = Join-Path $assetsBaseDir $pythonVersionTag
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

Invoke-Step -Display "UV_PROJECT_ENVIRONMENT='$venvDir' uv --project '$projectDir' sync --python '$($pythonSpec.Path)'" -Action {
    $previousProjectEnv = $env:UV_PROJECT_ENVIRONMENT
    $previousVirtualEnv = $env:VIRTUAL_ENV
    $env:UV_PROJECT_ENVIRONMENT = $venvDir
    try {
        if ($null -ne $previousVirtualEnv) {
            Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue
        }
        uv --project $projectDir sync --python $pythonSpec.Path
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
}

Write-Host "Done."
Write-Host "Activate with: $venvDir\Scripts\Activate.ps1"
