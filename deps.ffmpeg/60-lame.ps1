param(
    [string] $Name = 'lame',
    [string] $Version = '3.100',
    [string] $Uri = 'https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz',
    [string] $Hash = "${PSScriptRoot}/checksums/lame-3.100.tar.gz.win.sha256",
    [array] $Targets = @('x64', 'arm64'),
    [array] $Patches = @(
        @{
            PatchFile = "${PSScriptRoot}/patches/lame/0001-fix-nmake-64-bit-builds.patch"
            HashSum = "0772e07d3d0c484d281e3bfdb4f93e81adf303623fe57d955b98196795725f39"
        }
    )
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath .
}

function Clean {
    Set-Location "${Name}-${Version}"

    Get-ChildItem -Recurse -Include 'lame.exe','mp3x.exe','mp3rtp.exe' | Remove-Item
    Get-ChildItem -Recurse -Include 'libmp3lame.*','libmp3lame-static.lib','lame_enc.dll' | Remove-Item
    Get-ChildItem -Recurse -Include 'lame.pdb','icl.pch' | Remove-Item
    Get-ChildItem -Recurse -Include '*.obj','*.res' | Remove-Item
}

function Patch {
    Log-Information "Patch (${Target})"
    Set-Location "${Name}-${Version}"

    $Patches | ForEach-Object {
        $Params = $_
        Safe-Patch @Params
    }
}

function Build {
    Log-Information "Build (${Target})"
    Set-Location "${Name}-${Version}"

    $BuildMachines = @{
        x64 = 'x64'
        x86 = 'I686'
        arm64 = 'arm64'
    }

    $mk = Get-Content "Makefile.MSVC" -Raw
    $mk = $mk -replace '/O2b2ity', '/O2' -replace '/GAy', '' -replace '/Gs1024', '' -replace '/Zp8', ''
    Set-Content "Makefile.MSVC" $mk -NoNewline

    $cfg = Get-Content "configMS.h" -Raw
    $cfg = $cfg -replace '(?m)^\s*typedef\s+(__int\d+|unsigned __int\d+|float|double)\s+(u?int\d+_t|float\d+_t);\s*$', ''
    $cfg = $cfg -replace '(?m)^#define\s+(u?int\d+_t)\s+(signed|unsigned)?\s*(char|short|int|long).*$', ''
    $cfg = "#include <stdint.h>`n" + $cfg
    Set-Content "configMS.h" $cfg -NoNewline

    $clangTarget = if ($Target -eq 'arm64') { 'aarch64-pc-windows-msvc' } elseif ($Target -eq 'x86') { 'i686-pc-windows-msvc' } else { 'x86_64-pc-windows-msvc' }
    $Params = @{
        BasePath = (Get-Location | Convert-Path)
        BuildPath = "."
        BuildCommand = "nmake -f Makefile.MSVC MACHINE=/machine:$($BuildMachines[$Target]) MMX=NO COMP=MS ASM=NO MSVCVER=Win64 CC=`"clang-cl --target=$clangTarget`" LN=link"
        Target = $Target
    }

    if ( $Target -eq 'x86' ) {
        $Params += @{
            HostArchitecture = $Target
        }
    }

    Invoke-DevShell @Params
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location "${Name}-${Version}"

    $Params = @{
        ErrorAction = "SilentlyContinue"
        Path = @(
            "$($ConfigData.OutputPath)/include/lame"
            "$($ConfigData.OutputPath)/lib"
        )
        ItemType = "Directory"
        Force = $true
    }

    New-Item @Params *> $null

    $Items = @(
        @{
            Path = "include/lame.h"
            Destination = "$($ConfigData.OutputPath)/include/lame"
            Recurse = $true
            Force = $true
        },
        @{
            Path = "output/libmp3lame-static.lib"
            Destination = "$($ConfigData.OutputPath)/lib/mp3lame.lib"
            Recurse = $true
            Force = $true
        }
    )

    $Items | ForEach-Object {
        $Item = $_
        Log-Output ('{0} => {1}' -f ($Item.Path -join ", "), $Item.Destination)
        Copy-Item @Item
    }
}
