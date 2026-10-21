# Shared test setup. Dot-source from BeforeAll:  . (Join-Path $PSScriptRoot '../TestCommon.ps1')

$script:AISRepoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $script:AISRepoRoot 'src'))) {
    $script:AISRepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}
$script:AISManifest = Join-Path $script:AISRepoRoot 'src/AIStocktake/AIStocktake.psd1'
$script:AISSchemaFile = Join-Path $script:AISRepoRoot 'schema/scan-result.v1.schema.json'
$script:AISFixtureRoot = Join-Path $script:AISRepoRoot 'tests/fixtures/profiles/dev-basic'

Import-Module -Name $script:AISManifest -Force

function New-TestKey {
    # Generated per test run; never a literal key in the repo.
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return , $bytes
}

function New-TestCollectorFile {
    # Writes a collector file into a folder. $Body is the PowerShell source of the Invoke scriptblock body.
    param(
        [Parameter(Mandatory = $true)] [string] $Directory,
        [Parameter(Mandatory = $true)] [string] $Id,
        [string] $Body = '',
        [string] $Extra = ''
    )
    if (-not (Test-Path -LiteralPath $Directory)) { New-Item -ItemType Directory -Path $Directory -Force | Out-Null }
    $text = @"
`$Collector = @{
    Id = '$Id'
    Version = '1.0.0'
    $Extra
    Invoke = {
        param(`$Ctx, `$Catalog)
        $Body
    }
}
"@
    Set-Content -LiteralPath (Join-Path $Directory ($Id + '.ps1')) -Value $text -Encoding UTF8
}
