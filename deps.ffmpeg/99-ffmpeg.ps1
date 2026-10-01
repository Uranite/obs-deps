param(
    [string] $Name = 'FFmpeg',
    [string] $Version = 'e54e1179985145a2e0a5be9ee9000384ee58b7a5',
    [string] $Uri = 'https://github.com/FFmpeg/FFmpeg.git',
    [string] $Hash = "e54e1179985145a2e0a5be9ee9000384ee58b7a5",
    [array] $Targets = @('x64', 'arm64'),
    [array] $Patches = @(
        @{
            PatchFile = "${PSScriptRoot}/patches/FFmpeg/0001-flvdec-handle-unknown-Windows.patch"
            HashSum = "72f41d25f709b1566aecaff0204e94af79d91b7845165deb5bf234440962b2fc"
        }
        @{
            PatchFile = "${PSScriptRoot}/patches/FFmpeg/0002-libaomenc-presets-Windows.patch"
            HashSum = "cec898b957fc289512094fc2c4e6a61d6872f716e4a643fb970c599a453a33f4"
        }
    )
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path

    if ( ! ( $SkipAll -or $SkipDeps ) ) {
        Invoke-External pacman.exe -S --noconfirm --needed --noprogressbar nasm make perl gcc pkgconf
    }
}

function Clean {
    Set-Location $Path

    if ( Test-Path "build_${Target}" ) {
        Log-Information "Clean build directory (${Target})"
        Remove-Item -Path "build_${Target}" -Recurse -Force
    }
}

function Patch {
    Log-Information "Patch (${Target})"
    Set-Location $Path

    $Patches | ForEach-Object {
        $Params = $_
        Safe-Patch @Params
    }

    $configure = Get-Content configure -Raw
    $configure = $configure -replace 'if test "\$cc_type" = "clang"; then', 'if true; then'
    $configure = $configure -replace 'test "\$cc_type" != "\$ld_type" && die "LTO requires same compiler and linker"', 'true'
    $configure = $configure -replace 'mingw32\|win32\)', 'mingw32|win32|win64|arm64)'
    $configure = $configure -replace "SLIB_CREATE_DEF_CMD='LDFLAGS", "SLIB_CREATE_DEF_CMD='AR=""`$(AR_CMD)"" NM=""`$(NM_CMD)"" LDFLAGS"
    Set-Content -Path configure -Value $configure -NoNewline
}

