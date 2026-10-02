param(
    [string] $Name = 'svt-av1',
    [string] $Version = 'd235cfcc0cfa0a24ec32ea77ec156907921e3a23',
    [string] $Uri = 'https://gitlab.com/AOMediaCodec/SVT-AV1.git',
    [string] $Hash = 'd235cfcc0cfa0a24ec32ea77ec156907921e3a23',
    [array] $Targets = @('x64'),
    [array] $Patches = @(
        @{
            PatchFile = "${PSScriptRoot}/patches/svt-av1/0001-fix-eb-new-macro-trailing-comma.patch"
            HashSum = '2D21D229CE7D61C4DB08EDBDC85EA30D50908525D31743A3BCE59660C0381A10'
        }
    )
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path

    if ( ! ( $SkipAll -or $SkipDeps ) ) {
        Invoke-External pacman.exe -S --noconfirm --needed --noprogressbar nasm
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
}

function Configure {
    Log-Information "Configure (${Target})"
    Set-Location $Path

    $OnOff = @('OFF', 'ON')
    $Options = @(
        $CmakeOptions
        "-DBUILD_SHARED_LIBS:BOOL=$($OnOff[$script:Shared.isPresent])"
        '-DBUILD_APPS:BOOL=OFF'
    )

    Invoke-External cmake -S . -B "build_${Target}" @Options
}

function Build {
    Log-Information "Build (${Target})"
    Set-Location $Path

    $Options = @(
        '--build', "build_${Target}"
        '--config', $Configuration
    )

    if ( $VerbosePreference -eq 'Continue' ) {
        $Options += '--verbose'
    }

    Invoke-External cmake @Options
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location $Path

    $Options = @(
        '--install', "build_${Target}"
        '--config', $Configuration
    )

    if ( $Configuration -match "(Release|MinSizeRel)" ) {
        $Options += '--strip'
    }

    Invoke-External cmake @Options
}
