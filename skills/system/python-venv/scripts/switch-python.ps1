param(
    [string]$WorkspaceDir,
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

function Ensure-Uv {
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        if ($DryRun) {
            Write-Host "+ uv --version"
        }
        else {
            uv --version
        }
        return
    }

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
        throw "Could not resolve managed Python version for '$PythonRequest'."
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

$isDotSourced = $MyInvocation.InvocationName -eq "."
if (-not $isDotSourced -and -not $DryRun) {
    Write-Error "Run this script with dot-sourcing to apply deactivate/activate in current shell."
    Write-Host "Example: . .\scripts\switch-python.ps1 -PythonVersion $PythonVersion"
    exit 1
}

$WorkspaceDir = Resolve-WorkspaceDir -ExplicitDir $WorkspaceDir
Write-Host "Workspace directory: $WorkspaceDir"
$assetsBaseDir = Join-Path $SkillDir "assets"

Invoke-Step -Display "New-Item -ItemType Directory -Path '$assetsBaseDir' -Force" -Action {
    New-Item -ItemType Directory -Path $assetsBaseDir -Force | Out-Null
}
Invoke-Step -Display "Set-Location '$assetsBaseDir'" -Action {
    Set-Location $assetsBaseDir
}

Ensure-Uv
$pythonSpec = Resolve-PythonSpec -PythonRequest $PythonVersion
$pythonVersionTag = "v$($pythonSpec.Version)"
$pythonVersionDir = Join-Path $assetsBaseDir $pythonVersionTag
$venvDir = Join-Path $pythonVersionDir ".venv"
$activateScript = Join-Path $venvDir "Scripts\Activate.ps1"
Write-Host "Python request: $PythonVersion"
Write-Host "Python version: $pythonVersionTag"
Write-Host "Venv path: $venvDir"

Invoke-Step -Display "New-Item -ItemType Directory -Path '$WorkspaceDir' -Force" -Action {
    New-Item -ItemType Directory -Path $WorkspaceDir -Force | Out-Null
}

if ($DryRun) {
    Write-Host "+ if (-not (Test-Path '$WorkspaceDir\pyproject.toml')) { uv --directory '$WorkspaceDir' init --python '$($pythonSpec.Path)' }"
}
else {
    if (-not (Test-Path (Join-Path $WorkspaceDir "pyproject.toml"))) {
        Invoke-Step -Display "uv --directory '$WorkspaceDir' init --python '$($pythonSpec.Path)'" -Action {
            uv --directory $WorkspaceDir init --python $pythonSpec.Path
        }
    }
}

Invoke-Step -Display "New-Item -ItemType Directory -Path '$pythonVersionDir' -Force" -Action {
    New-Item -ItemType Directory -Path $pythonVersionDir -Force | Out-Null
}
Invoke-Step -Display "Set-Location '$pythonVersionDir'" -Action {
    Set-Location $pythonVersionDir
}

if ($DryRun) {
    Write-Host "+ if (-not (Test-Path '$venvDir')) { uv venv --python '$($pythonSpec.Path)' '$venvDir' }"
}
else {
    if (-not (Test-Path $venvDir)) {
        Invoke-Step -Display "uv venv --python '$($pythonSpec.Path)' '$venvDir'" -Action {
            uv venv --python $pythonSpec.Path $venvDir
        }
    }
}

Invoke-Step -Display "UV_PROJECT_ENVIRONMENT='$venvDir' uv --project '$WorkspaceDir' sync --python '$($pythonSpec.Path)'" -Action {
    $previousProjectEnv = $env:UV_PROJECT_ENVIRONMENT
    $previousVirtualEnv = $env:VIRTUAL_ENV
    $env:UV_PROJECT_ENVIRONMENT = $venvDir
    try {
        if ($null -ne $previousVirtualEnv) {
            Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue
        }
        uv --project $WorkspaceDir sync --python $pythonSpec.Path
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

if ($DryRun) {
    Write-Host "+ deactivate (if active)"
    Write-Host "+ . '$activateScript'"
    exit 0
}

if (Get-Command deactivate -ErrorAction SilentlyContinue) {
    deactivate
}
elseif ($env:VIRTUAL_ENV) {
    Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue
}

. $activateScript
Write-Host "Activated VIRTUAL_ENV: $env:VIRTUAL_ENV"
