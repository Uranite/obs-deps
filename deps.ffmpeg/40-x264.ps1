param(
    [string] $Name = 'x264',
    [string] $Version = '0480cb05fa188d37ae87e8f4fd8f1aea3711f7ee',
    [string] $Uri = 'https://code.videolan.org/videolan/x264.git',
    [string] $Hash = '0480cb05fa188d37ae87e8f4fd8f1aea3711f7ee',
    [array] $Targets = @('x64', 'arm64'),
    [switch] $ForceShared = $true
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path

    if ( ! ( $SkipAll -or $SkipDeps ) ) {
        if ( $Target -ne 'arm64' ) {
            Invoke-External pacman.exe -S --noconfirm --needed --noprogressbar nasm
        }
        Invoke-External pacman.exe -S --noconfirm --needed --noprogressbar make
    }

    if ( $Target -eq 'arm64' ) {
        Remove-Item -Path "${Path}/tools/gas-preprocessor.pl" -ErrorAction SilentlyContinue
        Copy-Item -Path "$($script:WorkRoot)/gas-preprocessor/gas-preprocessor.pl" -Destination "${Path}/tools/"
    }
}

function Clean {
    Set-Location $Path
    if ( Test-Path "build_${Target}" ) {
        Log-Information "Clean build directory (${Target})"
        Remove-Item -Path "build_${Target}" -Recurse -Force
    }
}

function Configure {
    Log-Information "Configure (${Target})"
    Set-Location $Path

    $TargetCPUs = @{
        x64 = 'x86_64'
        x86 = 'x86'
        arm64 = 'aarch64'
    }

    if ( $ForceShared -and ( $script:Shared -eq $false ) ) {
        $Shared = $true
    } else {
        $Shared = $script:Shared.isPresent
    }

    New-Item -ItemType Directory -Force "build_${Target}" > $null

    $ConfigureCommand = @(
        'bash'
        '../configure'
        ('--host=' + $($TargetCPUs[$Target]) + '-mingw64')
        ('--prefix="' + $($script:ConfigData.OutputPath -replace '([A-Fa-f]):','/$1' -replace '\\','/') + '"')
        '--enable-static'
        '--enable-pic'
        '--disable-lsmash'
        '--disable-avs'
        '--disable-gpac'
        '--disable-interlaced'
        '--disable-cli'
        '--enable-lto'
        $(if ( $Shared ) { '--enable-shared' })
        $(if ( $Configuration -match '(Debug|RelWithDebInfo)' ) { '--enable-debug' })
    )

    $Params = @{
        BasePath = (Get-Location | Convert-Path)
        BuildPath = "build_${Target}"
        BuildCommand = $($ConfigureCommand -join ' ')
        Target = $Target
    }

    $clangTarget = if ($Target -eq 'arm64') { 'aarch64-pc-windows-msvc' } elseif ($Target -eq 'x86') { 'i686-pc-windows-msvc' } else { 'x86_64-pc-windows-msvc' }
    Set-Content -Path "build_${Target}/cl" -Value "#!/bin/bash`nexec clang-cl --target=$clangTarget `"`$@`""
    
    $Backup = @{
        PATH = $env:PATH
        CC = $env:CC
        CFLAGS = $env:CFLAGS
        CXXFLAGS = $env:CXXFLAGS
        MSYS2_PATH_TYPE = $env:MSYS2_PATH_TYPE
    }
    $env:PATH = "$((Get-Item "build_${Target}").FullName -replace '\\','/');$env:PATH"
    $env:CC = "cl"
    $env:CFLAGS = $($($script:CFlags) + ' -wd4003')
    $env:CXXFLAGS = $($($script:CxxFlags) + ' -wd4003')
    $env:MSYS2_PATH_TYPE = 'inherit'
    Invoke-DevShell @Params
    $Backup.GetEnumerator() | ForEach-Object { Set-Item -Path "env:\$($_.Key)" -Value $_.Value }
}

function Build {
    Log-Information "Build (${Target})"
    Set-Location $Path

    $Params = @{
        BasePath = (Get-Location | Convert-Path)
        BuildPath = "build_${Target}"
        BuildCommand = "make -j${env:NUMBER_OF_PROCESSORS}"
        Target = $Target
    }

    $Backup = @{
        PATH = $env:PATH
        MSYS2_PATH_TYPE = $env:MSYS2_PATH_TYPE
        VERBOSE = $env:VERBOSE
    }
    $env:PATH = "$((Get-Item "build_${Target}").FullName -replace '\\','/');$env:PATH"
    $env:MSYS2_PATH_TYPE = 'inherit'
    $env:VERBOSE = $(if ( $VerbosePreference -eq 'Continue' ) { '1' })
    Invoke-DevShell @Params
    $Backup.GetEnumerator() | ForEach-Object { Set-Item -Path "env:\$($_.Key)" -Value $_.Value }
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location $Path

    $Params = @{
        BasePath = (Get-Location | Convert-Path)
        BuildPath = "build_${Target}"
        BuildCommand = "make install"
        Target = $Target
    }

    $Backup = @{
        PATH = $env:PATH
        MSYS2_PATH_TYPE = $env:MSYS2_PATH_TYPE
        VERBOSE = $env:VERBOSE
    }
    $env:PATH = "$((Get-Item "build_${Target}").FullName -replace '\\','/');$env:PATH"
    $env:MSYS2_PATH_TYPE = 'inherit'
    $env:VERBOSE = $(if ( $VerbosePreference -eq 'Continue' ) { '1' })
    Invoke-DevShell @Params
    $Backup.GetEnumerator() | ForEach-Object { Set-Item -Path "env:\$($_.Key)" -Value $_.Value }
}

function Fixup {
    Log-Information "Fixup (${Target})"
    Set-Location $Path

   if ( $ForceShared -and ( $script:Shared -eq $false ) ) {
        $Shared = $true
    } else {
        $Shared = $script:Shared.isPresent
    }

    if ( $Shared ) {
        Remove-Item -ErrorAction SilentlyContinue "$($script:ConfigData.OutputPath)/lib/libx264.lib"
        Rename-Item "$($script:ConfigData.OutputPath)/lib/libx264.dll.lib" -NewName "$($script:ConfigData.OutputPath)/lib/libx264.lib"
    }
}
