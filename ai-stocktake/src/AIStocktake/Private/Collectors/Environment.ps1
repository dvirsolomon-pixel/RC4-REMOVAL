# Example collector: describes the scanned host (OS and PowerShell runtime).
# It shows the minimal collector shape; see docs/COLLECTOR-CONTRACT.md.
# The attribute tells PSScriptAnalyzer that $Collector is read by the loader.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'Collector', Justification = 'Read by Import-AISCollector.')]
param()

$Collector = @{
    Id                = 'Environment'
    Version           = '1.0.0'
    Description       = 'Host operating system and PowerShell runtime of the scan.'
    Platforms         = @('Windows', 'Linux', 'MacOS')
    RequiresElevation = $false
    TimeoutSeconds    = 5
    Invoke            = {
        param($Ctx, $Catalog)
        $null = $Catalog   # not needed by this collector

        New-AISInventoryItem -Kind 'host' -Name ($Ctx.Os.family + ' host') -Version $Ctx.Os.version `
            -Scope 'machine' -Source 'system' -Properties @{
            osFamily          = $Ctx.Os.family
            osVersion         = $Ctx.Os.version
            powershellVersion = $Ctx.PowerShell.version
            powershellEdition = $Ctx.PowerShell.edition
            scanMode          = $Ctx.Mode
            elevated          = [bool]$Ctx.IsElevated
            profilesScanned   = @($Ctx.Profiles).Count
        }
    }
}
