# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

<#
.SYNOPSIS
Setups dependencies required to build and work with the SFS Client.

.DESCRIPTION
This script will install all of the dependencies required to build and work with the SFS Client.
Use this on Windows platforms in a PowerShell session.

.EXAMPLE
PS> .\scripts\Setup.ps1
#>

function Update-Env {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Install-Python {
    Write-Host -ForegroundColor Cyan "Installing latest Python if it's not installed"

    # We use the "python --version" command to check if it exists because by default Windows now comes
    # with a python.exe from the Store that simply opens the Store when someone tries to use python.exe
    python --version 2>&1 | Out-Null
    if (!$?) {
        winget install python
        if (!$?) {
            Write-Host "Failed to install Python"
            exit 1
        }
    }
}

function Install-PipDependencies {
    Write-Host -ForegroundColor Cyan "`nInstalling dependencies using pip"

    # Upgrade pip and install requirements. Filter out output for dependencies that are already installed
    $PipInstalledPackageString = "Requirement already satisfied"
    python -m pip install --upgrade pip | Select-String -Pattern $PipInstalledPackageString -NotMatch

    $PipReqs = Join-Path $PSScriptRoot "pip.requirements.txt" -Resolve
    pip install -r $PipReqs | Select-String -Pattern $PipInstalledPackageString -NotMatch
}

function Install-CMake {
    Write-Host -ForegroundColor Cyan "`nInstalling cmake if it's not installed"

    # Installing cmake from winget because it adds to PATH
    cmake --version 2>&1 | Out-Null
    if (!$?) {
        winget install cmake
        if (!$?) {
            Write-Host "Failed to install cmake"
            exit 1
        }

        # Update env with newly installed cmake
        Update-Env
    }
}

function Install-CppBuildTools {
    Write-Host -ForegroundColor Cyan "`nInstalling C++ Build Tools"

    # - Microsoft.VisualStudio.Workload.VCTools is the C++ workload in the Visual Studio Build Tools
    # --wait makes the install synchronous
    winget install Microsoft.VisualStudio.2022.BuildTools --silent --override "--wait --addProductLang En-us --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --remove Microsoft.VisualStudio.Component.VC.CMake.Project"
}

function Set-GitHooks {
    Write-Host -ForegroundColor Cyan "`nSetting Git hooks"

    $GitRoot = (Resolve-Path (&git -C $PSScriptRoot rev-parse --show-toplevel)).Path
    $HookDestDir = Join-Path $GitRoot "\.git\hooks" -Resolve
    $GitHooks = @{"pre-commit-wrapper.sh" = "pre-commit" }
    foreach ($i in $GitHooks.GetEnumerator()) {
        $HookSrc = Join-Path $GitRoot $i.Name -Resolve
        $HookDest = Join-Path $HookDestDir $i.Value

        # If the destination doesn't exist or is different than the one in the source, we'll copy it over.
        if (-not (Test-Path $HookDest) -or (Get-FileHash $HookDest).Hash -ne (Get-FileHash $HookSrc).Hash) {
            Copy-Item -Path $HookSrc -Destination $HookDest -Force | Out-Null
            Write-Host -ForegroundColor Cyan "Setup git $($i.Value) hook with $HookSrc"
        }
    }
}

function Set-Aliases {
    Write-Host -ForegroundColor Cyan "`nSetting aliases"

    $PythonScriptsDir = python -c 'import os,sysconfig;print(sysconfig.get_path("scripts",f"{os.name}_user"))'

    $Aliases = [ordered]@{
        "clang-format" = "$PythonScriptsDir\clang-format.exe"
        "cmake-format" = "$PythonScriptsDir\cmake-format.exe"
    }
    foreach ($i in $Aliases.GetEnumerator()) {
        $Alias = $i.Name
        $Target = $i.Value

        # If the alias doesn't exist or is set to something different than the one we want to target, we'll add it.
        if (!(Get-Alias $Alias -ErrorAction SilentlyContinue) -or (Get-Alias $Alias).Definition -ne $Target) {
            New-Alias -Name "$Alias" -Value "$Target" -Scope Global
            Write-Host "  Setup alias $Alias"
        }
    }
}

Install-Python
Install-PipDependencies
Install-CMake
Install-CppBuildTools
Set-GitHooks
Set-Aliases