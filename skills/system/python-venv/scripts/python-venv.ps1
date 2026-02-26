function Show-PythonVenvUsage {
@"
Usage:
  python_venv ensure <X.Y.Z>
  python_venv activate <X.Y.Z>
  python_venv deactivate
  python_venv use <X.Y.Z>
  python_venv add <X.Y.Z> <dep...>
  python_venv path <X.Y.Z>
"@
}

function Get-PythonVenvSkillDir {
    $currentDir = (Resolve-Path -LiteralPath $PSScriptRoot).Path
    while ($true) {
        $skillMdPath = Join-Path $currentDir "SKILL.md"
        if (Test-Path -LiteralPath $skillMdPath) {
            return $currentDir
        }

        $parentDir = Split-Path -Path $currentDir -Parent
        if ([string]::IsNullOrWhiteSpace($parentDir) -or $parentDir -eq $currentDir) {
            break
        }
        $currentDir = $parentDir
    }

    throw "SKILL.md not found while resolving skill directory from: $PSScriptRoot"
}

function Get-PythonVenvDir {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )
    Join-Path (Get-PythonVenvSkillDir) ("assets/v{0}" -f $Version)
}

function Assert-PythonVenvUv {
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        throw "uv command not found in PATH."
    }
}

function Ensure-PythonVenv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    Assert-PythonVenvUv
    $envDir = Get-PythonVenvDir -Version $Version
    New-Item -ItemType Directory -Path $envDir -Force | Out-Null

    $previousLocation = Get-Location
    try {
        Set-Location -LiteralPath $envDir

        if (-not (Test-Path -LiteralPath (Join-Path $envDir "pyproject.toml"))) {
            & uv init --bare --python $Version --name ("python_v" + $Version.Replace(".", "_"))
            if ($LASTEXITCODE -ne 0) {
                throw "uv init failed with exit code $LASTEXITCODE."
            }
        }

        & uv venv --python $Version --allow-existing
        if ($LASTEXITCODE -ne 0) {
            throw "uv venv failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Set-Location -LiteralPath $previousLocation
    }
}

function Get-PythonVenvActivateScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    $envDir = Get-PythonVenvDir -Version $Version
    $unixActivate = Join-Path (Join-Path $envDir ".venv") "bin/Activate.ps1"
    $windowsActivate = Join-Path (Join-Path $envDir ".venv") "Scripts/Activate.ps1"

    if (Test-Path -LiteralPath $unixActivate) {
        return $unixActivate
    }
    if (Test-Path -LiteralPath $windowsActivate) {
        return $windowsActivate
    }
    return $null
}

function Activate-PythonVenv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    $activatePath = Get-PythonVenvActivateScript -Version $Version
    if ($null -eq $activatePath) {
        Ensure-PythonVenv -Version $Version
        $activatePath = Get-PythonVenvActivateScript -Version $Version
    }

    if ($null -eq $activatePath) {
        throw "Activate script not found for version $Version."
    }

    . $activatePath
}

function Deactivate-PythonVenv {
    if ([string]::IsNullOrWhiteSpace($env:VIRTUAL_ENV)) {
        return
    }

    if (Get-Command deactivate -ErrorAction SilentlyContinue) {
        deactivate
        return
    }

    $oldVirtualEnv = $env:VIRTUAL_ENV
    Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue
    Remove-Item Env:VIRTUAL_ENV_PROMPT -ErrorAction SilentlyContinue

    $binPath = Join-Path $oldVirtualEnv "bin"
    $scriptsPath = Join-Path $oldVirtualEnv "Scripts"
    $pathEntries = @()
    foreach ($entry in ($env:PATH -split [IO.Path]::PathSeparator)) {
        if ([string]::IsNullOrWhiteSpace($entry)) {
            continue
        }
        if ($entry -eq $binPath -or $entry -eq $scriptsPath) {
            continue
        }
        $pathEntries += $entry
    }
    $env:PATH = ($pathEntries -join [IO.Path]::PathSeparator)
}

function Test-NonPythonDependency {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Dependency
    )

    switch ($Dependency) {
        "pptxgenjs" { return $true }
        "npm:pptxgenjs" { return $true }
        default { return $false }
    }
}

