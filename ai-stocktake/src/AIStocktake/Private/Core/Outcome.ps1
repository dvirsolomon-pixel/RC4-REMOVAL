# Exit code and path helpers used by Invoke-AISScan.

function Get-AISExitCode {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [AllowEmptyCollection()] [AllowNull()] [object[]] $Findings,
        [int] $ErrorCount,
        [string] $FailOnSeverity = 'high'
    )

    $threshold = Get-AISSeverityRank -Severity $FailOnSeverity
    foreach ($f in $Findings) {
        if ($null -eq $f) { continue }
        if ((Get-AISSeverityRank -Severity ([string]$f['severity'])) -ge $threshold) { return 1 }
    }
    if ($ErrorCount -gt 0) { return 2 }
    return 0
}

function Test-AISPathUnder {
    [CmdletBinding()]
    [OutputType([bool])]
    param([string] $Path, [string] $Parent)

    $p = (ConvertTo-AISNormalizedPath -Path $Path) + '/'
    $q = (ConvertTo-AISNormalizedPath -Path $Parent) + '/'
    return $p.StartsWith($q, [System.StringComparison]::Ordinal)
}
