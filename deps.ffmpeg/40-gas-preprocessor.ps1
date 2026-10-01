param(
    [string] $Name = 'gas-preprocessor',
    [string] $Version = 'ac1836309c2e77023c228b7184485597286289d3',
    [string] $Uri = 'https://github.com/FFmpeg/gas-preprocessor.git',
    [string] $Hash = 'ac1836309c2e77023c228b7184485597286289d3',
    [array] $Targets = @('arm64')
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path
}

