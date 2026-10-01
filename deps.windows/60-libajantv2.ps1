param(
    [string] $Name = 'ntv2',
    [string] $Version = '2d7636d86b6180bb4c5075fea040b1b812cc8b57',
    [string] $Uri = 'https://github.com/aja-video/libajantv2.git',
    [string] $Hash = '2d7636d86b6180bb4c5075fea040b1b812cc8b57',
    [array] $Targets = @('x64'),
    [switch] $ForceStatic = $true,
    [array] $Patches = @(
        @{
            PatchFile = "${PSScriptRoot}/patches/ajantv2/0001-fix-clang-udiv128.patch"
            HashSum = '1e4571a214081b7a369037c6c4b97f435029cdee8282c05c2d112e581b93b758'
        },
        @{
            PatchFile = "${PSScriptRoot}/patches/ajantv2/0002-install-m31-headers.patch"
            HashSum = 'D77DCCB550A1E9C1522ABEAD997C479065ECCCD251393BFF5CBF3B7BA6E222CB'
        },
        @{
            PatchFile = "${PSScriptRoot}/patches/ajantv2/0003-fix-getdeviceinfolist-scoping.patch"
            HashSum = '5E21BCF3D960D469679271F5FEF6CB1445BA3819FB2E5E9CF7A4BBDCFB6B5DFE'
        },
        @{
            PatchFile = "${PSScriptRoot}/patches/ajantv2/0004-export-mbedtls-libs.patch"
            HashSum = '4073B345B818D424C2DD5F2ABC02438B0DE383EF925123275C6271D6AB57FF38'
        }
    )
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path
}

function Patch {
    Log-Information "Patch (${Target})"
    Set-Location $Path

    $Patches | ForEach-Object {
        $Params = $_
        Safe-Patch @Params
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

    if ( $ForceStatic -and $script:Shared ) {
        $Shared = $false
    } else {
        $Shared = $script:Shared.isPresent
    }

    $OnOff = @('OFF', 'ON')
    $Options = @(
        $CmakeOptions
        "-DAJANTV2_BUILD_SHARED:BOOL=$($OnOff[$Shared])"
        '-DAJANTV2_DISABLE_DEMOS:BOOL=ON'
        '-DAJANTV2_DISABLE_DRIVER:BOOL=ON'
        '-DAJANTV2_DISABLE_TESTS:BOOL=ON'
        '-DAJANTV2_DISABLE_TOOLS:BOOL=ON'
        '-DAJANTV2_DISABLE_PLUGINS:BOOL=ON'
        '-DAJA_INSTALL_SOURCES:BOOL=OFF'
        '-DAJA_INSTALL_HEADERS:BOOL=ON'
        '-DAJA_INSTALL_MISC:BOOL=OFF'
        '-DAJA_INSTALL_CMAKE:BOOL=OFF'
    )

    $Backup = @{
        CC = $env:CC
        CXX = $env:CXX
    }
    $env:CC = "clang"
    $env:CXX = "clang++"
    Invoke-External cmake -S . -B "build_${Target}" @Options
    $Backup.GetEnumerator() | ForEach-Object { Set-Item -Path "env:\$($_.Key)" -Value $_.Value }
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

    $Backup = @{
        CC = $env:CC
        CXX = $env:CXX
    }
    $env:CC = "clang"
    $env:CXX = "clang++"
    Invoke-External cmake @Options
    $Backup.GetEnumerator() | ForEach-Object { Set-Item -Path "env:\$($_.Key)" -Value $_.Value }
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

    $Params = @{
        ErrorAction = "SilentlyContinue"
        Path = @(
            "$($ConfigData.OutputPath)/bin"
            "$($ConfigData.OutputPath)/lib"
        )
        ItemType = "Directory"
        Force = $true
    }

    New-Item @Params *> $null

    $Items = @(
        @{
            Path = "$($ConfigData.OutputPath)/lib/ajantv2$(if ( $Configuration -eq 'Debug' ) { 'd' }).lib"
            Destination = "$($ConfigData.OutputPath)/lib"
            Force = $true
        }
    )

    $Items | ForEach-Object {
        $Item = $_
        Log-Output ('{0} => {1}' -f ($Item.Path -join ", "), $Item.Destination)
        Move-Item @Item
    }
}
