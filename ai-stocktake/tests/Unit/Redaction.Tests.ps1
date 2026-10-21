Describe 'Privacy mode redaction' -Tag 'Unit' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../TestCommon.ps1')
    }

    It 'replaces profile paths, user names and host name; leaves hashes alone' {
        $k = New-TestKey
        InModuleScope AIStocktake -Parameters @{ Root = $script:AISFixtureRoot; K = $k } {
            param($Root, $K)
            $ctx = New-AISScanContext -Root $Root -PrivacyMode -FingerprintKey $K
            $rules = Get-AISPrivacyRule -Context $ctx
            $up = $ctx.Roots.UserProfile
            $alicePseudo = ConvertTo-AISPseudonym -Key $K -Value 'alice'

            Protect-AISString -Text (Join-Path $up '.cursor/mcp.json') -Rules $rules | Should -Be ('{UserProfile}' + [IO.Path]::DirectorySeparatorChar + '.cursor/mcp.json')
            Protect-AISString -Text ($up.ToUpperInvariant() + '\x') -Rules $rules | Should -BeLike '{UserProfile}*'
            Protect-AISString -Text 'C:\Users\alice\AppData' -Rules $rules | Should -Be ('C:\Users\' + $alicePseudo + '\AppData')
            Protect-AISString -Text 'owner: Alice.' -Rules $rules | Should -Be ('owner: ' + $alicePseudo + '.')
            Protect-AISString -Text 'malice and aliceberg' -Rules $rules | Should -Be 'malice and aliceberg'
            Protect-AISString -Text 'host FIXTURE-PC-01 ok' -Rules $rules | Should -Be ('host ' + (ConvertTo-AISPseudonym -Key $K -Value 'FIXTURE-PC-01') + ' ok')
            Protect-AISString -Text $alicePseudo -Rules $rules | Should -Be $alicePseudo
            Protect-AISString -Text '' -Rules $rules | Should -Be ''
        }
    }

    It 'redacts a whole document and re-keys ids consistently' {
        $k = New-TestKey
        InModuleScope AIStocktake -Parameters @{ Root = $script:AISFixtureRoot; K = $k } {
            param($Root, $K)
            $ctx = New-AISScanContext -Root $Root -PrivacyMode -FingerprintKey $K
            $path = Join-Path $ctx.Roots.AppData 'Claude/claude_desktop_config.json'
            $inv = New-AISInventoryItem -Kind 'mcp-server' -Name 'alice-notes' -UserProfileName 'alice' -Path $path -Properties @{ owner = 'alice' }
            $f = New-AISFinding -RuleId 'AIS-MCP-001' -Category 'mcp' -Severity 'info' -Title 'Server of alice' -InventoryRef $inv.id -EvidencePath $path -Detail ('Found in ' + $path)
            $doc = ConvertTo-AISScanDocument -Context $ctx -ScanId ([guid]::NewGuid().ToString()) -StartedAtUtc $ctx.Now() -DurationMs 1 -CatalogVersion '0' -Inventory @($inv) -Findings @($f)
            $json = ConvertTo-AISJson -InputObject $doc
            $json | Should -Not -Match '(?i)(?<![a-z0-9])alice(?![a-z0-9])'
            $json | Should -Not -Match 'FIXTURE-PC-01'
            $json | Should -Not -Match ([regex]::Escape($ctx.FixtureRoot.Replace('\', '\\')))
            $doc['inventory'][0]['id'] | Should -Not -Be $inv.id
            $doc['inventory'][0]['id'] | Should -Be (ConvertTo-AISKeyedId -Key $K -Id $inv.id)
            $doc['findings'][0]['inventoryRef'] | Should -Be $doc['inventory'][0]['id']
            $doc['inventory'][0]['path'] | Should -BeLike '{UserProfile}*'
            $doc['device']['users'][0] | Should -Match '^hmac:[0-9a-f]{16}$'
            $doc['scan']['privacyMode'] | Should -BeTrue
        }
    }

    It 'does not alter anything when privacy mode is off' {
        InModuleScope AIStocktake -Parameters @{ Root = $script:AISFixtureRoot } {
            param($Root)
            $ctx = New-AISScanContext -Root $Root
            $inv = New-AISInventoryItem -Kind 'app' -Name 'alice tool' -UserProfileName 'alice'
            $doc = ConvertTo-AISScanDocument -Context $ctx -ScanId ([guid]::NewGuid().ToString()) -StartedAtUtc $ctx.Now() -DurationMs 1 -CatalogVersion '0' -Inventory @($inv)
            $doc['inventory'][0]['id'] | Should -Be $inv.id
            $doc['inventory'][0]['name'] | Should -Be 'alice tool'
            $doc['device']['hostname'] | Should -Be 'FIXTURE-PC-01'
        }
    }
}

Describe 'Get-AISSafeErrorInfo' -Tag 'Unit' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../TestCommon.ps1')
    }

    It 'returns safe messages, unwraps inner exceptions, and hides unsafe ones' {
        InModuleScope AIStocktake {
            $safe = New-AISSafeException -Code 'ConfigMissing' -Message 'Config missing.'
            (Get-AISSafeErrorInfo -ErrorObject $safe).Message | Should -Be 'Config missing.'
            $wrapped = New-Object System.Management.Automation.MethodInvocationException -ArgumentList 'outer SECRETVALUE', $safe
            (Get-AISSafeErrorInfo -ErrorObject $wrapped).Code | Should -Be 'ConfigMissing'
            $unsafe = Get-AISSafeErrorInfo -ErrorObject (New-Object System.FormatException -ArgumentList 'contains SECRETVALUE') -DefaultCode 'X' -Context 'Thing'
            $unsafe.Code | Should -Be 'X'
            $unsafe.Message | Should -Match 'FormatException'
            $unsafe.Message | Should -Not -Match 'SECRETVALUE'
        }
    }
}
