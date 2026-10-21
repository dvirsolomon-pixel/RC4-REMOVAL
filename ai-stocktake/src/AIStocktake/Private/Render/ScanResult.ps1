# Scan result document (schema/scan-result.v1.schema.json) and JSON writer.

function ConvertTo-AISScanDocument {
    <#
    .SYNOPSIS
        Assembles the plain-data scan result document.
    .DESCRIPTION
        Sorts arrays for deterministic output, removes duplicate ids (first one
        wins), computes the summary, and, in privacy mode, redacts strings and
        re-keys ids. The returned value is ordered dictionaries/arrays only and
        is exactly what is written to disk.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object] $Context,
        [Parameter(Mandatory = $true)] [string] $ScanId,
        [Parameter(Mandatory = $true)] [datetime] $StartedAtUtc,
        [Parameter(Mandatory = $true)] [long] $DurationMs,
        [Parameter(Mandatory = $true)] [string] $CatalogVersion,
        [AllowEmptyCollection()] [object[]] $CollectorStatus = @(),
        [AllowEmptyCollection()] [object[]] $Inventory = @(),
        [AllowEmptyCollection()] [object[]] $Findings = @(),
        [AllowEmptyCollection()] [object[]] $Secrets = @(),
        [AllowEmptyCollection()] [object[]] $ScanErrors = @()
    )

    $inv = @(Select-AISUniqueById -Items $Inventory | Sort-Object -Property kind, name, id)
    $fnd = @(Select-AISUniqueById -Items $Findings | Sort-Object -Property @{ Expression = { Get-AISSeverityRank -Severity $_.severity }; Descending = $true }, @{ Expression = { $_.ruleId } }, @{ Expression = { $_.id } })
    $sec = @(Select-AISUniqueById -Items $Secrets | Sort-Object -Property type, id)

    $users = @()
    foreach ($p in $Context.Profiles) { $users += [string]$p.Name }

    $bySeverity = [ordered]@{ info = 0; low = 0; medium = 0; high = 0; critical = 0 }
    foreach ($f in $fnd) { $bySeverity[[string]$f.severity] = [int]$bySeverity[[string]$f.severity] + 1 }
    $toolIds = @($inv | Where-Object { $_.toolId } | ForEach-Object { $_.toolId } | Sort-Object -Unique)

    $doc = [ordered]@{
        schemaVersion = $script:AISSchemaVersion
        scan          = [ordered]@{
            id             = $ScanId
            startedAt      = $StartedAtUtc
            durationMs     = $DurationMs
            agentVersion   = $script:AISAgentVersion
            catalogVersion = $CatalogVersion
            mode           = $Context.Mode
            elevated       = [bool]$Context.IsElevated
            privacyMode    = [bool]$Context.PrivacyMode
            fixture        = [bool]$Context.IsFixture
            collectors     = @($CollectorStatus)
        }
        device        = [ordered]@{
            hostname   = $Context.HostName
            os         = $Context.Os
            powershell = $Context.PowerShell
            users      = $users
        }
        inventory     = $inv
        findings      = $fnd
        secrets       = $sec
        errors        = @($ScanErrors)
        summary       = [ordered]@{
            bySeverity = $bySeverity
            inventory  = $inv.Count
            tools      = $toolIds.Count
            mcpServers = @($inv | Where-Object { $_.kind -eq 'mcp-server' }).Count
            secrets    = $sec.Count
            errors     = @($ScanErrors).Count
        }
    }

    $rules = $null
    if ($Context.PrivacyMode) { $rules = Get-AISPrivacyRule -Context $Context }
    $plain = ConvertTo-AISPlainData -InputObject $doc -PrivacyRules $rules

    if ($Context.PrivacyMode) {
        $key = $Context.FingerprintKey
        foreach ($section in @('inventory', 'findings', 'secrets')) {
            foreach ($item in $plain[$section]) {
                $item['id'] = ConvertTo-AISKeyedId -Key $key -Id $item['id']
                if ($item.Contains('inventoryRef') -and $item['inventoryRef']) {
                    $item['inventoryRef'] = ConvertTo-AISKeyedId -Key $key -Id $item['inventoryRef']
                }
            }
        }
    }
    return $plain
}

function Select-AISUniqueById {
    [CmdletBinding()]
    param([AllowEmptyCollection()] [object[]] $Items)

    $seen = @{}
    foreach ($i in $Items) {
        if ($null -eq $i) { continue }
        if ($seen.ContainsKey($i.id)) { continue }
        $seen[$i.id] = $true
        $i
    }
}

function Write-AISScanResult {
    <#
    .SYNOPSIS
        Writes a scan result document to <Directory>/<name>.aistocktake.json
        (UTF-8, no BOM). File name: scan-<host>-<yyyyMMddTHHmmssZ>.aistocktake.json
        where <host> is the document's hostname (a pseudonym in privacy mode).
    .OUTPUTS
        [string] full path of the written file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary] $Document,
        [Parameter(Mandatory = $true)] [string] $Directory
    )

    $hostPart = ([string]$Document['device']['hostname']) -replace '[^A-Za-z0-9-]', '-'
    $started = [string]$Document['scan']['startedAt']
    $stamp = ($started -replace '[-:]', '') -replace '\.\d+', ''
    $name = 'scan-' + $hostPart + '-' + $stamp + '.aistocktake.json'
    return (Write-AISJsonFile -LiteralPath (Join-Path -Path $Directory -ChildPath $name) -InputObject $Document)
}

function Get-AISSchemaPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $repoRoot = Split-Path -Path (Split-Path -Path $script:AISModuleRoot -Parent) -Parent
    return (Join-Path -Path (Join-Path -Path $repoRoot -ChildPath 'schema') -ChildPath 'scan-result.v1.schema.json')
}

function Test-AISScanResultSchema {
    <#
    .SYNOPSIS
        Validates scan result JSON text against the v1 schema.
        Requires PowerShell 7+ (Test-Json -SchemaFile). On 5.1 it throws.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)] [string] $Json,
        [string] $SchemaPath = (Get-AISSchemaPath)
    )

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw (New-AISSafeException -Code 'NotSupported' -Message 'Schema validation requires PowerShell 7 or later.')
    }
    # Resolved dynamically: Test-Json does not exist in Windows PowerShell 5.1.
    $testJson = Get-Command -Name 'Test-Json' -CommandType Cmdlet
    return [bool](& $testJson -Json $Json -SchemaFile $SchemaPath -ErrorAction SilentlyContinue)
}
