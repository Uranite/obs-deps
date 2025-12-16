param(
    [string] $Name = 'FFmpeg',
    [string] $Version = '8.0',
    [string] $Uri = 'https://github.com/FFmpeg/FFmpeg.git',
    [string] $Hash = "9c93070155903e2c2d08f9f7234a920877903f80",
    [array] $Targets = @('x64', 'arm64'),
    [array] $Patches = @(
        @{
            PatchFile = "${PSScriptRoot}/patches/FFmpeg/0001-flvdec-handle-unknown-Windows.patch"
            HashSum   = "72f41d25f709b1566aecaff0204e94af79d91b7845165deb5bf234440962b2fc"
        }
        @{
            PatchFile = "${PSScriptRoot}/patches/FFmpeg/0002-libaomenc-presets-Windows.patch"
            HashSum   = "cec898b957fc289512094fc2c4e6a61d6872f716e4a643fb970c599a453a33f4"
        }
    )
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path

    if ( ! ( $SkipAll -or $SkipDeps ) ) {
        Invoke-External pacman.exe -S --noconfirm --needed --noprogressbar nasm
        Invoke-External pacman.exe -S --noconfirm --needed --noprogressbar make
        Invoke-External pacman.exe -S --noconfirm --needed --noprogressbar perl
        Invoke-External pacman.exe -S --noconfirm --needed --noprogressbar gcc
        Invoke-External pacman.exe -S --noconfirm --needed --noprogressbar pkgconf
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

    # Fix fftools/resources/graph.html path resolution which fails with missing slash on Windows
    $ResMakefile = "fftools/resources/Makefile"
    if (Test-Path $ResMakefile) {
        Log-Information "Patching fftools/resources/Makefile to fix vpath issue..."
        $Content = Get-Content $ResMakefile
        $NewContent = $Content + @(
            "",
            "# Explicit dependencies and rules to fix vpath resolution/path corruption on Windows",
            "fftools/resources/graph.html.gz: `$(SRC_PATH)/fftools/resources/graph.html",
            "	`$(M)gzip -nc9 `$< > `$@",
            "",
            "fftools/resources/graph.css.min: `$(SRC_PATH)/fftools/resources/graph.css",
            "	`$(M)sed 's!/\\*.*\\*/!!g' `$< | tr '\n' ' ' | tr -s ' ' | sed 's/^ //; s/ `$$//' > `$@",
            "",
            "fftools/resources/graph.css.min.gz: fftools/resources/graph.css.min",
            "	`$(M)gzip -nc9 `$< > `$@"
        )
        $NewContent | Set-Content $ResMakefile
    }
}

function Configure {
    Log-Information "Configure (${Target})"
    Set-Location $Path

    $TargetArch = @{
        x64   = 'x86_64'
        x86   = 'x86'
        arm64 = 'arm64'
    }

    New-Item -ItemType Directory -Force "build_${Target}" > $null

    $ConfigureCommand = @(
        'bash'
        '../configure'
        ('--prefix="' + $($script:ConfigData.OutputPath -replace '([A-Fa-f]):', '/$1' -replace '\\', '/') + '"')
        ('--arch=' + $($TargetArch[$Target]))
        $(if ( $Target -ne $script:HostArchitecture ) { '--enable-cross-compile' })
        '--cc=clang'
        '--cxx=clang'
        ('--extra-cflags=' + "'-D_WINDLL -D_WIN32_WINNT=0x0A00" + $(if ( $Target -eq 'arm64' ) { ' -D__ARM_PCS_VFP' }) + "'")
        ('--extra-cxxflags=' + "'-D_WIN32_WINNT=0x0A00'")
        ('--extra-ldflags=' + "'-fuse-ld=lld -Wl,-APPCONTAINER:NO -Wl,-MACHINE:${Target}'")
        $(if ( $Target -eq 'arm64' ) { '--as=armasm64.exe', '--cpu=armv8' })
        '--pkg-config=pkg-config'
        $(if ( $Target -ne 'x86' ) { '--target-os=win64' } else { '--target-os=win32' })
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
        BasePath     = (Get-Location | Convert-Path)
        BuildPath    = "build_${Target}"
        BuildCommand = $($ConfigureCommand -join ' ')
        Target       = $Target
    }

    $Backup = @{
        CFLAGS            = $env:CFLAGS
        CXXFLAGS          = $env:CXXFLAGS
        PKG_CONFIG_LIBDIR = $env:PKG_CONFIG_LIBDIR
        PKG_CONFIG_PATH   = $env:PKG_CONFIG_PATH
        LDFLAGS           = $env:LDFLAGS
        MSYS2_PATH_TYPE   = $env:MSYS2_PATH_TYPE
        PATH              = $env:PATH
    }
    $env:CFLAGS = "-O3 -DNDEBUG -I$($script:ConfigData.OutputPath -replace '([A-Fa-f]):','/$1' -replace '\\','/')/include"
    $env:CXXFLAGS = "-O3 -DNDEBUG -I$($script:ConfigData.OutputPath -replace '([A-Fa-f]):','/$1' -replace '\\','/')/include"
    $env:PKG_CONFIG_LIBDIR = "$($script:ConfigData.OutputPath -replace '([A-Fa-f]):','/$1' -replace '\\','/')/lib/pkgconfig"
    $env:PKG_CONFIG_PATH = "$($script:ConfigData.OutputPath -replace '([A-Fa-f]):','/$1' -replace '\\','/')/lib/pkgconfig"
    $env:LDFLAGS = "-L$($script:ConfigData.OutputPath -replace '([A-Fa-f]):','/$1' -replace '\\','/')/lib"
    $env:PATH = "$($script:WorkRoot -replace '([A-Fa-f]):','/$1' -replace '\\','/')/gas-preprocessor;${Env:PATH})"
    $env:MSYS2_PATH_TYPE = 'inherit'
    Invoke-DevShell @Params
    $Backup.GetEnumerator() | ForEach-Object { Set-Item -Path "env:\$($_.Key)" -Value $_.Value }
    ($(Get-Content build_${Target}\config.h) -replace '[^\x20-\x7D]+', '') | Set-Content -Path build_${Target}\config.h

    # Patch config.mak to remove -lm from HOSTEXTRALIBS (causes m.lib error on Windows)
    $ConfigMak = "build_${Target}\ffbuild\config.mak"
    if (Test-Path $ConfigMak) {
        Log-Information "Patching config.mak to remove -lm..."
        (Get-Content $ConfigMak) -replace 'HOSTEXTRALIBS=-lm', 'HOSTEXTRALIBS=' | Set-Content $ConfigMak

        Log-Information "Patching config.mak to use explicit paths for internal libraries..."
        # Change LD_LIB=%.lib to LD_LIB=lib%/%.lib to fix linking of internal libs (avutil.lib not found)
        (Get-Content $ConfigMak) -replace 'LD_LIB=%.lib', 'LD_LIB=lib%/%.lib' | Set-Content $ConfigMak

        Log-Information "Disabling resource compression and forcing explicit rules..."
        # 1. Disable compression by clearing the variable (overrides any previous 'yes')
        Add-Content -Path $ConfigMak -Value "CONFIG_RESOURCE_COMPRESSION="

        # 2. Add explicit rules to fftools/resources/Makefile for the uncompressed path
        # This fixes the 'fftoolsresources' path corruption issue in implicit rules
        $ResMakefile = "fftools/resources/Makefile"
        if (Test-Path $ResMakefile) {
            $Rules = @(
                "",
                "# Explicit rules for uncompressed resources (Windows path fix)",
                "fftools/resources/graph.css.min: `$(SRC_PATH)/fftools/resources/graph.css",
                "	`$(M)sed 's!/\\*.*\\*/!!g' `$< | tr '\n' ' ' | tr -s ' ' | sed 's/^ //; s/ `$$//' > `$@",
                "",
                "fftools/resources/graph.css.c: fftools/resources/graph.css.min",
                "	`$(M)`$(BIN2C) `$< `$@ graph_css",
                "",
                "fftools/resources/graph.html.c: `$(SRC_PATH)/fftools/resources/graph.html",
                "	`$(M)`$(BIN2C) `$< `$@ graph_html"
            )
            Add-Content -Path $ResMakefile -Value ($Rules -join "`n")
        }
    }
}

function Build {
    Log-Information "Build (${Target})"
    Set-Location $Path

    $Params = @{
        BasePath     = (Get-Location | Convert-Path)
        BuildPath    = "build_${Target}"
        BuildCommand = "make -j${env:NUMBER_OF_PROCESSORS}"
        Target       = $Target
    }

    $Backup = @{
        MSYS2_PATH_TYPE = $env:MSYS2_PATH_TYPE
        VERBOSE         = $env:VERBOSE
        PATH            = $env:PATH
    }
    $env:MSYS2_PATH_TYPE = 'inherit'
    $env:VERBOSE = $(if ( $VerbosePreference -eq 'Continue' ) { '1' })
    $env:PATH = "$($script:WorkRoot -replace '([A-Fa-f]):','/$1' -replace '\\','/')/gas-preprocessor;${Env:PATH})"
    Invoke-DevShell @Params
    $Backup.GetEnumerator() | ForEach-Object { Set-Item -Path "env:\$($_.Key)" -Value $_.Value }
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location $Path

    $Params = @{
        BasePath     = (Get-Location | Convert-Path)
        BuildPath    = "build_${Target}"
        BuildCommand = "make -r install"
        Target       = $Target
    }

    $Backup = @{
        MSYS2_PATH_TYPE = $env:MSYS2_PATH_TYPE
        VERBOSE         = $env:VERBOSE
    }
    $env:MSYS2_PATH_TYPE = 'inherit'
    $env:VERBOSE = $(if ( $VerbosePreference -eq 'Continue' ) { '1' })
    Invoke-DevShell @Params
    $Backup.GetEnumerator() | ForEach-Object { Set-Item -Path "env:\$($_.Key)" -Value $_.Value }
}
