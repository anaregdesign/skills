param(
    [string]$WorkspaceDir,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

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

Invoke-Step -Display "uv venv --python 3 .venv" -Action {
    uv venv --python 3 .venv
}

Invoke-Step -Display "uv sync" -Action { uv sync }

Write-Host "Done."
Write-Host "Activate with: $WorkspaceDir\.venv\Scripts\Activate.ps1"
