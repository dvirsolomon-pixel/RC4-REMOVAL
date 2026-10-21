# Path templates and normalization.
#
# Catalog entries and collectors describe locations as templates such as
#   {AppData}\Claude\claude_desktop_config.json
#   {UserProfile}/.cursor/mcp.json
# Resolve-AISPath maps the leading {Token} to a root of the scan context
# (real folders, or folders inside a fixture) and joins the remaining segments
# with Join-Path, so the same template works on Windows and on Linux test runs.

$script:AISRootTokens = @(
    'UserProfile', 'AppData', 'LocalAppData', 'ProgramData',
    'ProgramFiles', 'ProgramFilesX86', 'SystemDrive', 'UsersRoot'
)

function Resolve-AISPath {
    <#
    .SYNOPSIS
        Resolves a path template ({Token}\rest) against a roots table.
    .PARAMETER Template
        Path template. The first segment may be a {Token} naming a root. Both
        '\' and '/' are accepted as separators. A template without a token is
        returned with separators normalized for the current platform.
    .PARAMETER Roots
        Roots table (hashtable/ordered dictionary), usually $Profile.Roots or $Context.Roots.
    .PARAMETER Context
        Scan context; its current-user Roots are used when -Roots is not given.
    .OUTPUTS
        [string] full path. The path is not required to exist.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Template,

        [System.Collections.IDictionary] $Roots,

        [object] $Context
    )

    if (-not $Roots) {
        if (-not $Context) { throw 'Resolve-AISPath requires -Roots or -Context.' }
        $Roots = $Context.Roots
    }

    $segments = @($Template -split '[\\/]+' | Where-Object { $_ -ne '' })
    if ($segments.Count -eq 0) { throw 'Path template is empty.' }

    $base = $null
    $rest = $segments
    $match = [regex]::Match($segments[0], '^\{([A-Za-z0-9]+)\}$')
    if ($match.Success) {
        $token = $match.Groups[1].Value
        if ($script:AISRootTokens -notcontains $token) {
            throw ("Unknown path token '{" + $token + "}'.")
        }
        if (-not $Roots.Contains($token) -or [string]::IsNullOrEmpty([string]$Roots[$token])) {
            throw ("Path root '{" + $token + "}' is not available in this scan context.")
        }
        $base = [string]$Roots[$token]
        $rest = @()
        if ($segments.Count -gt 1) { $rest = $segments[1..($segments.Count - 1)] }
    }
    elseif ($Template -match '\{[A-Za-z0-9]+\}') {
        throw 'Path tokens are only allowed as the first segment of a template.'
    }

    if ($null -eq $base) {
        # No token: keep absolute/relative nature of the input.
        $sep = [System.IO.Path]::DirectorySeparatorChar
        $prefix = ''
        if ($Template -match '^[\\/]') { $prefix = [string]$sep }
        return ($prefix + ($segments -join $sep))
    }

    $path = $base
    foreach ($segment in $rest) {
        $path = Join-Path -Path $path -ChildPath $segment
    }
    return $path
}

function ConvertTo-AISNormalizedPath {
    <#
    .SYNOPSIS
        Canonical form of a path for hashing/comparison: forward slashes,
        no duplicate or trailing separators, lower-case invariant.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Path
    )

    if ([string]::IsNullOrEmpty($Path)) { return '' }
    $p = $Path -replace '[\\/]+', '/'
    if ($p.Length -gt 1) { $p = $p.TrimEnd('/') }
    return $p.ToLowerInvariant()
}
