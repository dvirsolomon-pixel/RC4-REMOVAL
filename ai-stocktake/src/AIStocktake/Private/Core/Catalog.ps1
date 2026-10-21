# Catalog loading (minimal core part; the catalog content and its schema are
# owned by task K1). Every *.json file under the catalog folder (recursive) is
# parsed with ConvertFrom-AISJsonC and exposed in $Catalog.Data, keyed by its
# path relative to the catalog folder without extension, using '/' separators
# (for example 'mcp-clients', 'tools/cursor').
# catalogVersion comes from <catalog>/catalog.json -> "version" (default '0.0.0').

function Get-AISDefaultCatalogPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Module lives at <repo>/src/AIStocktake; the catalog at <repo>/catalog.
    $repoRoot = Split-Path -Path (Split-Path -Path $script:AISModuleRoot -Parent) -Parent
    return (Join-Path -Path $repoRoot -ChildPath 'catalog')
}

function Import-AISCatalog {
    <#
    .OUTPUTS
        @{ Catalog = AIS.Catalog { Version; Path; Data }; Errors = AIS.ScanError[] }
    #>
    [CmdletBinding()]
    param([string] $Path = (Get-AISDefaultCatalogPath))

    $errors = @()
    $data = [ordered]@{}
    $version = '0.0.0'
    if ($Path -and (Test-Path -LiteralPath $Path -PathType Container)) {
        $full = (Resolve-Path -LiteralPath $Path).ProviderPath
        foreach ($file in (Get-ChildItem -LiteralPath $full -Filter '*.json' -File -Recurse | Sort-Object -Property FullName)) {
            $rel = $file.FullName.Substring($full.Length).TrimStart('\', '/') -replace '\\', '/'
            $key = $rel.Substring(0, $rel.Length - '.json'.Length)
            try {
                $data[$key] = Read-AISJsonFile -LiteralPath $file.FullName
            }
            catch {
                $info = Get-AISSafeErrorInfo -ErrorObject $_ -DefaultCode 'CatalogParseError' -Context 'Catalog load'
                $errors += (New-AISScanError -Collector 'Catalog' -Code 'CatalogParseError' -Message $info.Message)
            }
        }
        if ($data.Contains('catalog')) {
            $v = Get-AISFieldValue -InputObject $data['catalog'] -Name 'version'
            if ($v) { $version = [string]$v }
        }
    }
    $catalog = [pscustomobject]@{
        PSTypeName = 'AIS.Catalog'
        Version    = $version
        Path       = $Path
        Data       = $data
    }
    return @{ Catalog = $catalog; Errors = $errors }
}
