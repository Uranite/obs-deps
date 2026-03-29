param(
    [string] $Name = 'luajit',
    [string] $Version = '2.1',
    [string] $Uri = 'https://github.com/luajit/luajit.git',
    [string] $Hash = 'a4f56a459a588ae768801074b46ba0adcfb49eb1',
    [array] $Targets = @('x64', 'arm64')
)

function Setup {
    Setup-Dependency -Uri $Uri -Branch v2.1 -Hash $Hash -DestinationPath $Path
}

function Build {
    Log-Information "Build (${Target})"
    Set-Location $Path

    $msvcbuild = Get-Content "src/msvcbuild.bat" -Raw
    $clangTarget = if ($Target -eq 'arm64') { 'aarch64-pc-windows-msvc' } elseif ($Target -eq 'x86') { 'i686-pc-windows-msvc' } else { 'x86_64-pc-windows-msvc' }
    $linkTarget = if ($Target -eq 'arm64') { 'ARM64' } elseif ($Target -eq 'x86') { 'X86' } else { 'X64' }
    $msvcbuild = $msvcbuild -replace '@set LJCOMPILE=cl', "@set LJCOMPILE=clang-cl --target=$clangTarget" -replace '@set LJLINK=link', "@set LJLINK=lld-link /MACHINE:$linkTarget"
    Set-Content "src/msvcbuild.bat" $msvcbuild -NoNewline

    $Params = @{
        BasePath = (Get-Location | Convert-Path)
        BuildPath = "src"
        BuildCommand = "cmd.exe /c 'msvcbuild.bat amalg'"
        Target = $Target
    }

    Invoke-DevShell @Params
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location $Path

    $Params = @{
        Path = "$($ConfigData.OutputPath)/include/luajit"
        ItemType = "Directory"
        Force = $true
    }

    New-Item @Params -ErrorAction SilentlyContinue > $null

    $Items = @(
        @{
            Path = "src/*.h"
            Destination = "$($ConfigData.OutputPath)/include/luajit"
        }
        @{
            Path = "src/lua51.dll"
            Destination = "$($ConfigData.OutputPath)/bin"
        }
        @{
            Path = "src/lua51.lib"
            Destination = "$($ConfigData.OutputPath)/lib"
        }
    )

    $Items | ForEach-Object {
        $Item = $_
        Log-Output ('{0} => {1}' -f ($Item.Path -join ", "), $Item.Destination)
        Copy-Item @Item
    }
}
