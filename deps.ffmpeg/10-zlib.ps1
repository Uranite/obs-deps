param(
    [string] $Name = 'zlib',
    [string] $Version = 'f9dd6009be3ed32415edf1e89d1bc38380ecb95d',
    [string] $Uri = 'https://github.com/madler/zlib.git',
    [string] $Hash = "f9dd6009be3ed32415edf1e89d1bc38380ecb95d",
    [array] $Targets = @('x64', 'arm64')
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

function Configure {
    Log-Information "Configure (${Target})"
    Set-Location $Path

    $Options = @(
        $CmakeOptions
        '-DZ_HAVE_UNISTD_H:BOOL=OFF'
        '-DZLIB_BUILD_TESTING:BOOL=OFF'
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

function Fixup {
    Log-Information "Fixup (${Target})"
    Set-Location $Path

    $LibPath = "$($script:ConfigData.OutputPath)/lib"
    if ( Test-Path "$LibPath/zs.lib" ) {
        Move-Item -Path "$LibPath/zs.lib" -Destination "$LibPath/zlib.lib" -Force
    }
}
