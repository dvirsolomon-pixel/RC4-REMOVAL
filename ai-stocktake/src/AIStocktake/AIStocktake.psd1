@{
    RootModule           = 'AIStocktake.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '33449cca-11e5-403a-9ecf-8a3653a64164'
    Author               = 'AI Stocktake contributors'
    CompanyName          = 'AI Stocktake'
    Copyright            = '(c) AI Stocktake contributors. MIT License.'
    Description          = 'Offline, read-only inventory of AI tools, MCP servers, coding agents, browser extensions and local LLM runtimes on a workstation. Secrets are reported as keyed fingerprints only.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @('Invoke-AISScan', 'Get-AISCollector')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags       = @('AI', 'Inventory', 'MCP', 'Security', 'Audit', 'Windows')
            LicenseUri = 'https://opensource.org/licenses/MIT'
        }
    }
}
