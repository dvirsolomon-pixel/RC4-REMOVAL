# Standard objects emitted by collectors (ARCHITECTURE.md section 2.3).
#
# Collectors MUST create output only through these factories. The orchestrator
# routes collector output by PSTypeName:
#   AIS.InventoryItem -> inventory[]   AIS.Finding   -> findings[]
#   AIS.SecretFinding -> secrets[]     AIS.ScanError -> errors[]
# Field names and limits mirror schema/scan-result.v1.schema.json.

$script:AISInventoryKinds = @('app', 'agent', 'extension', 'mcp-server', 'runtime', 'host')
$script:AISScopes = @('user', 'machine')
$script:AISSources = @('registry', 'file', 'process', 'port', 'system')
$script:AISSeverities = @('info', 'low', 'medium', 'high', 'critical')
$script:AISLengthBuckets = @('<20', '20-40', '>40')

# Names that must never appear as an inventory property: they invite storing a
# secret value. Compared case-insensitively. Kept in sync with the schema.
$script:AISForbiddenPropertyNames = @(
    'value', 'rawValue', 'raw', 'secret', 'secrets', 'password', 'passwd', 'pwd',
    'token', 'accessToken', 'refreshToken', 'apiKey', 'key', 'privateKey',
    'credential', 'credentials', 'authorization', 'auth', 'cookie', 'connectionString',
    'env', 'headers'
)

$script:AISLimits = @{
    Name = 256; Version = 64; Path = 2048; Title = 200; Detail = 1000; Remediation = 2000
    Reference = 512; PropertyString = 1024; PropertyArray = 100; Properties = 50; Message = 500
    JsonPointer = 512; Type = 64
}

function Limit-AISString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Text,

        [Parameter(Mandatory = $true)]
        [int] $MaxLength
    )

    if ($null -eq $Text) { return $null }
    if ($Text.Length -le $MaxLength) { return $Text }
    return $Text.Substring(0, $MaxLength - 3) + '...'
}

function Assert-AISOptionalPattern {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [AllowNull()] [AllowEmptyString()] [string] $Value,
        [Parameter(Mandatory = $true)] [string] $Pattern
    )

    if (-not [string]::IsNullOrEmpty($Value) -and $Value -cnotmatch $Pattern) {
        throw (New-AISSafeException -Code 'InvalidArgument' -Message ("Parameter '" + $Name + "' does not match the required pattern " + $Pattern + '.'))
    }
}

function Assert-AISPropertyBag {
    <#
    .SYNOPSIS
        Validates and copies an inventory property bag: camelCase keys, no
        forbidden names, scalar values or arrays of scalars only.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [System.Collections.IDictionary] $Properties
    )

    $out = [ordered]@{}
    if ($null -eq $Properties) { return $out }
    if ($Properties.Count -gt $script:AISLimits.Properties) {
        throw (New-AISSafeException -Code 'InvalidProperties' -Message ('An inventory item may have at most ' + $script:AISLimits.Properties + ' properties.'))
    }
    $keys = @($Properties.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    foreach ($key in $keys) {
        if ($key -cnotmatch '^[a-z][A-Za-z0-9]{0,63}$') {
            throw (New-AISSafeException -Code 'InvalidPropertyName' -Message ("Inventory property name '" + $key + "' must be camelCase letters and digits."))
        }
        foreach ($forbidden in $script:AISForbiddenPropertyNames) {
            if ($key -ieq $forbidden) {
                throw (New-AISSafeException -Code 'ForbiddenPropertyName' -Message ("Inventory property name '" + $key + "' is not allowed because it could carry a secret value."))
            }
        }
        $out[$key] = ConvertTo-AISPropertyValue -Value $Properties[$key] -Name $key
    }
    return $out
}

function ConvertTo-AISPropertyValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Value,

        [string] $Name,

        [switch] $NoArray
    )

    if ($null -eq $Value) { return $null }
    if ($Value -is [System.Management.Automation.PSObject] -and -not ($Value -is [System.Management.Automation.PSCustomObject])) {
        $Value = $Value.PSObject.BaseObject
    }
    if ($Value -is [string] -or $Value -is [char] -or $Value -is [version] -or $Value -is [enum] -or $Value -is [guid]) {
        return (Limit-AISString -Text ([string]$Value) -MaxLength $script:AISLimits.PropertyString)
    }
    if ($Value -is [bool]) { return [bool]$Value }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [int16] -or $Value -is [byte] -or $Value -is [uint32] -or $Value -is [uint64] -or $Value -is [uint16]) { return [long]$Value }
    if ($Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) { return [double]$Value }
    if ($Value -is [datetime]) { return (ConvertTo-AISPlainData -InputObject $Value) }
    if (-not $NoArray -and -not ($Value -is [System.Collections.IDictionary]) -and -not ($Value -is [System.Management.Automation.PSCustomObject]) -and $Value -is [System.Collections.IEnumerable]) {
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($element in $Value) {
            if ($list.Count -ge $script:AISLimits.PropertyArray) { break }
            $list.Add((ConvertTo-AISPropertyValue -Value $element -Name $Name -NoArray))
        }
        return , $list.ToArray()
    }
    throw (New-AISSafeException -Code 'InvalidPropertyValue' -Message ("Inventory property '" + $Name + "' must be a string, number, boolean or an array of those."))
}

