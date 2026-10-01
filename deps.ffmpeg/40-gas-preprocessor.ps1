param(
    [string] $Name = 'gas-preprocessor',
    [string] $Version = 'ca93666a02f978ac0801e2ae26eee5a385137fd3',
    [string] $Uri = 'https://github.com/FFmpeg/gas-preprocessor.git',
    [string] $Hash = 'ca93666a02f978ac0801e2ae26eee5a385137fd3',
    [array] $Targets = @('arm64')
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path
}

