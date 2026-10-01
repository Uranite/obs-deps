param(
    [string] $Name = 'speexdsp',
    [string] $Version = '1.2.1',
    [string] $Uri = 'https://github.com/xiph/speexdsp.git',
    [string] $Hash = '7a158783df74efe7c2d1c6ee8363c1e695c71226',
    [array] $Targets = @('x64', 'arm64'),
    [array] $Patches = @(
        @{
            PatchFile = "${PSScriptRoot}/patches/speexdsp/0001-Add-CMakeLists.patch"
            HashSum = 'e8814dbc5683ce6a3c70553147fbdca92b74aab45ceb06e0040127754fe991c5'
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

    $cml = Get-Content "CMakeLists.txt" -Raw
    $cml = $cml -replace ' /Oi', ''
    Set-Content "CMakeLists.txt" $cml -NoNewline

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
