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

function Patch {
    Log-Information "Patch (${Target})"
    Set-Location $Path

    $gas = Get-Content gas-preprocessor.pl -Raw
    $gas = $gas -replace '@preprocess_c_cmd = grep ! /\^-O/, @preprocess_c_cmd;', '@preprocess_c_cmd = grep ! /^-O/, @preprocess_c_cmd; @preprocess_c_cmd = grep ! /^-flto/, @preprocess_c_cmd; @preprocess_c_cmd = grep ! /^\/clang:/, @preprocess_c_cmd; @preprocess_c_cmd = grep ! /^-march=/, @preprocess_c_cmd;'
    $gas = $gas -replace '@gcc_cmd = grep ! /\^-O/, @gcc_cmd;', '@gcc_cmd = grep ! /^-O/, @gcc_cmd; @gcc_cmd = grep ! /^-flto/, @gcc_cmd; @gcc_cmd = grep ! /^\/clang:/, @gcc_cmd; @gcc_cmd = grep ! /^-march=/, @gcc_cmd;'
    Set-Content -Path gas-preprocessor.pl -Value $gas -NoNewline
}