function Configure {
    Log-Information "Configure (${Target})"
    Set-Location $Path

    $TargetArch = @{
        x64 = 'x86_64'
        x86 = 'x86'
        arm64 = 'arm64'
    }

    New-Item -ItemType Directory -Force "build_${Target}" > $null

    $ConfigureCommand = @(
        'bash'
        '../configure'
        ('--prefix="' + $($script:ConfigData.OutputPath -replace '([A-Fa-f]):','/$1' -replace '\\','/') + '"')
        ('--arch=' + $($TargetArch[$Target]))
        $(if ( $Target -ne $script:HostArchitecture ) { '--enable-cross-compile' })
        '--toolchain=msvc'
        $clangTarget = if ($Target -eq 'arm64') { 'aarch64-pc-windows-msvc' } elseif ($Target -eq 'x86') { 'i686-pc-windows-msvc' } else { 'x86_64-pc-windows-msvc' }
        ('--cc="C:/PROGRA~1/LLVM/bin/clang-cl.exe --target=' + $clangTarget + '"')
        ('--cxx="C:/PROGRA~1/LLVM/bin/clang-cl.exe --target=' + $clangTarget + '"')
        ('--extra-cflags=' + "'-D_WINDLL -MD -D_WIN32_WINNT=0x0A00" + $(if ( $Target -eq 'arm64' ) { ' -D__ARM_PCS_VFP' }) + "'")
        ('--extra-cxxflags=' + "'-MD -D_WIN32_WINNT=0x0A00'")
        ('--extra-ldflags=' + "'-APPCONTAINER:NO -MACHINE:${Target}'")
        "--ar=C:/PROGRA~1/LLVM/bin/llvm-ar.exe"
        "--nm=C:/PROGRA~1/LLVM/bin/llvm-nm.exe"
        "--ld=C:/PROGRA~1/LLVM/bin/lld-link.exe"
        $(if ( $Target -eq 'arm64' ) { '--as=armasm64.exe','--cpu=armv8' })
        '--pkg-config=pkg-config'
        $(if ( $Target -ne 'x86' ) { '--target-os=win64' } else { '--target-os=win32' })
        '--enable-lto=thin'
        $(if ( $Target -eq 'x64' ) { '--enable-libaom' })
        $(if ( $Target -eq 'x64' ) { '--enable-libsvtav1' })
        '--enable-libtheora'
        '--enable-libmp3lame'
        '--enable-w32threads'
        '--enable-version3'
        '--enable-gpl'
        '--enable-libx264'
        '--enable-libopus'
        '--enable-libvorbis'
        '--enable-libvpx'
        '--enable-librist'
        '--enable-libsrt'
        '--enable-shared'
        '--enable-zlib'
        '--disable-static'
        '--disable-libjack'
        '--disable-indev=jack'
        '--disable-sdl2'
        '--disable-doc'
        $(if ( ! $script:Shared ) { ('--pkg-config-flags=' + "'--static'") })
        $(if ( $Configuration -eq 'Debug' ) { '--enable-debug' } else { '--disable-debug' })
        $(if ( $Configuration -eq 'RelWithDebInfo' ) { '--disable-stripping' })
    )

    $Params = @{
        BasePath = (Get-Location | Convert-Path)
        BuildPath = "build_${Target}"
        BuildCommand = $($ConfigureCommand -join ' ')
        Target = $Target
    }

    $Backup = @{
        CC = $env:CC
        CXX = $env:CXX
        CFLAGS = $env:CFLAGS
        CXXFLAGS = $env:CXXFLAGS
        PKG_CONFIG_LIBDIR = $env:PKG_CONFIG_LIBDIR
        LDFLAGS = $env:LDFLAGS
        MSYS2_PATH_TYPE = $env:MSYS2_PATH_TYPE
        PATH = $env:PATH
    }
    $clangTarget = if ($Target -eq 'arm64') { 'aarch64-pc-windows-msvc' } elseif ($Target -eq 'x86') { 'i686-pc-windows-msvc' } else { 'x86_64-pc-windows-msvc' }
    $env:CC = "C:/PROGRA~1/LLVM/bin/clang-cl.exe --target=$clangTarget"
    $env:CXX = "C:/PROGRA~1/LLVM/bin/clang-cl.exe --target=$clangTarget"
    $env:CFLAGS = "$($script:CFlags) -I$($script:ConfigData.OutputPath -replace '([A-Fa-f]):','/$1' -replace '\\','/')/include"
    $env:CXXFLAGS = "$($script:CxxFlags) -I$($script:ConfigData.OutputPath -replace '([A-Fa-f]):','/$1' -replace '\\','/')/include"
    $env:PKG_CONFIG_LIBDIR = "$($script:ConfigData.OutputPath -replace '([A-Fa-f]):','/$1' -replace '\\','/')/lib/pkgconfig"
    $env:LDFLAGS = "-LIBPATH:$($script:ConfigData.OutputPath -replace '([A-Fa-f]):','/$1' -replace '\\','/')/lib"
    $env:PATH = "$($script:WorkRoot -replace '([A-Fa-f]):','/$1' -replace '\\','/')/gas-preprocessor;$env:PATH"
    $env:MSYS2_PATH_TYPE = 'inherit'
    Invoke-DevShell @Params
    $Backup.GetEnumerator() | ForEach-Object { Set-Item -Path "env:\$($_.Key)" -Value $_.Value }
    ($(Get-Content build_${Target}\config.h) -replace '[^\x20-\x7D]+', '') | Set-Content -Path build_${Target}\config.h
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
        MSYS2_PATH_TYPE = $env:MSYS2_PATH_TYPE
        VERBOSE = $env:VERBOSE
        PATH = $env:PATH
    }
    $env:MSYS2_PATH_TYPE = 'inherit'
    $env:VERBOSE = $(if ( $VerbosePreference -eq 'Continue' ) { '1' })
    $env:PATH = "$($script:WorkRoot -replace '([A-Fa-f]):','/$1' -replace '\\','/')/gas-preprocessor;$env:PATH"
    Invoke-DevShell @Params
    $Backup.GetEnumerator() | ForEach-Object { Set-Item -Path "env:\$($_.Key)" -Value $_.Value }
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location $Path

    $Params = @{
        BasePath = (Get-Location | Convert-Path)
        BuildPath = "build_${Target}"
        BuildCommand = "make -r install"
        Target = $Target
    }

    $Backup = @{
        MSYS2_PATH_TYPE = $env:MSYS2_PATH_TYPE
        VERBOSE = $env:VERBOSE
    }
    $env:MSYS2_PATH_TYPE = 'inherit'
    $env:VERBOSE = $(if ( $VerbosePreference -eq 'Continue' ) { '1' })
    Invoke-DevShell @Params
    $Backup.GetEnumerator() | ForEach-Object { Set-Item -Path "env:\$($_.Key)" -Value $_.Value }
}
