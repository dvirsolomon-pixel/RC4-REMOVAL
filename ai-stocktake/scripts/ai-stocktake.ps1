<#
.SYNOPSIS
    Command-line entry point for AI Stocktake. Runs Invoke-AISScan and exits
    with its exit code (0 = clean, 1 = findings at/above threshold, 2 = error).
.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ai-stocktake.ps1 -OutputPath .\out
.EXAMPLE
    pwsh -NoProfile -File ./scripts/ai-stocktake.ps1 -Root ./tests/fixtures/profiles/dev-basic -OutputPath ./out -PrivacyMode
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path -Path (Get-Location).Path -ChildPath 'out'),
    [string] $Root,
    [switch] $MachineWide,
    [Alias('RedactUser')]
    [switch] $PrivacyMode,
    [string[]] $Include,
    [string[]] $Exclude,
    [ValidateSet('info', 'low', 'medium', 'high', 'critical')]
    [string] $FailOnSeverity = 'high',
    [string] $FingerprintKeyPath,
    [switch] $EphemeralKey
)

$ErrorActionPreference = 'Stop'
try {
    $manifest = Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'src/AIStocktake/AIStocktake.psd1'
    Import-Module -Name $manifest -Force

    $scanArgs = @{
        OutputPath     = $OutputPath
        MachineWide    = $MachineWide
        PrivacyMode    = $PrivacyMode
        FailOnSeverity = $FailOnSeverity
        EphemeralKey   = $EphemeralKey
    }
    if ($Root) { $scanArgs['Root'] = $Root }
    if ($Include) { $scanArgs['Include'] = $Include }
    if ($Exclude) { $scanArgs['Exclude'] = $Exclude }
    if ($FingerprintKeyPath) { $scanArgs['FingerprintKeyPath'] = $FingerprintKeyPath }

    $outcome = Invoke-AISScan @scanArgs -ErrorAction Continue
    if ($outcome.OutputFile) { Write-Output ('Result: ' + $outcome.OutputFile) }
    if ($outcome.Summary) {
        $s = $outcome.Summary
        Write-Output ('Inventory items: ' + $s['inventory'] + '; findings (critical/high/medium/low/info): ' +
            $s['bySeverity']['critical'] + '/' + $s['bySeverity']['high'] + '/' + $s['bySeverity']['medium'] + '/' +
            $s['bySeverity']['low'] + '/' + $s['bySeverity']['info'] + '; errors: ' + $s['errors'])
    }
    exit [int]$outcome.ExitCode
}
catch {
    Write-Output 'AI Stocktake could not start.'
    exit 2
}
