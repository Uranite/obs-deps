param(
    [string] $Name = 'libdatachannel',
    [string] $Version = 'v0.21.0',
    [string] $Uri = 'https://github.com/paullouisageneau/libdatachannel.git',
    [string] $Hash = '9d5c46b8f506943727104d766e5dad0693c5a223',
    [array] $Targets = @('x64', 'arm64'),
    [switch] $ForceShared = $true,
    [array] $Patches = @(
        @{
            PatchFile = "${PSScriptRoot}/patches/libdatachannel/0001-fix-usrsctp-compiler-flags.patch"
            HashSum   = "184F319866F302784DA6F1BFB772209C488DF2E0DB91190C37C4E676E0DC9A6B"
        }
    )
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

    if ( $ForceShared -and ( $script:Shared -eq $false ) ) {
        $Shared = $true
    }
    else {
        $Shared = $script:Shared.isPresent
    }

    $OnOff = @('OFF', 'ON')
    $Options = @(
        $CmakeOptions
        "-DBUILD_SHARED_LIBS:BOOL=$($OnOff[$Shared])"
        '-DUSE_MBEDTLS:BOOL=ON'
        '-DNO_WEBSOCKET:BOOL=ON'
        '-DNO_TESTS:BOOL=ON'
        '-DNO_EXAMPLES:BOOL=ON'
        '-DCMAKE_POLICY_VERSION_MINIMUM=3.5'
        "-DCMAKE_CXX_FLAGS='-DNOMINMAX'"
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
