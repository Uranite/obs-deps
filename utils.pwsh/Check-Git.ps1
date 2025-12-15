function Check-Git {
    <#
        .SYNOPSIS
            Ensures available git executable on host system.
        .DESCRIPTION
            Checks whether a git command is available on the host system. If none is found,
            Git is installed via winget.
        .EXAMPLE
            Check-Git
    #>

    if ( ! ( Test-Path function:Log-Information ) ) {
        . $PSScriptRoot/Logger.ps1
    }

    Log-Information 'Check for Git executable'

    if ( ! ( Get-Command git ) ) {
        Log-Warning 'No Git executable found. Will try to install via winget...'
        winget install git
    }
    else {
        Log-Debug "Git found at $(Get-Command git)"
        Log-Status "Git found"
    }
}

function Get-GitUnixBinPath {
    if ( Get-Command git -ErrorAction SilentlyContinue ) {
        try {
            $GitExecPath = (git --exec-path).Trim()
            $GitRoot = $GitExecPath | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
            $UnixBin = Join-Path $GitRoot "usr\bin"
            
            if ( Test-Path $UnixBin ) {
                return $UnixBin
            }
        }
        catch {
            Write-Verbose "Could not determine git exec path: $_"
        }
    }

    # Fallback to relative path from executable (works for standard installs)
    try {
        return (Resolve-Path -Path "$((Get-Command git).Source | Split-Path)\..\usr\bin" -ErrorAction SilentlyContinue).Path
    }
    catch {
        return $null
    }
}
