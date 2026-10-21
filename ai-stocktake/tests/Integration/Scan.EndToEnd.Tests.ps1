BeforeDiscovery {
    $script:HasTestJson = [bool](Get-Command -Name Test-Json -CommandType Cmdlet -ErrorAction SilentlyContinue)
}

Describe 'Invoke-AISScan end to end against the dev-basic fixture' -Tag 'Integration' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../TestCommon.ps1')
        $script:Key = New-TestKey
        $script:Out = Join-Path $TestDrive 'out'
        $script:Outcome = Invoke-AISScan -Root $script:AISFixtureRoot -OutputPath $script:Out -FingerprintKey $script:Key
        $script:Json = Get-Content -LiteralPath $script:Outcome.OutputFile -Raw
        $script:Doc = $script:Json | ConvertFrom-Json
    }

    It 'writes one result file with the expected name, UTF-8 without BOM' {
        @(Get-ChildItem -LiteralPath $script:Out).Count | Should -Be 1
        (Split-Path $script:Outcome.OutputFile -Leaf) | Should -Be 'scan-FIXTURE-PC-01-20261021T080000Z.aistocktake.json'
        ([IO.File]::ReadAllBytes($script:Outcome.OutputFile))[0] | Should -Not -Be 0xEF
    }

    It 'exits 0 for a clean scan and reports collectors and summary' {
        $script:Outcome.ExitCode | Should -Be 0
        $script:Doc.schemaVersion | Should -Be '1.0.0'
        $script:Doc.scan.mode | Should -Be 'user'
        $script:Doc.scan.fixture | Should -BeTrue
        # PS7 ConvertFrom-Json turns ISO strings into DateTime, so check the raw text.
        $script:Json | Should -Match '"startedAt":\s*"2026-10-21T08:00:00\.000Z"'
        ($script:Doc.scan.collectors | Where-Object id -EQ 'Environment').status | Should -Be 'ok'
        $script:Doc.device.hostname | Should -Be 'FIXTURE-PC-01'
        @($script:Doc.device.users) | Should -Be @('alice')
        ($script:Doc.inventory | Where-Object kind -EQ 'host').properties.powershellEdition | Should -Be 'Desktop'
        $script:Doc.summary.inventory | Should -Be @($script:Doc.inventory).Count
        @($script:Doc.errors).Count | Should -Be 0
    }

    It 'conforms to the v1 schema' -Skip:(-not $script:HasTestJson) {
        Test-Json -Json $script:Json -SchemaFile $script:AISSchemaFile | Should -BeTrue
    }

    It 'never writes the fingerprint key into the output' {
        $b64 = [Convert]::ToBase64String($script:Key)
        $hex = -join ($script:Key | ForEach-Object { $_.ToString('x2') })
        $script:Json | Should -Not -Match ([regex]::Escape($b64))
        $script:Json | Should -Not -Match $hex
        $script:Json | Should -Not -Match '"(?i:fingerprintKey|key)"'
    }

    It 'produces stable ids across runs' {
        $again = Invoke-AISScan -Root $script:AISFixtureRoot -FingerprintKey $script:Key
        @($again.Result['inventory'] | ForEach-Object { $_['id'] }) | Should -Be @($script:Doc.inventory.id)
        $again.OutputFile | Should -BeNullOrEmpty
    }

    It 'privacy mode removes user and host names and fixture paths' {
        $out = Join-Path $TestDrive 'private'
        $o = Invoke-AISScan -Root $script:AISFixtureRoot -OutputPath $out -FingerprintKey $script:Key -RedactUser
        $json = Get-Content -LiteralPath $o.OutputFile -Raw
        $json | Should -Not -Match '(?i)(?<![a-z0-9])alice(?![a-z0-9])'
        $json | Should -Not -Match 'FIXTURE-PC-01'
        (Split-Path $o.OutputFile -Leaf) | Should -Not -Match 'FIXTURE'
        ($json | ConvertFrom-Json).scan.privacyMode | Should -BeTrue
    }

    It 'machine-wide without elevation records NotElevated and exits 2' {
        $o = Invoke-AISScan -Root $script:AISFixtureRoot -MachineWide -FingerprintKey $script:Key
        $o.ExitCode | Should -Be 2
        $o.Result['errors'][0]['code'] | Should -Be 'NotElevated'
        $o.Result['scan']['mode'] | Should -Be 'user'
    }

    It 'machine-wide with elevation scans every fixture profile' {
        $root = Join-Path $TestDrive 'admin'
        Copy-Item -LiteralPath $script:AISFixtureRoot -Destination $root -Recurse
        Set-Content -LiteralPath (Join-Path $root 'fixture.json') -Value '{ "hostName": "ADMIN-PC", "userName": "alice", "isElevated": true, "now": "2026-10-21T09:00:00Z" }'
        $o = Invoke-AISScan -Root $root -MachineWide -FingerprintKey $script:Key
        $o.ExitCode | Should -Be 0
        $o.Result['scan']['mode'] | Should -Be 'machine'
        $o.Result['scan']['elevated'] | Should -BeTrue
        @($o.Result['device']['users']) | Should -Be @('alice', 'bob')
    }

    Context 'collector errors, selection and exit codes' {
        BeforeAll {
            $script:Extra = Join-Path $TestDrive 'extra'
            New-TestCollectorFile -Directory $script:Extra -Id 'RiskyThing' -Body @'
$i = New-AISInventoryItem -Kind 'agent' -Name 'Risky agent' -ToolId 'risky' -UserProfileName $Ctx.UserName
$i
New-AISFinding -RuleId 'AIS-TST-001' -Category 'test' -Severity 'high' -Title 'Risky setting' -ToolId 'risky' -InventoryRef $i.id
New-AISFinding -RuleId 'AIS-TST-002' -Category 'test' -Severity 'low' -Title 'Minor setting'
'@
            New-TestCollectorFile -Directory $script:Extra -Id 'Exploder' -Body "throw ('parse failed near ' + 'CANARY-CONFIG-CONTENT')"
        }

        It 'captures a failing collector in errors[] and still completes' {
            $o = Invoke-AISScan -Root $script:AISFixtureRoot -FingerprintKey $script:Key -CollectorPath $script:Extra -Include 'Exploder', 'Environment'
            $o.ExitCode | Should -Be 2
            $statuses = @{}
            foreach ($c in $o.Result['scan']['collectors']) { $statuses[$c['id']] = $c['status'] }
            $statuses['Exploder'] | Should -Be 'error'
            $statuses['Environment'] | Should -Be 'ok'
            $statuses['RiskyThing'] | Should -Be 'skipped'
            $o.Result['errors'][0]['collector'] | Should -Be 'Exploder'
            (InModuleScope AIStocktake -Parameters @{ D = $o.Result } { param($D) ConvertTo-AISJson $D }) | Should -Not -Match 'CANARY-CONFIG-CONTENT'
        }

        It 'returns exit code 1 when a finding reaches the threshold (findings win over errors)' {
            $o = Invoke-AISScan -Root $script:AISFixtureRoot -FingerprintKey $script:Key -CollectorPath $script:Extra
            $o.ExitCode | Should -Be 1
            $o.Summary['bySeverity']['high'] | Should -Be 1
            $o.Summary['tools'] | Should -Be 1
            $o.Result['findings'][0]['severity'] | Should -Be 'high'
            $o.Result['findings'][0]['inventoryRef'] | Should -Be ($o.Result['inventory'] | Where-Object { $_['toolId'] -eq 'risky' })['id']
        }

        It 'honors -FailOnSeverity and -Exclude' {
            (Invoke-AISScan -Root $script:AISFixtureRoot -FingerprintKey $script:Key -CollectorPath $script:Extra -Exclude 'Exploder' -FailOnSeverity critical).ExitCode | Should -Be 0
            (Invoke-AISScan -Root $script:AISFixtureRoot -FingerprintKey $script:Key -CollectorPath $script:Extra -Exclude 'Exploder', 'RiskyThing' -FailOnSeverity low).ExitCode | Should -Be 0
            (Invoke-AISScan -Root $script:AISFixtureRoot -FingerprintKey $script:Key -CollectorPath $script:Extra -Exclude 'Exploder' -FailOnSeverity low).ExitCode | Should -Be 1
        }

        It 'records an unknown -Include as an error' {
            $o = Invoke-AISScan -Root $script:AISFixtureRoot -FingerprintKey $script:Key -Include 'DoesNotExist'
            $o.ExitCode | Should -Be 2
            $o.Result['errors'][0]['code'] | Should -Be 'UnknownCollector'
        }
    }

    Context 'fatal errors and keys' {
        It 'returns exit code 2 and writes nothing for a missing fixture root' {
            $out = Join-Path $TestDrive 'fatal'
            $o = Invoke-AISScan -Root (Join-Path $TestDrive 'missing-root') -OutputPath $out -FingerprintKey $script:Key -ErrorAction SilentlyContinue -ErrorVariable ev
            $o.ExitCode | Should -Be 2
            $o.Result | Should -BeNullOrEmpty
            Test-Path -LiteralPath $out | Should -BeFalse
            ($ev | Select-Object -First 1).ToString() | Should -Match 'Fixture root not found'
        }

        It 'refuses a key file inside the output folder' {
            $out = Join-Path $TestDrive 'keyout'
            $o = Invoke-AISScan -Root $script:AISFixtureRoot -OutputPath $out -FingerprintKeyPath (Join-Path $out 'k.key') -ErrorAction SilentlyContinue -ErrorVariable ev
            $o.ExitCode | Should -Be 2
            ($ev | Select-Object -First 1).ToString() | Should -Match 'must not be located inside the output folder'
        }

        It 'uses an explicit key file path outside the output folder' -Skip:([bool](Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue) -or $PSVersionTable.PSEdition -eq 'Desktop') {
            $keyPath = Join-Path $TestDrive 'state/fp.key'
            $o1 = Invoke-AISScan -Root $script:AISFixtureRoot -FingerprintKeyPath $keyPath -PrivacyMode
            $o2 = Invoke-AISScan -Root $script:AISFixtureRoot -FingerprintKeyPath $keyPath -PrivacyMode
            Test-Path -LiteralPath $keyPath | Should -BeTrue
            $o1.Result['device']['hostname'] | Should -Be $o2.Result['device']['hostname']
        }
    }

    Context 'command-line wrapper' {
        It 'propagates the exit code to the process' {
            $pwsh = (Get-Process -Id $PID).Path
            $script = Join-Path $script:AISRepoRoot 'scripts/ai-stocktake.ps1'
            $out = Join-Path $TestDrive 'cli'
            $null = & $pwsh -NoProfile -NonInteractive -File $script -Root $script:AISFixtureRoot -OutputPath $out
            $LASTEXITCODE | Should -Be 0
            @(Get-ChildItem -LiteralPath $out -Filter '*.aistocktake.json').Count | Should -Be 1
            $null = & $pwsh -NoProfile -NonInteractive -File $script -Root $script:AISFixtureRoot -OutputPath $out -MachineWide
            $LASTEXITCODE | Should -Be 2
        }
    }
}
