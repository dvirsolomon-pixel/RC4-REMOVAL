#Requires -Version 5.1
# AIStocktake module loader.
# Dot-sources every Private and Public script, except Private/Collectors:
# collector files are discovered and loaded at scan time by Import-AISCollector
# (see docs/COLLECTOR-CONTRACT.md).

$script:AISModuleRoot = $PSScriptRoot
$script:AISSchemaVersion = '1.0.0'
# Single source of truth for the agent version is the manifest.
$script:AISAgentVersion = [string](Import-PowerShellDataFile -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'AIStocktake.psd1')).ModuleVersion
$script:AISCollectorDirectory = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private') -ChildPath 'Collectors'

$privateFolders = @('Core', 'Render')
foreach ($folder in $privateFolders) {
    $folderPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private') -ChildPath $folder
    if (Test-Path -LiteralPath $folderPath) {
        foreach ($file in (Get-ChildItem -LiteralPath $folderPath -Filter '*.ps1' -File | Sort-Object -Property Name)) {
            . $file.FullName
        }
    }
}

$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
$publicFunctions = @()
foreach ($file in (Get-ChildItem -LiteralPath $publicPath -Filter '*.ps1' -File | Sort-Object -Property Name)) {
    . $file.FullName
    $publicFunctions += $file.BaseName
}

Export-ModuleMember -Function $publicFunctions
