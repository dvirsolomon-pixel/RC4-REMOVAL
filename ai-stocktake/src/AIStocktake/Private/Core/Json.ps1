# JSON helpers that behave the same on Windows PowerShell 5.1 and PowerShell 7.
#
# Rules (see ARCHITECTURE.md section 4):
# - ConvertTo-Json always gets -Depth 20 (the default of 2 silently truncates).
# - Files are written with [IO.File]::WriteAllText and UTF-8 without BOM.
# - JSONC (comments, trailing commas) is cleaned before ConvertFrom-Json,
#   because 5.1 supports neither.
# - Parse errors are rethrown with a generic message: the original
#   ErrorRecord of ConvertFrom-Json may quote file content (and thus secrets).

$script:AISJsonDepth = 20

function ConvertFrom-AISJsonC {
    <#
    .SYNOPSIS
        Parses JSON or JSONC text (// and /* */ comments, trailing commas).
    .OUTPUTS
        PSCustomObject, array or scalar. Arrays are returned as a single array
        object (not enumerated), also for one-element arrays on PowerShell 7.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string] $Text
    )

    $clean = Remove-AISJsonComment -Text $Text
    if ([string]::IsNullOrWhiteSpace($clean)) {
        throw (New-AISSafeException -Code 'JsonEmpty' -Message 'JSON content is empty.')
    }

    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $result = ConvertFrom-Json -InputObject $clean -NoEnumerate -ErrorAction Stop
        }
        else {
            $result = ConvertFrom-Json -InputObject $clean -ErrorAction Stop
        }
    }
    catch {
        # Never surface the original message: it can quote the content.
        throw (New-AISSafeException -Code 'JsonParseError' -Message 'JSON content could not be parsed.')
    }
    return , $result
}

function Remove-AISJsonComment {
    <#
    .SYNOPSIS
        Removes // and /* */ comments and trailing commas outside of strings.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Text
    )

    if ($Text.Length -gt 0 -and $Text[0] -eq [char]0xFEFF) { $Text = $Text.Substring(1) }

    $sb = New-Object System.Text.StringBuilder -ArgumentList $Text.Length
    $i = 0
    $n = $Text.Length
    $inString = $false
    while ($i -lt $n) {
        $c = $Text[$i]
        if ($inString) {
            [void]$sb.Append($c)
            if ($c -eq '\' -and ($i + 1) -lt $n) {
                [void]$sb.Append($Text[$i + 1])
                $i += 2
                continue
            }
            if ($c -eq '"') { $inString = $false }
            $i++
            continue
        }
        if ($c -eq '"') {
            $inString = $true
            [void]$sb.Append($c)
            $i++
            continue
        }
        if ($c -eq '/' -and ($i + 1) -lt $n) {
            $next = $Text[$i + 1]
            if ($next -eq '/') {
                $i += 2
                while ($i -lt $n -and $Text[$i] -ne "`n" -and $Text[$i] -ne "`r") { $i++ }
                continue
            }
            if ($next -eq '*') {
                $i += 2
                while ($i -lt $n -and -not ($Text[$i] -eq '*' -and ($i + 1) -lt $n -and $Text[$i + 1] -eq '/')) { $i++ }
                $i += 2
                [void]$sb.Append(' ')
                continue
            }
        }
        if ($c -eq ',') {
            # Drop the comma if the next significant character closes a container.
            $j = $i + 1
            $dropped = $false
            while ($j -lt $n) {
                $d = $Text[$j]
                if ([char]::IsWhiteSpace($d)) { $j++; continue }
                if ($d -eq '/' -and ($j + 1) -lt $n -and $Text[$j + 1] -eq '/') {
                    while ($j -lt $n -and $Text[$j] -ne "`n") { $j++ }
                    continue
                }
                if ($d -eq '/' -and ($j + 1) -lt $n -and $Text[$j + 1] -eq '*') {
                    $j += 2
                    while ($j -lt $n -and -not ($Text[$j] -eq '*' -and ($j + 1) -lt $n -and $Text[$j + 1] -eq '/')) { $j++ }
                    $j += 2
                    continue
                }
                if ($d -eq '}' -or $d -eq ']') { $dropped = $true }
                break
            }
            if ($dropped) { $i++; continue }
        }
        [void]$sb.Append($c)
        $i++
    }
    return $sb.ToString()
}

function Read-AISJsonFile {
    <#
    .SYNOPSIS
        Reads and parses a JSON/JSONC file. Errors never contain file content.
    .PARAMETER MaxBytes
        Files larger than this are refused (config files are small; this
        bounds memory and time on unexpected input).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath,

        [long] $MaxBytes = 10MB
    )

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        throw (New-AISSafeException -Code 'FileNotFound' -Message ("File not found: " + $LiteralPath))
    }
    $item = Get-Item -LiteralPath $LiteralPath -Force
    if ($item.Length -gt $MaxBytes) {
        throw (New-AISSafeException -Code 'FileTooLarge' -Message ("File exceeds the size limit: " + $LiteralPath))
    }
    try {
        $text = [System.IO.File]::ReadAllText($item.FullName, [System.Text.Encoding]::UTF8)
    }
    catch {
        throw (New-AISSafeException -Code 'FileReadError' -Message ("File could not be read: " + $LiteralPath))
    }
    try {
        $parsed = ConvertFrom-AISJsonC -Text $text
    }
    catch {
        throw (New-AISSafeException -Code 'JsonParseError' -Message ("File is not valid JSON: " + $LiteralPath))
    }
    return , $parsed
}

