Describe 'Collector registration and execution' -Tag 'Unit' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../TestCommon.ps1')
    }

    Context 'Import-AISCollector' {
        It 'discovers the built-in Environment collector' {
            $c = @(Get-AISCollector)
            $c.Id | Should -Contain 'Environment'
            ($c | Where-Object Id -EQ 'Environment').Version | Should -Match '^\d+\.\d+\.\d+$'
        }

        It 'reports invalid collector files and keeps valid ones' {
            $dir = Join-Path $TestDrive 'mixed'
            New-TestCollectorFile -Directory $dir -Id 'GoodOne' -Body 'New-AISInventoryItem -Kind app -Name Good'
            New-TestCollectorFile -Directory $dir -Id 'BadKeys' -Extra "Platform = 'Windows'"
            New-TestCollectorFile -Directory $dir -Id 'BadPlat' -Extra "Platforms = @('Amiga')"
            Set-Content -LiteralPath (Join-Path $dir 'NoAssign.ps1') -Value '$x = 1'
            Set-Content -LiteralPath (Join-Path $dir 'Broken.ps1') -Value 'throw "boom"'
            Set-Content -LiteralPath (Join-Path $dir 'Mismatch.ps1') -Value '$Collector = @{ Id = "Other"; Version = "1.0.0"; Invoke = {} }'
            InModuleScope AIStocktake -Parameters @{ Dir = $dir } {
                param($Dir)
                $r = Import-AISCollector -Path @($Dir)
                @($r.Collectors.Id) | Should -Be @('GoodOne')
                $codes = @($r.Errors | ForEach-Object { $_.collector + ':' + $_.code })
                $codes | Should -Contain 'BadKeys:InvalidCollector'
                $codes | Should -Contain 'BadPlat:InvalidCollector'
                $codes | Should -Contain 'NoAssign:InvalidCollector'
                $codes | Should -Contain 'Broken:InvalidCollector'
                $codes | Should -Contain 'Mismatch:InvalidCollector'
                ($r.Errors | Where-Object collector -EQ 'Broken').message | Should -Not -Match 'boom'
            }
        }

        It 'rejects duplicate ids across folders' {
            $d1 = Join-Path $TestDrive 'd1'
            $d2 = Join-Path $TestDrive 'd2'
            New-TestCollectorFile -Directory $d1 -Id 'Twice'
            New-TestCollectorFile -Directory $d2 -Id 'Twice'
            InModuleScope AIStocktake -Parameters @{ D1 = $d1; D2 = $d2 } {
                param($D1, $D2)
                $r = Import-AISCollector -Path @($D1, $D2)
                @($r.Collectors).Count | Should -Be 1
                $r.Errors[0].code | Should -Be 'DuplicateCollector'
            }
        }
    }

    Context 'Select-AISCollector' {
        It 'applies include and exclude wildcards and reports unknown includes' {
            InModuleScope AIStocktake {
                $defs = @('Apps', 'McpConfigs', 'Processes', 'Environment') | ForEach-Object { [pscustomobject]@{ Id = $_ } }
                $r = Select-AISCollector -Collectors $defs -Include @('Mcp*', 'Apps', 'Nope') -Exclude @('apps')
                @($r.Selected.Id) | Should -Be @('McpConfigs')
                $r.Errors[0].code | Should -Be 'UnknownCollector'
                $r.Errors[0].message | Should -Match 'Nope'
                @((Select-AISCollector -Collectors $defs -Exclude @('P*')).Selected.Id) | Should -Be @('Apps', 'McpConfigs', 'Environment')
                @((Select-AISCollector -Collectors $defs).Selected).Count | Should -Be 4
            }
        }
    }

    Context 'Invoke-AISCollector' {
        BeforeAll {
            $script:Dir = Join-Path $TestDrive 'run'
            New-TestCollectorFile -Directory $script:Dir -Id 'Mixed' -Body @'
New-AISInventoryItem -Kind app -Name 'A'
New-AISFinding -RuleId 'AIS-TST-001' -Category 'test' -Severity 'high' -Title 'T'
New-AISScanError -Collector 'Whatever' -Code 'PartialRead' -Message 'One file skipped.'
'stray string'
@{ not = 'typed' }
'@
            New-TestCollectorFile -Directory $script:Dir -Id 'ThrowsUnsafe' -Body @'
New-AISInventoryItem -Kind app -Name 'Before'
throw ('config content: ' + 'SENSITIVE-CANARY-VALUE')
'@
            New-TestCollectorFile -Directory $script:Dir -Id 'ThrowsSafe' -Body "throw (New-AISSafeException -Code 'ConfigUnreadable' -Message 'Cannot read settings file.')"
            New-TestCollectorFile -Directory $script:Dir -Id 'WritesError' -Body "Write-Error 'SENSITIVE-CANARY-VALUE'; New-AISInventoryItem -Kind app -Name 'After'"
            New-TestCollectorFile -Directory $script:Dir -Id 'MacOnly' -Extra "Platforms = @('MacOS')" -Body "New-AISInventoryItem -Kind app -Name 'X'"
            New-TestCollectorFile -Directory $script:Dir -Id 'AdminOnly' -Extra 'RequiresElevation = $true' -Body "New-AISInventoryItem -Kind app -Name 'X'"
            New-TestCollectorFile -Directory $script:Dir -Id 'Slow' -Extra 'TimeoutSeconds = 1' -Body 'Start-Sleep -Milliseconds 1200'
            New-TestCollectorFile -Directory $script:Dir -Id 'UsesContext' -Body @'
$cfg = Resolve-AISPath -Template '{AppData}\Example\settings.json' -Context $Ctx
$procs = @($Ctx.Processes.GetSnapshot())
New-AISInventoryItem -Kind app -Name ('procs-' + $procs.Count) -Path $cfg -UserProfileName $Ctx.UserName
'@
        }

        It 'routes typed output, re-labels emitted errors and drops untyped output' {
            InModuleScope AIStocktake -Parameters @{ Dir = $script:Dir; Root = $script:AISFixtureRoot } {
                param($Dir, $Root)
                $ctx = New-AISScanContext -Root $Root
                $def = (Import-AISCollector -Path @($Dir)).Collectors | Where-Object Id -EQ 'Mixed'
                $r = Invoke-AISCollector -Definition $def -Context $ctx -Catalog $null
                $r.Status | Should -Be 'ok'
                $r.Inventory.Count | Should -Be 1
                $r.Findings.Count | Should -Be 1
                $codes = @($r.Errors | ForEach-Object code)
                $codes | Should -Contain 'PartialRead'
                $codes | Should -Contain 'InvalidCollectorOutput'
                @($r.Errors | ForEach-Object collector | Sort-Object -Unique) | Should -Be @('Mixed')
            }
        }

        It 'captures an unsafe exception with a generic message and keeps earlier output' {
            InModuleScope AIStocktake -Parameters @{ Dir = $script:Dir; Root = $script:AISFixtureRoot } {
                param($Dir, $Root)
                $ctx = New-AISScanContext -Root $Root
                $def = (Import-AISCollector -Path @($Dir)).Collectors | Where-Object Id -EQ 'ThrowsUnsafe'
                $r = Invoke-AISCollector -Definition $def -Context $ctx -Catalog $null
                $r.Status | Should -Be 'error'
                $r.Inventory.Count | Should -Be 1
                $r.Errors[0].code | Should -Be 'CollectorFailed'
                $r.Errors[0].message | Should -Not -Match 'SENSITIVE-CANARY-VALUE'
                $r.Errors[0].message | Should -Match 'ThrowsUnsafe'
            }
        }

        It 'keeps the message and code of a safe exception' {
            InModuleScope AIStocktake -Parameters @{ Dir = $script:Dir; Root = $script:AISFixtureRoot } {
                param($Dir, $Root)
                $ctx = New-AISScanContext -Root $Root
                $def = (Import-AISCollector -Path @($Dir)).Collectors | Where-Object Id -EQ 'ThrowsSafe'
                $r = Invoke-AISCollector -Definition $def -Context $ctx -Catalog $null
                $r.Errors[0].code | Should -Be 'ConfigUnreadable'
                $r.Errors[0].message | Should -Be 'Cannot read settings file.'
            }
        }

        It 'treats non-terminating errors as failures without leaking their text' {
            InModuleScope AIStocktake -Parameters @{ Dir = $script:Dir; Root = $script:AISFixtureRoot } {
                param($Dir, $Root)
                $ctx = New-AISScanContext -Root $Root
                $def = (Import-AISCollector -Path @($Dir)).Collectors | Where-Object Id -EQ 'WritesError'
                $r = Invoke-AISCollector -Definition $def -Context $ctx -Catalog $null
                $r.Status | Should -Be 'error'
                $r.Inventory.Count | Should -Be 0
                $r.Errors[0].message | Should -Not -Match 'SENSITIVE-CANARY-VALUE'
            }
        }

        It 'skips collectors for other platforms or needing elevation' {
            InModuleScope AIStocktake -Parameters @{ Dir = $script:Dir; Root = $script:AISFixtureRoot } {
                param($Dir, $Root)
                $ctx = New-AISScanContext -Root $Root
                $defs = (Import-AISCollector -Path @($Dir)).Collectors
                $mac = Invoke-AISCollector -Definition ($defs | Where-Object Id -EQ 'MacOnly') -Context $ctx -Catalog $null
                $mac.Status | Should -Be 'skipped'
                $mac.Reason | Should -Match 'Windows'
                $adm = Invoke-AISCollector -Definition ($defs | Where-Object Id -EQ 'AdminOnly') -Context $ctx -Catalog $null
                $adm.Status | Should -Be 'skipped'
                $adm.Inventory.Count | Should -Be 0
            }
        }

        It 'flags a soft timeout without discarding the run' {
            InModuleScope AIStocktake -Parameters @{ Dir = $script:Dir; Root = $script:AISFixtureRoot } {
                param($Dir, $Root)
                $ctx = New-AISScanContext -Root $Root
                $def = (Import-AISCollector -Path @($Dir)).Collectors | Where-Object Id -EQ 'Slow'
                $r = Invoke-AISCollector -Definition $def -Context $ctx -Catalog $null
                $r.Status | Should -Be 'ok'
                $r.Errors[0].code | Should -Be 'SoftTimeoutExceeded'
            }
        }

        It 'lets collectors use the context, path resolver and providers' {
            InModuleScope AIStocktake -Parameters @{ Dir = $script:Dir; Root = $script:AISFixtureRoot } {
                param($Dir, $Root)
                $ctx = New-AISScanContext -Root $Root
                $def = (Import-AISCollector -Path @($Dir)).Collectors | Where-Object Id -EQ 'UsesContext'
                $r = Invoke-AISCollector -Definition $def -Context $ctx -Catalog $null
                $r.Status | Should -Be 'ok'
                $r.Inventory[0].name | Should -Be 'procs-1'
                $r.Inventory[0].path | Should -BeLike '*alice*Roaming*Example*settings.json'
            }
        }
    }

    Context 'Import-AISCatalog' {
        It 'returns an empty catalog when the folder is missing' {
            InModuleScope AIStocktake -Parameters @{ Dir = (Join-Path $TestDrive 'nocatalog') } {
                param($Dir)
                $r = Import-AISCatalog -Path $Dir
                $r.Catalog.Version | Should -Be '0.0.0'
                @($r.Errors).Count | Should -Be 0
            }
        }

        It 'loads JSON files, reads the version and reports parse errors safely' {
            $dir = Join-Path $TestDrive 'catalog'
            New-Item -ItemType Directory -Path (Join-Path $dir 'tools') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $dir 'catalog.json') -Value '{ "version": "2026.10.0" }'
            Set-Content -LiteralPath (Join-Path $dir 'tools/cursor.json') -Value '{ "id": "cursor", // jsonc
}'
            Set-Content -LiteralPath (Join-Path $dir 'broken.json') -Value '{ "x": CANARYTEXT'
            InModuleScope AIStocktake -Parameters @{ Dir = $dir } {
                param($Dir)
                $r = Import-AISCatalog -Path $Dir
                $r.Catalog.Version | Should -Be '2026.10.0'
                $r.Catalog.Data['tools/cursor'].id | Should -Be 'cursor'
                $r.Errors[0].code | Should -Be 'CatalogParseError'
                $r.Errors[0].message | Should -Not -Match 'CANARYTEXT'
            }
        }
    }
}
