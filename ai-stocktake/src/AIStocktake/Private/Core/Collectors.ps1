# Collector discovery, validation, selection and execution.
# The contract is documented in docs/COLLECTOR-CONTRACT.md.

$script:AISCollectorKeys = @('Id', 'Version', 'Description', 'Platforms', 'RequiresElevation', 'TimeoutSeconds', 'Invoke')
$script:AISPlatforms = @('Windows', 'Linux', 'MacOS')

function Import-AISCollector {
    <#
    .SYNOPSIS
        Discovers collector files (*.ps1) in the given folders and validates them.
    .OUTPUTS
        @{ Collectors = AIS.CollectorDefinition[] (sorted by Id); Errors = AIS.ScanError[] }
    #>
    [CmdletBinding()]
    param(
        [string[]] $Path = @($script:AISCollectorDirectory)
    )

    $defs = @()
    $errors = @()
    $seen = @{}
    foreach ($dir in $Path) {
        if (-not $dir -or -not (Test-Path -LiteralPath $dir -PathType Container)) {
            $errors += (New-AISScanError -Collector 'Core' -Code 'CollectorPathNotFound' -Message ('Collector folder not found: ' + $dir))
            continue
        }
        foreach ($file in (Get-ChildItem -LiteralPath $dir -Filter '*.ps1' -File | Sort-Object -Property Name)) {
            $label = Get-AISCollectorLabel -Name $file.BaseName
            try {
                # Load in a child scope of the module so the Invoke scriptblock
                # is bound to the module and can call its private helpers.
                $raw = & {
                    param($CollectorFile)
                    $Collector = $null
                    . $CollectorFile
                    , $Collector
                } $file.FullName
            }
            catch {
                $errors += (New-AISScanError -Collector $label -Code 'InvalidCollector' -Message ('Collector file failed to load: ' + $file.Name))
                continue
            }
            $problem = Test-AISCollectorDefinition -Definition $raw -FileBaseName $file.BaseName
            if ($problem) {
                $errors += (New-AISScanError -Collector $label -Code 'InvalidCollector' -Message ($file.Name + ': ' + $problem))
                continue
            }
            if ($seen.ContainsKey($raw.Id)) {
                $errors += (New-AISScanError -Collector $label -Code 'DuplicateCollector' -Message ("Collector id '" + $raw.Id + "' is defined more than once; " + $file.FullName + ' was ignored.'))
                continue
            }
            $seen[$raw.Id] = $true
            $platforms = @($script:AISPlatforms)
            if ($raw.Contains('Platforms')) { $platforms = @($raw.Platforms) }
            $timeout = 30
            if ($raw.Contains('TimeoutSeconds')) { $timeout = [int]$raw.TimeoutSeconds }
            $defs += [pscustomobject]@{
                PSTypeName        = 'AIS.CollectorDefinition'
                Id                = [string]$raw.Id
                Version           = [string]$raw.Version
                Description       = $(if ($raw.Contains('Description')) { [string]$raw.Description } else { '' })
                Platforms         = $platforms
                RequiresElevation = $(if ($raw.Contains('RequiresElevation')) { [bool]$raw.RequiresElevation } else { $false })
                TimeoutSeconds    = $timeout
                Invoke            = $raw.Invoke
                SourcePath        = $file.FullName
            }
        }
    }
    return @{ Collectors = @($defs | Sort-Object -Property Id); Errors = $errors }
}

function Get-AISCollectorLabel {
    # A name usable in errors[].collector even when the file name is odd.
    [CmdletBinding()]
    [OutputType([string])]
    param([string] $Name)

    $clean = ($Name -replace '[^A-Za-z0-9]', '')
    if ($clean -notmatch '^[A-Za-z]') { $clean = 'C' + $clean }
    if ($clean.Length -lt 2) { $clean = $clean + 'x' }
    if ($clean.Length -gt 64) { $clean = $clean.Substring(0, 64) }
    return $clean
}

function Test-AISCollectorDefinition {
    <#
    .SYNOPSIS
        Returns $null when the definition is valid, otherwise a problem description.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()] [object] $Definition,
        [string] $FileBaseName
    )

    if ($null -eq $Definition) { return 'the file does not assign $Collector.' }
    if (-not ($Definition -is [System.Collections.IDictionary])) { return '$Collector must be a hashtable.' }
    foreach ($k in $Definition.Keys) {
        if ($script:AISCollectorKeys -notcontains [string]$k) { return ("unknown key '" + $k + "'.") }
    }
    foreach ($k in @('Id', 'Version', 'Invoke')) {
        if (-not $Definition.Contains($k)) { return ("missing required key '" + $k + "'.") }
    }
    if ([string]$Definition.Id -cnotmatch '^[A-Z][A-Za-z0-9]{1,63}$') { return 'Id must be PascalCase letters and digits.' }
    if ($FileBaseName -and [string]$Definition.Id -ne $FileBaseName) { return ("Id '" + $Definition.Id + "' must match the file name.") }
    if ([string]$Definition.Version -notmatch '^\d+\.\d+\.\d+$') { return 'Version must be semantic (major.minor.patch).' }
    if (-not ($Definition.Invoke -is [scriptblock])) { return 'Invoke must be a scriptblock.' }
    if ($Definition.Contains('Platforms')) {
        $p = @($Definition.Platforms)
        if ($p.Count -eq 0) { return 'Platforms must not be empty.' }
        foreach ($x in $p) { if ($script:AISPlatforms -cnotcontains [string]$x) { return ("unknown platform '" + $x + "'.") } }
    }
    if ($Definition.Contains('RequiresElevation') -and -not ($Definition.RequiresElevation -is [bool])) { return 'RequiresElevation must be a boolean.' }
    if ($Definition.Contains('TimeoutSeconds')) {
        $t = 0
        if (-not [int]::TryParse([string]$Definition.TimeoutSeconds, [ref]$t) -or $t -lt 1 -or $t -gt 600) { return 'TimeoutSeconds must be an integer between 1 and 600.' }
    }
    return $null
}

