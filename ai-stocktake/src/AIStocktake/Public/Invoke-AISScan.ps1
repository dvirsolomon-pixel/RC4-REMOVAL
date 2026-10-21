function Invoke-AISScan {
    <#
    .SYNOPSIS
        Runs an offline, read-only AI Stocktake scan and optionally writes the JSON result.

    .DESCRIPTION
        Discovers collectors (Private/Collectors/*.ps1 plus any -CollectorPath
        folders), runs each one in isolation against a scan context, and
        assembles a result that conforms to schema/scan-result.v1.schema.json.
        A failing collector never stops the scan: it is reported in errors[]
        with a message that cannot carry configuration content.

        The scanner never changes the machine. The only writes are the result
        file under -OutputPath and, on first use, the per-install fingerprint
        key (see -FingerprintKeyPath). No network access is performed.

        Exit codes (property ExitCode of the returned object; the wrapper script
        scripts/ai-stocktake.ps1 turns it into the process exit code):
          0  no finding at or above -FailOnSeverity and no errors
          1  at least one finding at or above -FailOnSeverity
          2  the scan could not run (fatal), or it completed with errors[] and
             no finding at or above -FailOnSeverity
        Findings take precedence over errors so that Intune remediation
        detection sees "non-compliant" whenever risky findings exist.

    .PARAMETER OutputPath
        Folder for the result file (created if missing). Without it nothing is
        written and the result is only returned.
    .PARAMETER Root
        Fixture folder that replaces the real machine (see ScanContext.ps1 and
        docs/COLLECTOR-CONTRACT.md). No real key file is read or created in this
        mode unless -FingerprintKeyPath is given.
    .PARAMETER MachineWide
        Scan all user profiles and machine-wide locations. Requires
        administrative rights; without them the current user is scanned and a
        'NotElevated' error is recorded.
    .PARAMETER PrivacyMode
        Replace user names and the host name with keyed pseudonyms, profile
        folders with {UserProfile}, and re-key all ids. Alias: -RedactUser.
    .PARAMETER Include
        Collector ids to run (wildcards allowed). Default: all.
    .PARAMETER Exclude
        Collector ids to skip (wildcards allowed). Applied after -Include.
    .PARAMETER FailOnSeverity
        Lowest finding severity that yields exit code 1. Default: high.
    .PARAMETER FingerprintKey
        Key bytes (at least 16) for fingerprints and pseudonyms. Intended for
        tests and for keys provisioned by a management tool.
    .PARAMETER FingerprintKeyPath
        Location of the per-install key file. Default:
        <LocalApplicationData>/AIStocktake/fingerprint.key. Must not be inside
        -OutputPath.
    .PARAMETER EphemeralKey
        Use a random in-memory key for this scan only (nothing is written;
        fingerprints are not comparable across scans).
    .PARAMETER CollectorPath
        Additional folders with collector files.
    .PARAMETER CatalogPath
        Catalog folder. Default: <repo>/catalog.

    .OUTPUTS
        AIS.ScanOutcome { ExitCode; OutputFile; Result; Summary }

    .EXAMPLE
        Invoke-AISScan -OutputPath .\out
    .EXAMPLE
        Invoke-AISScan -Root .\tests\fixtures\profiles\dev-basic -OutputPath .\out -PrivacyMode
    #>
    [CmdletBinding()]
    param(
        [string] $OutputPath,

        [string] $Root,

        [switch] $MachineWide,

        [Alias('RedactUser')]
        [switch] $PrivacyMode,

        [string[]] $Include,

        [string[]] $Exclude,

        [ValidateSet('info', 'low', 'medium', 'high', 'critical')]
        [string] $FailOnSeverity = 'high',

        [byte[]] $FingerprintKey,

        [string] $FingerprintKeyPath,

        [switch] $EphemeralKey,

        [string[]] $CollectorPath,

        [string] $CatalogPath
    )

    $scanStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $outcome = [pscustomobject]@{
        PSTypeName = 'AIS.ScanOutcome'
        ExitCode   = 2
        OutputFile = $null
        Result     = $null
        Summary    = $null
    }

    try {
        # --- Key ------------------------------------------------------------
        $outputFull = $null
        if ($OutputPath) { $outputFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath) }
        if ($FingerprintKey) {
            if ($FingerprintKey.Length -lt 16) {
                throw (New-AISSafeException -Code 'KeyTooShort' -Message 'Fingerprint key must be at least 16 bytes.')
            }
            $key = $FingerprintKey
        }
        elseif ($EphemeralKey -or ($Root -and -not $FingerprintKeyPath)) {
            $key = New-AISRandomKey -Length 32
        }
        else {
            $keyPath = $FingerprintKeyPath
            if (-not $keyPath) { $keyPath = Get-AISDefaultKeyPath }
            $keyPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($keyPath)
            if ($outputFull -and (Test-AISPathUnder -Path $keyPath -Parent $outputFull)) {
                throw (New-AISSafeException -Code 'KeyInsideOutput' -Message 'The fingerprint key file must not be located inside the output folder.')
            }
            $key = Get-AISFingerprintKey -Path $keyPath -Create
        }

        # --- Context, catalog, collectors -------------------------------------
        $ctx = New-AISScanContext -Root $Root -MachineWide:$MachineWide -PrivacyMode:$PrivacyMode -FingerprintKey $key
        $startedAt = $ctx.Now()

        $errors = New-Object System.Collections.Generic.List[object]
        foreach ($e in $ctx.InitErrors) { $errors.Add($e) }

        $catalogArgs = @{}
        if ($CatalogPath) { $catalogArgs['Path'] = $CatalogPath }
        $catalogLoad = Import-AISCatalog @catalogArgs
        foreach ($e in $catalogLoad.Errors) { $errors.Add($e) }
        $catalog = $catalogLoad.Catalog

        $paths = @($script:AISCollectorDirectory)
        if ($CollectorPath) { $paths += $CollectorPath }
        $loaded = Import-AISCollector -Path $paths
        foreach ($e in $loaded.Errors) { $errors.Add($e) }

        $selection = Select-AISCollector -Collectors $loaded.Collectors -Include $Include -Exclude $Exclude
        foreach ($e in $selection.Errors) { $errors.Add($e) }

        # --- Run --------------------------------------------------------------
        $inventory = New-Object System.Collections.Generic.List[object]
        $findings = New-Object System.Collections.Generic.List[object]
        $secrets = New-Object System.Collections.Generic.List[object]
        $statuses = New-Object System.Collections.Generic.List[object]
        $selectedIds = @($selection.Selected | ForEach-Object { $_.Id })

        foreach ($def in $loaded.Collectors) {
            if ($selectedIds -notcontains $def.Id) {
                $statuses.Add([ordered]@{ id = $def.Id; version = $def.Version; status = 'skipped'; durationMs = 0; reason = 'Not selected.' })
                continue
            }
            Write-Verbose ('Running collector ' + $def.Id)
            $run = Invoke-AISCollector -Definition $def -Context $ctx -Catalog $catalog
            foreach ($x in $run.Inventory) { $inventory.Add($x) }
            foreach ($x in $run.Findings) { $findings.Add($x) }
            foreach ($x in $run.Secrets) { $secrets.Add($x) }
            foreach ($x in $run.Errors) { $errors.Add($x) }
            $statuses.Add([ordered]@{ id = $def.Id; version = $def.Version; status = $run.Status; durationMs = $run.DurationMs; reason = $run.Reason })
        }

        # --- Assemble ---------------------------------------------------------
        $scanStopwatch.Stop()
        $doc = ConvertTo-AISScanDocument -Context $ctx -ScanId ([guid]::NewGuid().ToString()) -StartedAtUtc $startedAt `
            -DurationMs ([long]$scanStopwatch.ElapsedMilliseconds) -CatalogVersion $catalog.Version `
            -CollectorStatus $statuses.ToArray() -Inventory $inventory.ToArray() -Findings $findings.ToArray() `
            -Secrets $secrets.ToArray() -ScanErrors $errors.ToArray()

        if ($outputFull) {
            $outcome.OutputFile = Write-AISScanResult -Document $doc -Directory $outputFull
        }

        $outcome.Result = $doc
        $outcome.Summary = $doc['summary']
        $outcome.ExitCode = Get-AISExitCode -Findings $doc['findings'] -ErrorCount @($doc['errors']).Count -FailOnSeverity $FailOnSeverity
    }
    catch {
        $info = Get-AISSafeErrorInfo -ErrorObject $_ -DefaultCode 'ScanFailed' -Context 'Scan'
        $outcome.ExitCode = 2
        Write-Error -Message ('AI Stocktake scan failed (' + $info.Code + '): ' + $info.Message) -ErrorId ('AIS.' + $info.Code) -Category OperationStopped
    }
    return $outcome
}
