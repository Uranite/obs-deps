param(
    [string] $Name = 'mbedtls',
    [string] $Version = '3.6.5',
    [string] $Uri = 'https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-3.6.5/mbedtls-3.6.5.tar.bz2',
    [string] $Hash = "${PSScriptRoot}/checksums/mbedtls-${Version}.tar.bz2.win.sha256",
    [array] $Targets = @('x64', 'arm64'),
    [switch] $ForceStatic = $true
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath .
}

function Clean {
    Set-Location "${Name}-${Version}"

    if ( Test-Path "build_${Target}" ) {
        Log-Information "Clean build directory (${Target})"
        Remove-Item -Path "build_${Target}" -Recurse -Force
    }
}

function Patch {
    Log-Information "Patch (${Target})"
    Set-Location "${Name}-${Version}"

    Log-Information "Configuring mbedtls_config.h via scripts/config.py"
    Invoke-External python scripts/config.py set MBEDTLS_SSL_DTLS_SRTP
}

function Configure {
    Log-Information "Configure (${Target})"
    Set-Location "${Name}-${Version}"

    if ( $ForceStatic -and $script:Shared ) {
        $Shared = $false
    } else {
        $Shared = $script:Shared.isPresent
    }

    $OnOff = @('OFF', 'ON')
    $Options = @(
        $CmakeOptions
        "-DUSE_SHARED_MBEDTLS_LIBRARY:BOOL=$($OnOff[$Shared])"
        "-DUSE_STATIC_MBEDTLS_LIBRARY:BOOL=$($OnOff[$Shared -ne $true])"
        '-DENABLE_PROGRAMS:BOOL=OFF'
        '-DENABLE_TESTING:BOOL=OFF'
        '-DGEN_FILES:BOOL=OFF'
    )

    Invoke-External cmake -S . -B "build_${Target}" @Options
}

function Build {
    Log-Information "Build (${Target})"
    Set-Location "${Name}-${Version}"

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
    Set-Location "${Name}-${Version}"

    $Options = @(
        '--install', "build_${Target}"
        '--config', $Configuration
    )

    if ( $Configuration -match "(Release|MinSizeRel)" ) {
        $Options += '--strip'
    }

    Invoke-External cmake @Options
}
