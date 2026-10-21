# Hashing: deterministic ids, keyed fingerprints and pseudonyms.
#
# - Deterministic ids (New-AISDeterministicId) are unkeyed SHA-256 over
#   normalized parts, so the same item gets the same id on every scan.
#   In privacy mode the orchestrator re-keys every id (ConvertTo-AISKeyedId)
#   so ids cannot be brute-forced back to user names in paths.
# - Secret fingerprints (New-AISFingerprint) follow ARCHITECTURE.md section 3:
#   "hmac-sha256:" + first 16 hex chars of HMAC-SHA256(key, utf8(value)).
# - Pseudonyms (ConvertTo-AISPseudonym) hide user and host names:
#   "hmac:" + 16 hex chars, with a domain-separation prefix so a pseudonym can
#   never equal a secret fingerprint of the same string.
# - The key is 32 random bytes kept OUTSIDE the repo and OUTSIDE scan output
#   (Get-AISFingerprintKey). Tests pass a generated key.

function Get-AISSha256Hex {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string] $Text
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))
    }
    finally {
        $sha.Dispose()
    }
    return (ConvertTo-AISHex -Bytes $bytes)
}

function ConvertTo-AISHex {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]] $Bytes
    )

    $sb = New-Object System.Text.StringBuilder -ArgumentList ($Bytes.Length * 2)
    foreach ($b in $Bytes) { [void]$sb.Append($b.ToString('x2')) }
    return $sb.ToString()
}

function New-AISDeterministicId {
    <#
    .SYNOPSIS
        Returns a 32 hex char id derived from the given parts.
    .DESCRIPTION
        Parts are joined with U+001F. Each part is trimmed; parts passed via
        -PathParts are normalized with ConvertTo-AISNormalizedPath first, so
        'C:\Users\A\x.json' and 'c:/users/a/x.json' give the same id.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [AllowEmptyString()]
        [string[]] $Parts,

        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]] $PathParts
    )

    $all = New-Object System.Collections.Generic.List[string]
    foreach ($p in $Parts) {
        if ($null -eq $p) { $all.Add('') } else { $all.Add($p.Trim()) }
    }
    foreach ($p in $PathParts) { $all.Add((ConvertTo-AISNormalizedPath -Path $p)) }
    $joined = [string]::Join([string][char]0x1F, $all.ToArray())
    return (Get-AISSha256Hex -Text $joined).Substring(0, 32)
}

function Get-AISHmacHex {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]] $Key,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Text
    )

    if ($Key.Length -lt 16) {
        throw (New-AISSafeException -Code 'KeyTooShort' -Message 'Fingerprint key must be at least 16 bytes.')
    }
    $hmac = New-Object System.Security.Cryptography.HMACSHA256 -ArgumentList (, $Key)
    try {
        $bytes = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))
    }
    finally {
        $hmac.Dispose()
    }
    return (ConvertTo-AISHex -Bytes $bytes)
}

function New-AISFingerprint {
    <#
    .SYNOPSIS
        Keyed fingerprint of a secret value: "hmac-sha256:<16 hex>".
    .DESCRIPTION
        The value is only used to compute the HMAC. It is never logged,
        stored or included in any error message.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]] $Key,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Value
    )

    return ('hmac-sha256:' + (Get-AISHmacHex -Key $Key -Text $Value).Substring(0, 16))
}

function ConvertTo-AISPseudonym {
    <#
    .SYNOPSIS
        Stable keyed pseudonym for an identity (user name, host name): "hmac:<16 hex>".
        Case-insensitive: 'Alice' and 'alice' map to the same pseudonym.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]] $Key,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Value
    )

    return ('hmac:' + (Get-AISHmacHex -Key $Key -Text ('ais-identity:' + $Value.ToLowerInvariant())).Substring(0, 16))
}

function ConvertTo-AISKeyedId {
    <#
    .SYNOPSIS
        Re-keys a deterministic id for privacy mode (32 hex chars).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]] $Key,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Id
    )

    return (Get-AISHmacHex -Key $Key -Text ('ais-id:' + $Id)).Substring(0, 32)
}