function Add-PythonVenvDependencies {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $true)]
        [string[]]$Dependencies
    )

    Ensure-PythonVenv -Version $Version
    $envDir = Get-PythonVenvDir -Version $Version
    $pythonDependencies = @()
    $skippedDependencies = @()

    foreach ($dependency in $Dependencies) {
        if (Test-NonPythonDependency -Dependency $dependency) {
            $skippedDependencies += $dependency
            continue
        }
        $pythonDependencies += $dependency
    }

    if ($skippedDependencies.Count -gt 0) {
        [Console]::Error.WriteLine("Skipping non-Python dependencies: {0}. Install with: npm install -g pptxgenjs" -f ($skippedDependencies -join " "))
    }

    if ($pythonDependencies.Count -eq 0) {
        return
    }

    $previousLocation = Get-Location
    try {
        Set-Location -LiteralPath $envDir

        & uv add @pythonDependencies
        if ($LASTEXITCODE -ne 0) {
            throw "uv add failed with exit code $LASTEXITCODE."
        }

        & uv lock
        if ($LASTEXITCODE -ne 0) {
            throw "uv lock failed with exit code $LASTEXITCODE."
        }

        & uv sync
        if ($LASTEXITCODE -ne 0) {
            throw "uv sync failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Set-Location -LiteralPath $previousLocation
    }
}

function python_venv {
    param(
        [Parameter(Position = 0)]
        [string]$Action,
        [Parameter(Position = 1)]
        [string]$Version,
        [Parameter(Position = 2, ValueFromRemainingArguments = $true)]
        [string[]]$Dependencies
    )

    if ([string]::IsNullOrWhiteSpace($Action)) {
        [Console]::Error.WriteLine((Show-PythonVenvUsage))
        throw "Action is required."
    }

    switch ($Action.ToLowerInvariant()) {
        "ensure" {
            if ([string]::IsNullOrWhiteSpace($Version)) {
                [Console]::Error.WriteLine((Show-PythonVenvUsage))
                throw "Version is required for ensure."
            }
            Ensure-PythonVenv -Version $Version
        }
        "activate" {
            if ([string]::IsNullOrWhiteSpace($Version)) {
                [Console]::Error.WriteLine((Show-PythonVenvUsage))
                throw "Version is required for activate."
            }
            $targetVenv = Join-Path (Get-PythonVenvDir -Version $Version) ".venv"
            if (-not [string]::IsNullOrWhiteSpace($env:VIRTUAL_ENV) -and $env:VIRTUAL_ENV -ne $targetVenv) {
                Deactivate-PythonVenv
            }
            Activate-PythonVenv -Version $Version
        }
        "deactivate" {
            Deactivate-PythonVenv
        }
        "use" {
            if ([string]::IsNullOrWhiteSpace($Version)) {
                [Console]::Error.WriteLine((Show-PythonVenvUsage))
                throw "Version is required for use."
            }
            Ensure-PythonVenv -Version $Version
            $targetVenv = Join-Path (Get-PythonVenvDir -Version $Version) ".venv"
            if (-not [string]::IsNullOrWhiteSpace($env:VIRTUAL_ENV) -and $env:VIRTUAL_ENV -ne $targetVenv) {
                Deactivate-PythonVenv
            }
            Activate-PythonVenv -Version $Version
        }
        "add" {
            if ([string]::IsNullOrWhiteSpace($Version) -or $null -eq $Dependencies -or $Dependencies.Count -eq 0) {
                [Console]::Error.WriteLine((Show-PythonVenvUsage))
                throw "Version and dependencies are required for add."
            }
            Add-PythonVenvDependencies -Version $Version -Dependencies $Dependencies
        }
        "path" {
            if ([string]::IsNullOrWhiteSpace($Version)) {
                [Console]::Error.WriteLine((Show-PythonVenvUsage))
                throw "Version is required for path."
            }
            Get-PythonVenvDir -Version $Version
        }
        default {
            [Console]::Error.WriteLine((Show-PythonVenvUsage))
            throw "Unknown action: $Action"
        }
    }
}

if ($MyInvocation.InvocationName -ne ".") {
    python_venv @args
}