function ConvertTo-AISJson {
    <#
    .SYNOPSIS
        ConvertTo-Json with the module-wide depth. Use with plain data
        produced by ConvertTo-AISPlainData for identical 5.1/7 output shape.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowNull()]
        [object] $InputObject,

        [switch] $Compress
    )

    return (ConvertTo-Json -InputObject $InputObject -Depth $script:AISJsonDepth -Compress:$Compress)
}

function Write-AISJsonFile {
    <#
    .SYNOPSIS
        Serializes an object and writes it as UTF-8 without BOM.
    .OUTPUTS
        [string] the full path written.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object] $InputObject
    )

    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LiteralPath)
    $dir = [System.IO.Path]::GetDirectoryName($full)
    if ($dir -and -not [System.IO.Directory]::Exists($dir)) {
        [void][System.IO.Directory]::CreateDirectory($dir)
    }
    $json = ConvertTo-AISJson -InputObject $InputObject
    $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
    [System.IO.File]::WriteAllText($full, $json, $utf8NoBom)
    return $full
}

function ConvertTo-AISPlainData {
    <#
    .SYNOPSIS
        Deep-copies a value into plain JSON-friendly data: ordered dictionaries,
        object arrays, strings, numbers, booleans and $null.
    .DESCRIPTION
        - Hashtables are emitted with sorted keys (deterministic output);
          ordered dictionaries and PSCustomObjects keep their key order.
        - DateTime values become ISO-8601 UTC strings (yyyy-MM-ddTHH:mm:ss.fffZ),
          avoiding the 5.1 "\/Date(...)\/" format.
        - Strings are unwrapped from any PSObject (5.1 would otherwise serialize
          extended properties such as PSPath).
        - -StringTransform is applied to every string value (not to keys); it is
          used by privacy mode.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object] $InputObject,

        [scriptblock] $StringTransform,

        [int] $Depth = 0
    )

    if ($Depth -gt $script:AISJsonDepth) {
        throw (New-AISSafeException -Code 'DepthExceeded' -Message 'Object nesting exceeds the supported depth.')
    }
    if ($null -eq $InputObject) { return $null }

    $value = $InputObject
    if ($value -is [System.Management.Automation.PSObject] -and -not ($value -is [System.Management.Automation.PSCustomObject])) {
        $value = $value.PSObject.BaseObject
    }

    if ($value -is [string]) {
        $s = [string]$value
        if ($StringTransform) { $s = [string](& $StringTransform $s) }
        return $s
    }
    if ($value -is [char] -or $value -is [guid] -or $value -is [enum] -or $value -is [version] -or $value -is [uri]) {
        $s = $value.ToString()
        if ($StringTransform) { $s = [string](& $StringTransform $s) }
        return $s
    }
    if ($value -is [bool]) { return [bool]$value }
    if ($value -is [int] -or $value -is [long] -or $value -is [int16] -or $value -is [byte] -or
        $value -is [uint16] -or $value -is [uint32] -or $value -is [uint64] -or $value -is [sbyte]) {
        return [long]$value
    }
    if ($value -is [double] -or $value -is [single] -or $value -is [decimal]) { return [double]$value }
    if ($value -is [datetime]) {
        return $value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    if ($value -is [datetimeoffset]) {
        return $value.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)
    }

    if ($value -is [System.Collections.IDictionary]) {
        $out = [ordered]@{}
        $keys = @($value.Keys)
        if (-not ($value -is [System.Collections.Specialized.OrderedDictionary])) {
            $keys = @($keys | Sort-Object -Property @{ Expression = { [string]$_ } })
        }
        foreach ($k in $keys) {
            $out[[string]$k] = ConvertTo-AISPlainData -InputObject $value[$k] -StringTransform $StringTransform -Depth ($Depth + 1)
        }
        return $out
    }

    if ($value -is [System.Management.Automation.PSCustomObject]) {
        $out = [ordered]@{}
        foreach ($prop in $value.PSObject.Properties) {
            $out[$prop.Name] = ConvertTo-AISPlainData -InputObject $prop.Value -StringTransform $StringTransform -Depth ($Depth + 1)
        }
        return $out
    }

    if ($value -is [System.Collections.IEnumerable]) {
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($element in $value) {
            $list.Add((ConvertTo-AISPlainData -InputObject $element -StringTransform $StringTransform -Depth ($Depth + 1)))
        }
        return , $list.ToArray()
    }

    $fallback = [string]$value
    if ($StringTransform) { $fallback = [string](& $StringTransform $fallback) }
    return $fallback
}