function New-AISInventoryItem {
    <#
    .SYNOPSIS
        Creates an AIS.InventoryItem with a deterministic id.
    .DESCRIPTION
        id = New-AISDeterministicId over (kind, toolId, scope, profile, name) and
        the normalized path. Pass -IdDiscriminator when several items share all
        of these (for example two MCP servers in one config: use the server name).
    .PARAMETER Properties
        Small allowlisted facts (camelCase keys; string/number/bool or arrays of
        them). Never copy raw configuration objects here. Names that could carry
        secrets (value, token, password, env, headers, ...) are rejected.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('app', 'agent', 'extension', 'mcp-server', 'runtime', 'host')]
        [string] $Kind,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $ToolId,

        [string] $Version,

        [ValidateSet('user', 'machine')]
        [string] $Scope = 'user',

        [string] $UserProfileName,

        [ValidateSet('registry', 'file', 'process', 'port', 'system')]
        [string] $Source = 'file',

        [string] $Path,

        [System.Collections.IDictionary] $Properties,

        [string] $IdDiscriminator
    )

    Assert-AISOptionalPattern -Name 'ToolId' -Value $ToolId -Pattern '^[a-z0-9][a-z0-9._-]{0,63}$'
    $id = New-AISDeterministicId -Parts @('inventory', $Kind, $ToolId, $Scope, $UserProfileName, $Name, $IdDiscriminator) -PathParts @($Path)
    $item = [ordered]@{
        id         = $id
        kind       = $Kind
        toolId     = $(if ($ToolId) { $ToolId } else { $null })
        name       = (Limit-AISString -Text $Name -MaxLength $script:AISLimits.Name)
        version    = $(if ($Version) { Limit-AISString -Text $Version -MaxLength $script:AISLimits.Version } else { $null })
        scope      = $Scope
        profile    = $(if ($UserProfileName) { $UserProfileName } else { $null })
        source     = $Source
        path       = $(if ($Path) { Limit-AISString -Text $Path -MaxLength $script:AISLimits.Path } else { $null })
        properties = (Assert-AISPropertyBag -Properties $Properties)
    }
    $obj = New-Object -TypeName PSObject -Property $item
    $obj.PSObject.TypeNames.Insert(0, 'AIS.InventoryItem')
    return $obj
}

function New-AISFinding {
    <#
    .SYNOPSIS
        Creates an AIS.Finding with a deterministic id.
    .DESCRIPTION
        id = New-AISDeterministicId over (ruleId, jsonPointer, discriminator) and
        the normalized evidence path. -Detail must never contain secret values
        or unredacted command lines.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Z]{2,5}-[A-Z0-9]{2,10}-[0-9]{3}$')]
        [string] $RuleId,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-z][a-z0-9-]{1,40}$')]
        [string] $Category,

        [Parameter(Mandatory = $true)]
        [ValidateSet('info', 'low', 'medium', 'high', 'critical')]
        [string] $Severity,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Title,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $ToolId,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $InventoryRef,

        [string] $EvidencePath,

        [string] $JsonPointer,

        [string] $Detail,

        [string] $Remediation,

        [string[]] $References,

        [string] $IdDiscriminator
    )

    Assert-AISOptionalPattern -Name 'ToolId' -Value $ToolId -Pattern '^[a-z0-9][a-z0-9._-]{0,63}$'
    Assert-AISOptionalPattern -Name 'InventoryRef' -Value $InventoryRef -Pattern '^[0-9a-f]{32}$'
    $id = New-AISDeterministicId -Parts @('finding', $RuleId, $JsonPointer, $IdDiscriminator) -PathParts @($EvidencePath)
    $refs = @()
    foreach ($r in $References) {
        if (-not [string]::IsNullOrEmpty($r)) { $refs += (Limit-AISString -Text $r -MaxLength $script:AISLimits.Reference) }
    }
    $item = [ordered]@{
        id           = $id
        ruleId       = $RuleId
        category     = $Category
        severity     = $Severity
        title        = (Limit-AISString -Text $Title -MaxLength $script:AISLimits.Title)
        toolId       = $(if ($ToolId) { $ToolId } else { $null })
        inventoryRef = $(if ($InventoryRef) { $InventoryRef } else { $null })
        evidence     = [ordered]@{
            path        = $(if ($EvidencePath) { Limit-AISString -Text $EvidencePath -MaxLength $script:AISLimits.Path } else { $null })
            jsonPointer = $(if ($JsonPointer) { Limit-AISString -Text $JsonPointer -MaxLength $script:AISLimits.JsonPointer } else { $null })
            detail      = $(if ($Detail) { Limit-AISString -Text $Detail -MaxLength $script:AISLimits.Detail } else { $null })
        }
        remediation  = $(if ($Remediation) { Limit-AISString -Text $Remediation -MaxLength $script:AISLimits.Remediation } else { $null })
        references   = $refs
    }
    $obj = New-Object -TypeName PSObject -Property $item
    $obj.PSObject.TypeNames.Insert(0, 'AIS.Finding')
    return $obj
}

