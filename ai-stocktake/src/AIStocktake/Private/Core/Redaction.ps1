# Privacy mode (-PrivacyMode, alias -RedactUser).
#
# Applied to every string of the final result, after all collectors ran:
#   1. Each scanned profile folder (and the fixture root's Users folder) at
#      the start of a path, or anywhere inside a string, becomes '{UserProfile}'
#      (or '{UsersRoot}').
#   2. Every user name of the scan (current user and scanned profiles) becomes
#      its keyed pseudonym 'hmac:<16 hex>' when it appears as a whole word.
#   3. The host name becomes its keyed pseudonym.
#   4. All ids and inventoryRefs are re-keyed (ConvertTo-AISKeyedId), so they
#      stay stable across scans on the same install but cannot be brute-forced
#      back to paths that contain user names.
# Values that already are hashes (hmac:..., hmac-sha256:..., 32 hex ids) are
# left untouched.

function Get-AISPrivacyRule {
    <#
    .OUTPUTS
        Ordered list of @{ Regex = [regex]; Replacement = [string] }.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [object] $Context)

    $rules = New-Object System.Collections.Generic.List[object]
    $opts = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant

    # 1. Profile folders, longest first so nested paths win.
    $folders = @()
    foreach ($p in $Context.Profiles) {
        if ($p.Roots['UserProfile']) { $folders += @{ Path = [string]$p.Roots['UserProfile']; Token = '{UserProfile}' } }
    }
    if ($Context.Roots['UserProfile']) { $folders += @{ Path = [string]$Context.Roots['UserProfile']; Token = '{UserProfile}' } }
    if ($Context.Roots['UsersRoot']) { $folders += @{ Path = [string]$Context.Roots['UsersRoot']; Token = '{UsersRoot}' } }
    foreach ($f in @($folders | Sort-Object -Property @{ Expression = { $_.Path.Length } } -Descending)) {
        $segments = @($f.Path -split '[\\/]+' | Where-Object { $_ -ne '' })
        if ($segments.Count -eq 0) { continue }
        $escaped = ($segments | ForEach-Object { [regex]::Escape($_) }) -join '[\\/]+'
        $lead = ''
        if ($f.Path -match '^[\\/]') { $lead = '[\\/]+' }
        $pattern = $lead + $escaped + '(?=$|[\\/])'
        $rules.Add(@{ Regex = (New-Object System.Text.RegularExpressions.Regex -ArgumentList $pattern, $opts); Replacement = $f.Token })
    }

    # 2. User names (whole word), 3. host name.
    $names = @()
    foreach ($p in $Context.Profiles) { if ($p.Name) { $names += [string]$p.Name } }
    if ($Context.UserName) { $names += [string]$Context.UserName }
    $names = @($names | Sort-Object -Property Length -Descending -Unique)
    $identities = @()
    foreach ($n in $names) { $identities += $n }
    if ($Context.HostName) { $identities += [string]$Context.HostName }
    foreach ($id in $identities) {
        $pattern = '(?<![A-Za-z0-9_])' + [regex]::Escape($id) + '(?![A-Za-z0-9_])'
        $rules.Add(@{
                Regex       = (New-Object System.Text.RegularExpressions.Regex -ArgumentList $pattern, $opts)
                Replacement = (ConvertTo-AISPseudonym -Key $Context.FingerprintKey -Value $id)
            })
    }
    return , $rules.ToArray()
}

function Protect-AISString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()] [AllowEmptyString()] [string] $Text,
        [object[]] $Rules
    )

    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    if ($Text -cmatch '^(hmac|hmac-sha256):[0-9a-f]+$' -or $Text -cmatch '^[0-9a-f]{32}$') { return $Text }
    $s = $Text
    foreach ($r in $Rules) {
        # Replacement strings contain no '$' so they are literal.
        $s = $r.Regex.Replace($s, $r.Replacement)
    }
    return $s
}
