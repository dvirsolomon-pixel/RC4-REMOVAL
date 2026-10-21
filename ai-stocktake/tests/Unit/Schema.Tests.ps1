BeforeDiscovery {
    $script:HasTestJson = [bool](Get-Command -Name Test-Json -CommandType Cmdlet -ErrorAction SilentlyContinue)
}

Describe 'scan-result.v1 schema' -Tag 'Unit', 'Schema' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../TestCommon.ps1')
        $script:SchemaText = Get-Content -LiteralPath $script:AISSchemaFile -Raw
        $script:Schema = $script:SchemaText | ConvertFrom-Json

        # Walks the schema and yields every node with its JSON pointer.
        function Get-SchemaNode {
            param($Node, [string] $Pointer)
            if ($null -eq $Node) { return }
            if ($Node -is [System.Management.Automation.PSCustomObject]) {
                [pscustomobject]@{ Pointer = $Pointer; Node = $Node }
                foreach ($p in $Node.PSObject.Properties) {
                    Get-SchemaNode -Node $p.Value -Pointer ($Pointer + '/' + $p.Name)
                }
            }
            elseif ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
                $i = 0
                foreach ($e in $Node) { Get-SchemaNode -Node $e -Pointer ($Pointer + '/' + $i); $i++ }
            }
        }

        function New-ValidDocument {
            param([byte[]] $Key)
            InModuleScope AIStocktake -Parameters @{ Root = $script:AISFixtureRoot; K = $Key } {
                param($Root, $K)
                $ctx = New-AISScanContext -Root $Root -FingerprintKey $K
                $inv = New-AISInventoryItem -Kind 'mcp-server' -Name 'srv' -ToolId 'cursor' -Path 'C:\x\mcp.json' -Properties @{ transport = 'stdio'; args = @('a', 1, $true) }
                $f = New-AISFinding -RuleId 'AIS-MCP-002' -Category 'mcp' -Severity 'medium' -Title 't' -InventoryRef $inv.id -EvidencePath 'C:\x\mcp.json' -JsonPointer '/mcpServers/srv'
                $fp = New-AISFingerprint -Key $K -Value ('generated-' + [guid]::NewGuid())
                $s = New-AISSecretFinding -Type 'github_pat' -Fingerprint $fp -RuleId 'AIS-SEC-001' -Path 'C:\x\mcp.json' -JsonPointer '/mcpServers/srv/env/T' -LengthBucket '>40' -KnownPrefix 'ghp_' -InventoryRef $inv.id
                $e = New-AISScanError -Collector 'Apps' -Code 'Partial' -Message 'm'
                $status = @([ordered]@{ id = 'Apps'; version = '1.0.0'; status = 'ok'; durationMs = 3; reason = $null })
                ConvertTo-AISScanDocument -Context $ctx -ScanId ([guid]::NewGuid().ToString()) -StartedAtUtc $ctx.Now() -DurationMs 5 -CatalogVersion '2026.10.0' `
                    -CollectorStatus $status -Inventory @($inv) -Findings @($f) -Secrets @($s) -ScanErrors @($e)
            }
        }
    }

    It 'is valid JSON with a draft-07 $schema and a URN id (no network reference)' {
        $script:Schema.'$schema' | Should -Be 'http://json-schema.org/draft-07/schema#'
        $script:Schema.'$id' | Should -BeLike 'urn:*'
    }

    It 'closes every object schema with additionalProperties: false (except the typed property bag)' {
        $open = @()
        foreach ($n in (Get-SchemaNode -Node $script:Schema -Pointer '')) {
            $node = $n.Node
            $isObject = $node.PSObject.Properties['properties'] -and $node.PSObject.Properties['type'] -and (@($node.type) -contains 'object')
            if ($isObject -and $node.additionalProperties -ne $false) { $open += $n.Pointer }
        }
        $open | Should -BeNullOrEmpty
        $bag = $script:Schema.definitions.propertyBag
        $bag.propertyNames.pattern | Should -Not -BeNullOrEmpty
        $bag.propertyNames.not.enum | Should -Contain 'value'
    }

    It 'declares no property that could carry a secret value' {
        $forbidden = '^(value|rawValue|raw|secret|secretValue|password|passwd|token|apiKey|key|plaintext|cleartext|env|headers|commandLine|args)$'
        $bad = @()
        foreach ($n in (Get-SchemaNode -Node $script:Schema -Pointer '')) {
            $props = $n.Node.PSObject.Properties['properties']
            if ($props -and $props.Value -is [System.Management.Automation.PSCustomObject]) {
                foreach ($p in $props.Value.PSObject.Properties) {
                    if ($p.Name -match $forbidden) { $bad += ($n.Pointer + '/properties/' + $p.Name) }
                }
            }
        }
        $bad | Should -BeNullOrEmpty
        @($script:Schema.definitions.secret.properties.PSObject.Properties.Name) | Should -Be @('id', 'type', 'fp', 'ruleId', 'location', 'lengthBucket', 'knownPrefix', 'inventoryRef')
    }

    It 'keeps factory enums in sync with the schema' {
        $vals = InModuleScope AIStocktake { @{ Kinds = $script:AISInventoryKinds; Sev = $script:AISSeverities; Forbidden = $script:AISForbiddenPropertyNames; Src = $script:AISSources } }
        @($script:Schema.definitions.inventoryItem.properties.kind.enum) | Should -Be @($vals.Kinds)
        @($script:Schema.definitions.severity.enum) | Should -Be @($vals.Sev)
        @($script:Schema.definitions.inventoryItem.properties.source.enum) | Should -Be @($vals.Src)
        foreach ($f in $vals.Forbidden) { @($script:Schema.definitions.propertyBag.propertyNames.not.enum) | Should -Contain $f }
    }

    Context 'validation with Test-Json' {
        It 'accepts a document produced by the writer' -Skip:(-not $script:HasTestJson) {
            $doc = New-ValidDocument -Key (New-TestKey)
            $json = InModuleScope AIStocktake -Parameters @{ D = $doc } { param($D) ConvertTo-AISJson -InputObject $D }
            Test-Json -Json $json -SchemaFile $script:AISSchemaFile | Should -BeTrue
            InModuleScope AIStocktake -Parameters @{ J = $json } { param($J) Test-AISScanResultSchema -Json $J } | Should -BeTrue
        }

        It 'rejects <Case>' -Skip:(-not $script:HasTestJson) -TestCases @(
            @{ Case = 'an extra top-level field'; Mutate = { param($d) $d['extra'] = 1 } }
            @{ Case = 'a value field on a secret'; Mutate = { param($d) $d['secrets'][0]['value'] = 'x' } }
            @{ Case = 'a raw fingerprint'; Mutate = { param($d) $d['secrets'][0]['fp'] = 'not-a-fingerprint' } }
            @{ Case = 'a forbidden inventory property'; Mutate = { param($d) $d['inventory'][0]['properties']['token'] = 'x' } }
            @{ Case = 'a nested inventory property'; Mutate = { param($d) $d['inventory'][0]['properties']['nested'] = [ordered]@{ a = 1 } } }
            @{ Case = 'an extra evidence field'; Mutate = { param($d) $d['findings'][0]['evidence']['raw'] = 'x' } }
            @{ Case = 'an unknown severity'; Mutate = { param($d) $d['findings'][0]['severity'] = 'severe' } }
            @{ Case = 'an extra error field'; Mutate = { param($d) $d['errors'][0]['stack'] = 'x' } }
            @{ Case = 'a missing summary'; Mutate = { param($d) $d.Remove('summary') } }
        ) {
            $doc = New-ValidDocument -Key (New-TestKey)
            & $Mutate $doc
            $json = InModuleScope AIStocktake -Parameters @{ D = $doc } { param($D) ConvertTo-AISJson -InputObject $D }
            Test-Json -Json $json -SchemaFile $script:AISSchemaFile -ErrorAction SilentlyContinue | Should -BeFalse
        }
    }
}