function New-AISSecretFinding {
    <#
    .SYNOPSIS
        Creates an AIS.SecretFinding. Takes a fingerprint, never a raw value.
    .DESCRIPTION
        Compute -Fingerprint with New-AISFingerprint inside the detector and
        drop the raw value immediately. -KnownPrefix may only hold the PUBLIC
        prefix of the pattern (for example 'ghp_'), never characters of the
        secret part.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-z0-9][a-z0-9_-]{0,63}$')]
        [string] $Type,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^hmac-sha256:[0-9a-f]{16}$')]
        [string] $Fingerprint,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Z]{2,5}-[A-Z0-9]{2,10}-[0-9]{3}$')]
        [string] $RuleId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [string] $JsonPointer,

        [Parameter(Mandatory = $true)]
        [ValidateSet('<20', '20-40', '>40')]
        [string] $LengthBucket,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $KnownPrefix,

        [AllowNull()]
        [AllowEmptyString()]
        [string] $InventoryRef
    )

    Assert-AISOptionalPattern -Name 'KnownPrefix' -Value $KnownPrefix -Pattern '^[A-Za-z0-9_-]{1,16}$'
    Assert-AISOptionalPattern -Name 'InventoryRef' -Value $InventoryRef -Pattern '^[0-9a-f]{32}$'
    $id = New-AISDeterministicId -Parts @('secret', $RuleId, $JsonPointer, $Fingerprint) -PathParts @($Path)
    $item = [ordered]@{
        id           = $id
        type         = $Type
        fp           = $Fingerprint
        ruleId       = $RuleId
        location     = [ordered]@{
            path        = (Limit-AISString -Text $Path -MaxLength $script:AISLimits.Path)
            jsonPointer = $(if ($JsonPointer) { Limit-AISString -Text $JsonPointer -MaxLength $script:AISLimits.JsonPointer } else { $null })
        }
        lengthBucket = $LengthBucket
        knownPrefix  = $(if ($KnownPrefix) { $KnownPrefix } else { $null })
        inventoryRef = $(if ($InventoryRef) { $InventoryRef } else { $null })
    }
    $obj = New-Object -TypeName PSObject -Property $item
    $obj.PSObject.TypeNames.Insert(0, 'AIS.SecretFinding')
    return $obj
}

function New-AISScanError {
    <#
    .SYNOPSIS
        Creates an AIS.ScanError (a non-fatal problem recorded in errors[]).
    .DESCRIPTION
        Collectors may emit these for partial failures (for example one
        unreadable file) and keep going. The orchestrator overwrites
        'collector' with the emitting collector's id. -Message must never
        contain configuration values.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,63}$')]
        [string] $Collector,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,63}$')]
        [string] $Code,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Message
    )

    $item = [ordered]@{
        collector = $Collector
        code      = $Code
        message   = (Limit-AISString -Text $Message -MaxLength $script:AISLimits.Message)
    }
    $obj = New-Object -TypeName PSObject -Property $item
    $obj.PSObject.TypeNames.Insert(0, 'AIS.ScanError')
    return $obj
}

function Get-AISSeverityRank {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('info', 'low', 'medium', 'high', 'critical')]
        [string] $Severity
    )

    return [array]::IndexOf($script:AISSeverities, $Severity.ToLowerInvariant())
}