function New-AISRandomKey {
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [ValidateRange(16, 64)]
        [int] $Length = 32
    )

    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return , $bytes
}

function Get-AISDefaultKeyPath {
    <#
    .SYNOPSIS
        Default per-install key location: <LocalApplicationData>/AIStocktake/fingerprint.key
        (always the real user folder, never a fixture root).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $local = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData)
    if ([string]::IsNullOrEmpty($local)) {
        $local = Join-Path -Path ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)) -ChildPath '.local/share'
    }
    return (Join-Path -Path (Join-Path -Path $local -ChildPath 'AIStocktake') -ChildPath 'fingerprint.key')
}

function Get-AISFingerprintKey {
    <#
    .SYNOPSIS
        Loads the per-install fingerprint key, creating it on first use when -Create is set.
    .DESCRIPTION
        File format (one line): "AISKEY1 <protection> <base64>".
        - Windows: protection 'dpapi' (DPAPI, CurrentUser scope).
        - Other platforms: protection 'raw', file mode 0600 where supported.
        Creating the key is the only write the scanner performs outside -OutputPath.
    #>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [string] $Path = (Get-AISDefaultKeyPath),

        [switch] $Create
    )

    $entropy = [System.Text.Encoding]::UTF8.GetBytes('AIStocktake.fingerprint.v1')
    $isWindowsHost = ((Get-AISPlatform) -eq 'Windows')

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $line = ([System.IO.File]::ReadAllText($Path)).Trim()
        $parts = $line -split ' '
        if ($parts.Count -ne 3 -or $parts[0] -ne 'AISKEY1') {
            throw (New-AISSafeException -Code 'KeyFileInvalid' -Message ('Fingerprint key file has an unknown format: ' + $Path))
        }
        try {
            $blob = [System.Convert]::FromBase64String($parts[2])
        }
        catch {
            throw (New-AISSafeException -Code 'KeyFileInvalid' -Message ('Fingerprint key file is corrupt: ' + $Path))
        }
        if ($parts[1] -eq 'dpapi') {
            if (-not $isWindowsHost) {
                throw (New-AISSafeException -Code 'KeyFileInvalid' -Message 'DPAPI-protected key files can only be read on Windows.')
            }
            Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
            $key = [System.Security.Cryptography.ProtectedData]::Unprotect($blob, $entropy, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        }
        elseif ($parts[1] -eq 'raw') {
            $key = $blob
        }
        else {
            throw (New-AISSafeException -Code 'KeyFileInvalid' -Message ('Fingerprint key file has an unknown protection: ' + $Path))
        }
        if ($key.Length -lt 16) {
            throw (New-AISSafeException -Code 'KeyFileInvalid' -Message ('Fingerprint key is too short: ' + $Path))
        }
        return , $key
    }

    if (-not $Create) {
        throw (New-AISSafeException -Code 'KeyNotFound' -Message ('Fingerprint key file not found: ' + $Path))
    }

    $key = New-AISRandomKey -Length 32
    $dir = [System.IO.Path]::GetDirectoryName($Path)
    if ($dir -and -not [System.IO.Directory]::Exists($dir)) { [void][System.IO.Directory]::CreateDirectory($dir) }

    if ($isWindowsHost) {
        Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
        $blob = [System.Security.Cryptography.ProtectedData]::Protect($key, $entropy, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        $content = 'AISKEY1 dpapi ' + [System.Convert]::ToBase64String($blob)
    }
    else {
        $content = 'AISKEY1 raw ' + [System.Convert]::ToBase64String($key)
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
    [System.IO.File]::WriteAllText($Path, $content, $utf8NoBom)
    if (-not $isWindowsHost) {
        $setMode = [System.IO.File].GetMethod('SetUnixFileMode', [type[]]@([string], [System.IO.UnixFileMode]))
        if ($null -ne $setMode) {
            [System.IO.File]::SetUnixFileMode($Path, [System.IO.UnixFileMode]'UserRead, UserWrite')
        }
    }
    return , $key
}
