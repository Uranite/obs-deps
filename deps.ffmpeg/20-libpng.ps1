param(
    [string] $Name = 'libpng',
    [string] $Version = 'ef378794235277f3116860c2fa0d356659b05441',
    [string] $Uri = 'https://github.com/pnggroup/libpng.git',
    [string] $Hash = "ef378794235277f3116860c2fa0d356659b05441",
    [array] $Targets = @('x64', 'arm64'),
    [array] $Patches = @()
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path
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
        '-DPNG_TESTS:BOOL=OFF'
        '-DPNG_STATIC:BOOL=ON'
        "-DPNG_SHARED:BOOL=$($OnOff[$script:Shared.isPresent])"
    )


    if ( $Configuration -eq 'Debug' ) {
        $Options += '-DPNG_DEBUG:BOOL=ON'
    } else {
        $Options += '-DPNG_DEBUG:BOOL=OFF'
    }

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

    $Options += @($CmakePostfix)

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
