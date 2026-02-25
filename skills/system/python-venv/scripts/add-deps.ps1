param(
    [Parameter(Mandatory = $true)]
    [string[]]$Packages,
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

function Resolve-VenvDir {
    $venvBase = Join-Path $SkillDir "assets"
    $activeVenv = $env:VIRTUAL_ENV

    if ($activeVenv) {
        $activeFull = [System.IO.Path]::GetFullPath($activeVenv)
        $activeVersionDir = Split-Path -Parent $activeFull
        $activeTag = Split-Path -Leaf $activeVersionDir
        if (
            $activeFull -like "$venvBase*" -and
            $activeTag -match '^v\d+\.\d+\.\d+$' -and
            (Test-Path $activeFull)
        ) {
            return [PSCustomObject]@{
                VersionTag = $activeTag
                Path       = $activeFull
            }
        }
    }

    if (-not (Test-Path $venvBase)) {
        if ($DryRun) {
            Write-Host "+ New-Item -ItemType Directory -Path '$venvBase' -Force"
        }
        else {
            New-Item -ItemType Directory -Path $venvBase -Force | Out-Null
        }
    }

    $versionDirs = Get-ChildItem -Path $venvBase -Directory -Filter "v*" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -match '^v\d+\.\d+\.\d+$' -and
            (Test-Path (Join-Path $_.FullName ".venv"))
        } |
        Sort-Object { [version]($_.Name.Substring(1)) } -Descending

    $selected = $versionDirs | Select-Object -First 1
    if (-not $selected) {
        throw "No venv matching vX.Y.Z/.venv found under $venvBase. Run setup-windows.ps1 first."
    }

    return [PSCustomObject]@{
        VersionTag = $selected.Name
        Path       = Join-Path $selected.FullName ".venv"
    }
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "uv is not available. Run setup-windows.ps1 first."
}

$venvSpec = Resolve-VenvDir
$pythonBin = Join-Path $venvSpec.Path "Scripts\\python.exe"
$pythonVersionDir = Split-Path -Parent $venvSpec.Path
$projectDir = $pythonVersionDir
Write-Host "Python version: $($venvSpec.VersionTag)"
Write-Host "Venv path: $($venvSpec.Path)"

if ($DryRun) {
    Write-Host "+ Set-Location '$pythonVersionDir'"
    Write-Host "+ uv --version"
    Write-Host "+ if (-not (Test-Path '$projectDir\\pyproject.toml')) { uv --directory '$projectDir' init --bare --python '$pythonBin' }"
}
else {
    Set-Location $pythonVersionDir
    uv --version
    if (-not (Test-Path (Join-Path $projectDir "pyproject.toml"))) {
        uv --directory $projectDir init --bare --python $pythonBin
    }
}
Write-Host "Project directory: $projectDir"

Invoke-Step -Display ("UV_PROJECT_ENVIRONMENT='$($venvSpec.Path)' uv --project '$projectDir' add --python '$pythonBin' " + ($Packages -join " ")) -Action {
    $previousProjectEnv = $env:UV_PROJECT_ENVIRONMENT
    $previousVirtualEnv = $env:VIRTUAL_ENV
    $env:UV_PROJECT_ENVIRONMENT = $venvSpec.Path
    try {
        if ($null -ne $previousVirtualEnv) {
            Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue
        }
        uv --project $projectDir add --python $pythonBin @Packages
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
Invoke-Step -Display "UV_PROJECT_ENVIRONMENT='$($venvSpec.Path)' uv --project '$projectDir' lock --python '$pythonBin'" -Action {
    $previousProjectEnv = $env:UV_PROJECT_ENVIRONMENT
    $previousVirtualEnv = $env:VIRTUAL_ENV
    $env:UV_PROJECT_ENVIRONMENT = $venvSpec.Path
    try {
        if ($null -ne $previousVirtualEnv) {
            Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue
        }
        uv --project $projectDir lock --python $pythonBin
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
Invoke-Step -Display "UV_PROJECT_ENVIRONMENT='$($venvSpec.Path)' uv --project '$projectDir' sync --python '$pythonBin'" -Action {
    $previousProjectEnv = $env:UV_PROJECT_ENVIRONMENT
    $previousVirtualEnv = $env:VIRTUAL_ENV
    $env:UV_PROJECT_ENVIRONMENT = $venvSpec.Path
    try {
        if ($null -ne $previousVirtualEnv) {
            Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue
        }
        uv --project $projectDir sync --python $pythonBin
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
