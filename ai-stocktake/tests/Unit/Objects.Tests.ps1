Describe 'Object factories' -Tag 'Unit' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../TestCommon.ps1')
    }

    Context 'New-AISInventoryItem' {
        It 'creates a typed item with a deterministic id and all schema fields' {
            InModuleScope AIStocktake {
                $a = New-AISInventoryItem -Kind 'mcp-server' -Name 'filesystem' -ToolId 'claude-desktop' -UserProfileName 'alice' -Path 'C:\Users\alice\AppData\Roaming\Claude\claude_desktop_config.json' -Properties @{ transport = 'stdio'; args = @('-y', 'pkg') }
                $b = New-AISInventoryItem -Kind 'mcp-server' -Name 'filesystem' -ToolId 'claude-desktop' -UserProfileName 'alice' -Path 'c:/users/alice/appdata/roaming/claude/claude_desktop_config.json' -Properties @{ transport = 'stdio' }
                $a.PSObject.TypeNames[0] | Should -Be 'AIS.InventoryItem'
                $a.id | Should -Match '^[0-9a-f]{32}$'
                $a.id | Should -Be $b.id
                @($a.PSObject.Properties.Name) | Should -Be @('id', 'kind', 'toolId', 'name', 'version', 'scope', 'profile', 'source', 'path', 'properties')
                $a.properties['args'].Count | Should -Be 2
            }
        }

        It 'uses the discriminator to separate otherwise identical items' {
            InModuleScope AIStocktake {
                $a = New-AISInventoryItem -Kind 'app' -Name 'X' -IdDiscriminator '1'
                $b = New-AISInventoryItem -Kind 'app' -Name 'X' -IdDiscriminator '2'
                $a.id | Should -Not -Be $b.id
            }
        }

        It 'accepts $null optional values' {
            InModuleScope AIStocktake {
                $x = New-AISInventoryItem -Kind 'app' -Name 'X' -ToolId $null -Version $null -Path $null
                $x.toolId | Should -BeNullOrEmpty
                $x.path | Should -BeNullOrEmpty
            }
        }

        It 'rejects property names that could carry secrets, in any case' -TestCases @(
            @{ Name = 'value' }, @{ Name = 'token' }, @{ Name = 'apiKey' }, @{ Name = 'password' }, @{ Name = 'env' }, @{ Name = 'headers' }, @{ Name = 'accessToken' }
        ) {
            InModuleScope AIStocktake -Parameters @{ N = $Name } {
                param($N)
                $props = @{}
                $props[$N] = 'x'
                { New-AISInventoryItem -Kind 'app' -Name 'X' -Properties $props } | Should -Throw '*not allowed*'
            }
        }

        It 'rejects non-camelCase names and nested objects' {
            InModuleScope AIStocktake {
                { New-AISInventoryItem -Kind 'app' -Name 'X' -Properties @{ 'Bad-Name' = 1 } } | Should -Throw '*camelCase*'
                { New-AISInventoryItem -Kind 'app' -Name 'X' -Properties @{ nested = @{ a = 1 } } } | Should -Throw '*must be a string*'
                { New-AISInventoryItem -Kind 'app' -Name 'X' -Properties @{ nested = [pscustomobject]@{ a = 1 } } } | Should -Throw '*must be a string*'
            }
        }

        It 'validates kind, scope, source and toolId' {
            InModuleScope AIStocktake {
                { New-AISInventoryItem -Kind 'nope' -Name 'X' } | Should -Throw
                { New-AISInventoryItem -Kind 'app' -Name 'X' -Scope 'global' } | Should -Throw
                { New-AISInventoryItem -Kind 'app' -Name 'X' -Source 'web' } | Should -Throw
                { New-AISInventoryItem -Kind 'app' -Name 'X' -ToolId 'Bad Tool' } | Should -Throw '*ToolId*'
            }
        }

        It 'truncates over-long strings' {
            InModuleScope AIStocktake {
                $x = New-AISInventoryItem -Kind 'app' -Name ('n' * 400) -Properties @{ note = ('p' * 2000) }
                $x.name.Length | Should -Be 256
                $x.properties['note'].Length | Should -Be 1024
            }
        }
    }

    Context 'New-AISFinding' {
        It 'creates a typed finding with evidence and a deterministic id' {
            InModuleScope AIStocktake {
                $f = New-AISFinding -RuleId 'AIS-MCP-002' -Category 'mcp' -Severity 'medium' -Title 'Unpinned package' -EvidencePath 'C:\x\mcp.json' -JsonPointer '/mcpServers/a' -References @('https://owasp.org/x', '')
                $g = New-AISFinding -RuleId 'AIS-MCP-002' -Category 'mcp' -Severity 'high' -Title 'Other title' -EvidencePath 'c:/x/mcp.json' -JsonPointer '/mcpServers/a'
                $f.PSObject.TypeNames[0] | Should -Be 'AIS.Finding'
                $f.id | Should -Be $g.id
                $f.evidence['jsonPointer'] | Should -Be '/mcpServers/a'
                @($f.references).Count | Should -Be 1
                @($f.PSObject.Properties.Name) | Should -Be @('id', 'ruleId', 'category', 'severity', 'title', 'toolId', 'inventoryRef', 'evidence', 'remediation', 'references')
            }
        }

        It 'validates rule id, severity and inventory reference' {
            InModuleScope AIStocktake {
                { New-AISFinding -RuleId 'bad' -Category 'mcp' -Severity 'high' -Title 't' } | Should -Throw
                { New-AISFinding -RuleId 'AIS-MCP-001' -Category 'mcp' -Severity 'severe' -Title 't' } | Should -Throw
                { New-AISFinding -RuleId 'AIS-MCP-001' -Category 'mcp' -Severity 'high' -Title 't' -InventoryRef 'xyz' } | Should -Throw '*InventoryRef*'
            }
        }
    }

    Context 'New-AISSecretFinding' {
        It 'accepts only a fingerprint and exposes no value field' {
            $k = New-TestKey
            InModuleScope AIStocktake -Parameters @{ K = $k } {
                param($K)
                $fp = New-AISFingerprint -Key $K -Value ('generated-' + [guid]::NewGuid())
                $s = New-AISSecretFinding -Type 'github_pat' -Fingerprint $fp -RuleId 'AIS-SEC-001' -Path 'C:\x\mcp.json' -JsonPointer '/mcpServers/a/env/GITHUB_TOKEN' -LengthBucket '20-40' -KnownPrefix 'ghp_'
                $s.PSObject.TypeNames[0] | Should -Be 'AIS.SecretFinding'
                @($s.PSObject.Properties.Name) | Should -Not -Contain 'value'
                $s.fp | Should -Be $fp
                { New-AISSecretFinding -Type 'github_pat' -Fingerprint 'plain-text-secret' -RuleId 'AIS-SEC-001' -Path 'p' -LengthBucket '<20' } | Should -Throw
                { New-AISSecretFinding -Type 'github_pat' -Fingerprint $fp -RuleId 'AIS-SEC-001' -Path 'p' -LengthBucket '<20' -KnownPrefix 'much-too-long-prefix-value' } | Should -Throw '*KnownPrefix*'
            }
        }
    }

    Context 'New-AISScanError and severity rank' {
        It 'creates errors and ranks severities' {
            InModuleScope AIStocktake {
                $e = New-AISScanError -Collector 'Apps' -Code 'Partial' -Message ('m' * 900)
                $e.PSObject.TypeNames[0] | Should -Be 'AIS.ScanError'
                $e.message.Length | Should -Be 500
                { New-AISScanError -Collector 'Apps' -Code 'bad code' -Message 'x' } | Should -Throw
                (Get-AISSeverityRank -Severity 'critical') | Should -BeGreaterThan (Get-AISSeverityRank -Severity 'high')
                (Get-AISSeverityRank -Severity 'info') | Should -Be 0
            }
        }
    }
}
