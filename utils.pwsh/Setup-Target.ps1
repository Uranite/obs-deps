function Setup-Target {
    if ( ! ( Test-Path function:Log-Output ) ) {
        . $PSScriptRoot/Logger.ps1
    }

    $TargetData = @{
        x64 = @{
            Arch = 'x64'
            UnixArch = 'x86_64'
            CmakeArch = 'x64'
            Bitness = '64'
        }
        x86 = @{
            Arch = 'x86'
            UnixArch = 'x86'
            CmakeArch = 'Win32'
            Bitness = '32'
        }
        arm64 = @{
            Arch = 'arm64'
            UnixArch = 'aarch64'
            CmakeArch = 'ARM64'
            Bitness = '64'
        }
    }

    $script:ConfigData = $TargetData[$script:Target]

    $script:ConfigData += @{
        OutputPath = "${script:ProjectRoot}\windows\obs-${script:PackageName}-${script:Target}"
    }

    Log-Debug "
Architecture    : $($script:ConfigData.Arch)
CMake arch      : $($script:ConfigData.CmakeArch)
Unix arch       : $($script:ConfigData.UnixArch)
Target          : $($script:Target)
Output dir      : $($script:ConfigData.OutputPath)
Working dir     : $($script:WorkRoot)
Project dir     : $($script:ProjectRoot)
"
}

function Setup-BuildParameters {
    if ( ! ( Test-Path function:Log-Output ) ) {
        . $PSScriptRoot/Logger.ps1
    }

    $VisualStudioData = Find-VisualStudio

    $VisualStudioId = "Visual Studio {0} {1}" -f @(
        $VisualStudioData.InstallationVersion.Major
        ($VisualStudioData.DisplayName -split ' ')[-1]
    )

    $script:CFlags = @()
    $script:CxxFlags = @()

    switch ( ${script:Configuration} ) {
        Debug {
            $script:CFlags += @('-O0')
            $script:CxxFlags += @('-O0')
        }
        RelWithDebInfo {
            $script:CFlags += @('-O2', '-DNDEBUG')
            $script:CxxFlags += @('-O2', '-DNDEBUG')
        }
        Release {
            $script:CFlags += @('-O2', '-DNDEBUG')
            $script:CxxFlags += @('-O2', '-DNDEBUG')
        }
        MinSizeRel {
            $script:CFlags += @('-O1', '-DNDEBUG')
            $script:CxxFlags += @('-O1', '-DNDEBUG')
        }
    }

    $ClangTargets = @{
        x64 = 'x86_64-pc-windows-msvc'
        x86 = 'i686-pc-windows-msvc'
        arm64 = 'aarch64-pc-windows-msvc'
    }

    $script:ClangTarget = $ClangTargets[$script:Target]
    $script:ClangCl = 'C:/PROGRA~1/LLVM/bin/clang-cl.exe'
    $script:ClangXX = 'C:/PROGRA~1/LLVM/bin/clang-cl.exe'

    $script:CmakeOptions = @(
        '-G', 'Ninja'
        "-DCMAKE_C_COMPILER=$($script:ClangCl)"
        "-DCMAKE_CXX_COMPILER=$($script:ClangXX)"
        "-DCMAKE_C_COMPILER_TARGET=$($script:ClangTarget)"
        "-DCMAKE_CXX_COMPILER_TARGET=$($script:ClangTarget)"
        "-DCMAKE_INSTALL_PREFIX=$($script:ConfigData.OutputPath)"
        "-DCMAKE_PREFIX_PATH=$($script:ConfigData.OutputPath)"
        "-DCMAKE_IGNORE_PREFIX_PATH=C:\Strawberry\c"
        "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded$<$<CONFIG:Debug>:Debug>"
        "-DCMAKE_BUILD_TYPE=${script:Configuration}"
        '--no-warn-unused-cli'
    )

    $script:CMakePostfix = @()

    if ( $script:Quiet ) {
        $script:CmakeOptions += @(
            '-Wno-deprecated', '-Wno-dev', '--log-level=ERROR'
        )
    }

    Log-Debug @"

C flags         : $($script:CFlags)
C++ flags       : $($script:CxxFlags)
CMake options   : $($script:CmakeOptions)
Multi-process   : ${NumProcessors}
"@
}

function Initialize-ClangShim {
    <#
        .SYNOPSIS
            Creates a "cl" shim that forwards to clang-cl for the current target.
        .DESCRIPTION
            Several dependencies build with their own build systems (autotools,
            nmake, msvcbuild.bat) and invoke "cl" directly. Inside a Visual Studio
            Developer Shell that resolves to the real MSVC cl.exe, which would build
            with a different compiler than the CMake-based dependencies use. Writing a
            shim into a shared build directory and prepending it to PATH keeps the
            whole dependency set on one toolchain.
        .EXAMPLE
            Initialize-ClangShim
    #>

    if ( ! ( Test-Path function:Log-Debug ) ) {
        . $PSScriptRoot/Logger.ps1
    }

    $script:ClangShimDir = Join-Path $script:WorkRoot "toolchain"

    if ( ! ( Test-Path $script:ClangShimDir ) ) {
        New-Item -ItemType Directory -Path $script:ClangShimDir -Force | Out-Null
    }

    $ShimPath = Join-Path $script:ClangShimDir 'cl'

    Set-Content -Path $ShimPath -Encoding 'ascii' -NoNewline -Value (
        "#!/bin/bash`n" +
        "exec `"$($script:ClangCl)`" --target=$($script:ClangTarget) `"`$@`"`n"
    )

    $env:PATH = ($ShimPath -replace '\\','/') + ';' + $env:PATH

    Log-Debug "Created clang-cl shim for $($script:ClangTarget) at ${ShimPath}"
}

function Find-VisualStudio {
    <#
        .SYNOPSIS
            Finds available Visual Studio instance.
        .DESCRIPTION
            Uses WMI (Windows Management Instrumentation) to find an installed
            Visual Studio instance on the host system.
        .EXAMPLE
            Find-VisualStudio
    #>

    if ( $env:CI -eq $null ) {
        if ( ( Get-InstalledModule VSSetup ) -eq $null ) {
            Install-Module VSSetup -Scope CurrentUser
        }
    }

    $VisualStudioData = Get-VSSetupInstance -Prerelease:$($script:VSPrerelease) | Select-VSSetupInstance -Version '[16.0,19.0)' -Latest

    if ( $VisualStudioData -eq $null ) {
        $ErrorMessage = @(
            "A Visual Studio installation (2019 or newer) is required for this build script.",
            "The Visual Studio Community edition is available for free at https://visualstudio.microsoft.com/vs/community/.",
            "",
            "If Visual Studio is indeed installed, locate the directory ",
            " 'C:\ProgramData\Microsoft\VisualStudio\Packages\Microsoft.VisualStudio.Setup.WMIProvider,Version=xxxx'",
            " right-click the file 'Microsoft.Visualstudio.Setup.WMIProvider.msi' and choose 'repair'."
        )

        throw $ErrorMessage
    }

    return $VisualStudioData
}
