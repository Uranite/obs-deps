param(
    [string] $Name = 'speexdsp',
    [string] $Version = '1.2.1',
    [string] $Uri = 'https://github.com/xiph/speexdsp.git',
    [string] $Hash = '1b28a0f61bc31162979e1f26f3981fc3637095c8',
    [array] $Targets = @('x64', 'arm64'),
    [array] $Patches = @(
        @{
            PatchFile = "${PSScriptRoot}/patches/speexdsp/0001-Add-CMakeLists.patch"
            HashSum   = '5e384ccc0450822a5d4af7fbb23a845c953e8bec8a493ebdf179febdfe30eb73'
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

    $Options = $CmakeOptions

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