function Select-AISCollector {
    <#
    .SYNOPSIS
        Applies -Include / -Exclude (wildcards, case-insensitive) to collector definitions.
    .OUTPUTS
        @{ Selected = AIS.CollectorDefinition[]; Errors = AIS.ScanError[] }
        An -Include pattern that matches no collector yields an 'UnknownCollector' error.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()] [object[]] $Collectors,
        [string[]] $Include,
        [string[]] $Exclude
    )

    $errors = @()
    $selected = @($Collectors)
    if ($Include -and $Include.Count -gt 0) {
        foreach ($pattern in $Include) {
            $hit = @($Collectors | Where-Object { $_.Id -like $pattern })
            if ($hit.Count -eq 0) {
                $errors += (New-AISScanError -Collector 'Core' -Code 'UnknownCollector' -Message ("No collector matches -Include '" + $pattern + "'."))
            }
        }
        $selected = @($Collectors | Where-Object {
                $id = $_.Id
                @($Include | Where-Object { $id -like $_ }).Count -gt 0
            })
    }
    if ($Exclude -and $Exclude.Count -gt 0) {
        $selected = @($selected | Where-Object {
                $id = $_.Id
                @($Exclude | Where-Object { $id -like $_ }).Count -eq 0
            })
    }
    return @{ Selected = $selected; Errors = $errors }
}

function Invoke-AISCollector {
    <#
    .SYNOPSIS
        Runs one collector with error isolation.
    .OUTPUTS
        @{ Status = 'ok'|'error'|'skipped'; Reason; DurationMs; Inventory; Findings; Secrets; Errors }
    .DESCRIPTION
        - Skipped (not run) when the platform is not supported or elevation is
          required but missing.
        - Runs with $ErrorActionPreference = 'Stop', so a non-terminating error
          also fails the collector. Any exception => status 'error', one entry in
          errors[] with a safe message (see New-AISSafeException). Output emitted
          before the failure is kept.
        - Output objects are routed by PSTypeName; anything else is dropped and
          reported once as 'InvalidCollectorOutput'.
        - Soft timeout: the collector is not interrupted, but exceeding
          TimeoutSeconds adds a 'SoftTimeoutExceeded' error.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object] $Definition,
        [Parameter(Mandatory = $true)] [object] $Context,
        [AllowNull()] [object] $Catalog
    )

    $result = @{
        Status     = 'ok'
        Reason     = $null
        DurationMs = 0
        Inventory  = New-Object System.Collections.Generic.List[object]
        Findings   = New-Object System.Collections.Generic.List[object]
        Secrets    = New-Object System.Collections.Generic.List[object]
        Errors     = New-Object System.Collections.Generic.List[object]
    }

    if ($Definition.Platforms -notcontains $Context.Platform) {
        $result.Status = 'skipped'
        $result.Reason = 'Not supported on ' + $Context.Platform + '.'
        return $result
    }
    if ($Definition.RequiresElevation -and -not $Context.IsElevated) {
        $result.Status = 'skipped'
        $result.Reason = 'Requires administrative rights.'
        return $result
    }

    $collected = New-Object System.Collections.Generic.List[object]
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & {
            param($InvokeBlock, $Ctx, $Cat, $Sink)
            $ErrorActionPreference = 'Stop'
            & $InvokeBlock $Ctx $Cat | ForEach-Object { $Sink.Add($_) }
        } $Definition.Invoke $Context $Catalog $collected
    }
    catch {
        $info = Get-AISSafeErrorInfo -ErrorObject $_ -DefaultCode 'CollectorFailed' -Context ("Collector '" + $Definition.Id + "'")
        $code = $info.Code
        if (-not $code -or $code -notmatch '^[A-Za-z][A-Za-z0-9]{1,63}$') { $code = 'CollectorFailed' }
        $result.Status = 'error'
        $result.Errors.Add((New-AISScanError -Collector $Definition.Id -Code $code -Message $info.Message))
    }
    $sw.Stop()
    $result.DurationMs = [long]$sw.ElapsedMilliseconds

    $invalid = 0
    foreach ($obj in $collected) {
        if ($null -eq $obj) { continue }
        $typeNames = @($obj.PSObject.TypeNames)
        if ($typeNames -contains 'AIS.InventoryItem') { $result.Inventory.Add($obj) }
        elseif ($typeNames -contains 'AIS.Finding') { $result.Findings.Add($obj) }
        elseif ($typeNames -contains 'AIS.SecretFinding') { $result.Secrets.Add($obj) }
        elseif ($typeNames -contains 'AIS.ScanError') {
            $result.Errors.Add((New-AISScanError -Collector $Definition.Id -Code $obj.code -Message $obj.message))
        }
        else { $invalid++ }
    }
    if ($invalid -gt 0) {
        $result.Errors.Add((New-AISScanError -Collector $Definition.Id -Code 'InvalidCollectorOutput' -Message ([string]$invalid + ' output object(s) were not created by an AIS factory and were dropped.')))
    }
    if ($result.DurationMs -gt ([long]$Definition.TimeoutSeconds * 1000)) {
        $result.Errors.Add((New-AISScanError -Collector $Definition.Id -Code 'SoftTimeoutExceeded' -Message ('Collector ran for ' + $result.DurationMs + ' ms, above its ' + $Definition.TimeoutSeconds + ' s budget.')))
    }
    return $result
}
