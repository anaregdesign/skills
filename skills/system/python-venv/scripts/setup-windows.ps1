param(
    [string]$WorkspaceDir,
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

    & $Action
}

function Resolve-WorkspaceDir {
    param(
        [string]$ExplicitDir
    )

    $detectedDir = $null

    if ($ExplicitDir) {
        $detectedDir = $ExplicitDir
    }
    elseif (Test-Path (Join-Path (Get-Location) "pyproject.toml")) {
        $detectedDir = (Get-Location).Path
    }
    else {
        $gitRoot = $null
        if (Get-Command git -ErrorAction SilentlyContinue) {
            try {
                $candidate = (git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
                if ($candidate) {
                    $gitRoot = $candidate.Trim()
                }
            }
            catch {
                $gitRoot = $null
            }
        }

        if ($gitRoot -and (Test-Path (Join-Path $gitRoot "pyproject.toml"))) {
            $detectedDir = $gitRoot
        }
        elseif ($gitRoot) {
            $detectedDir = $gitRoot
        }
        else {
            $detectedDir = (Get-Location).Path
        }
    }

    if (-not $detectedDir) {
        if ([Environment]::UserInteractive) {
            $detectedDir = Read-Host "Workspace directory was not auto-detected. Enter path"
        }
        else {
            throw "Workspace directory was not auto-detected. Pass -WorkspaceDir."
        }
    }

    if (-not $detectedDir) {
        throw "Workspace directory is empty."
    }

    return [System.IO.Path]::GetFullPath($detectedDir)
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

$WorkspaceDir = Resolve-WorkspaceDir -ExplicitDir $WorkspaceDir
Write-Host "Workspace directory: $WorkspaceDir"

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
$venvDir = Join-Path (Join-Path (Join-Path $SkillDir "venv") $pythonVersionTag) ".venv"
Write-Host "Python request: $PythonVersion"
Write-Host "Python version: $pythonVersionTag"
Write-Host "Venv path: $venvDir"

Invoke-Step -Display "New-Item -ItemType Directory -Path '$WorkspaceDir' -Force" -Action {
    New-Item -ItemType Directory -Path $WorkspaceDir -Force | Out-Null
}

if ($DryRun) {
    Write-Host "+ Set-Location '$WorkspaceDir'"
    Write-Host "+ if (-not (Test-Path pyproject.toml)) { uv init }"
}
else {
    Set-Location $WorkspaceDir
    if (-not (Test-Path pyproject.toml)) {
        Invoke-Step -Display "uv init" -Action { uv init }
    }
}

Invoke-Step -Display "New-Item -ItemType Directory -Path '$(Split-Path -Parent $venvDir)' -Force" -Action {
    New-Item -ItemType Directory -Path (Split-Path -Parent $venvDir) -Force | Out-Null
}

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

Invoke-Step -Display "UV_PROJECT_ENVIRONMENT='$venvDir' uv sync" -Action {
    $previousProjectEnv = $env:UV_PROJECT_ENVIRONMENT
    $env:UV_PROJECT_ENVIRONMENT = $venvDir
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
Write-Host "Activate with: $venvDir\Scripts\Activate.ps1"
