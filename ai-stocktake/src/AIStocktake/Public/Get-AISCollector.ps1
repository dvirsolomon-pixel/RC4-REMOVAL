function Get-AISCollector {
    <#
    .SYNOPSIS
        Lists the collectors that Invoke-AISScan would discover.
    .DESCRIPTION
        Loads collector definitions from Private/Collectors and any -CollectorPath
        folders and returns their metadata. Invalid collector files are reported
        as warnings.
    .PARAMETER CollectorPath
        Additional folders with collector files.
    .EXAMPLE
        Get-AISCollector | Format-Table Id, Version, Platforms
    #>
    [CmdletBinding()]
    param(
        [string[]] $CollectorPath
    )

    $paths = @($script:AISCollectorDirectory)
    if ($CollectorPath) { $paths += $CollectorPath }
    $loaded = Import-AISCollector -Path $paths
    foreach ($e in $loaded.Errors) {
        Write-Warning ($e.collector + ': ' + $e.message)
    }
    foreach ($c in $loaded.Collectors) {
        [pscustomobject]@{
            PSTypeName        = 'AIS.CollectorInfo'
            Id                = $c.Id
            Version           = $c.Version
            Description       = $c.Description
            Platforms         = $c.Platforms
            RequiresElevation = $c.RequiresElevation
            TimeoutSeconds    = $c.TimeoutSeconds
            SourcePath        = $c.SourcePath
        }
    }
}
