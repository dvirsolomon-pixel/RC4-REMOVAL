Describe 'New-AISScanContext' -Tag 'Unit' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../TestCommon.ps1')
    }

    Context 'fixture mode' {
        It 'maps every root inside the fixture and reads fixture.json' {
            InModuleScope AIStocktake -Parameters @{ Root = $script:AISFixtureRoot } {
                param($Root)
                $ctx = New-AISScanContext -Root $Root
                $ctx.PSObject.TypeNames[0] | Should -Be 'AIS.ScanContext'
                $ctx.IsFixture | Should -BeTrue
                $ctx.Mode | Should -Be 'user'
                $ctx.HostName | Should -Be 'FIXTURE-PC-01'
                $ctx.UserName | Should -Be 'alice'
                $ctx.Platform | Should -Be 'Windows'
                $ctx.Os.version | Should -Be '10.0.26100'
                $ctx.PowerShell.edition | Should -Be 'Desktop'
                $ctx.IsElevated | Should -BeFalse
                foreach ($k in @('UserProfile', 'AppData', 'LocalAppData', 'ProgramData', 'ProgramFiles', 'ProgramFilesX86', 'SystemDrive', 'UsersRoot')) {
                    $ctx.Roots[$k].StartsWith($ctx.FixtureRoot) | Should -BeTrue -Because "$k must stay inside the fixture"
                }
                $ctx.Roots.AppData | Should -Be ([IO.Path]::Combine($ctx.FixtureRoot, 'Users', 'alice', 'AppData', 'Roaming'))
                @($ctx.Profiles).Count | Should -Be 1
                $ctx.Now() | Should -Be ([datetime]::SpecifyKind([datetime]'2026-10-21T08:00:00', [DateTimeKind]::Utc))
                $ctx.Now().Kind | Should -Be ([DateTimeKind]::Utc)
            }
        }

        It 'records NotElevated and scans only the current user when machine-wide is not allowed' {
            InModuleScope AIStocktake -Parameters @{ Root = $script:AISFixtureRoot } {
                param($Root)
                $ctx = New-AISScanContext -Root $Root -MachineWide
                $ctx.Mode | Should -Be 'user'
                @($ctx.Profiles).Count | Should -Be 1
                @($ctx.InitErrors).Count | Should -Be 1
                $ctx.InitErrors[0].code | Should -Be 'NotElevated'
            }
        }

        It 'enumerates all fixture profiles when elevated and machine-wide' {
            $root = Join-Path $TestDrive 'elevated'
            Copy-Item -LiteralPath $script:AISFixtureRoot -Destination $root -Recurse
            New-Item -ItemType Directory -Path (Join-Path $root 'Users/Public') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $root 'fixture.json') -Value '{ "hostName": "ADMIN-PC", "userName": "alice", "isElevated": true }'
            InModuleScope AIStocktake -Parameters @{ Root = $root } {
                param($Root)
                $ctx = New-AISScanContext -Root $Root -MachineWide
                $ctx.Mode | Should -Be 'machine'
                @($ctx.Profiles | ForEach-Object Name) | Should -Be @('alice', 'bob')
                $ctx.Profiles[0].IsCurrent | Should -BeTrue
                $ctx.Profiles[1].Roots.AppData | Should -BeLike '*bob*Roaming'
                @($ctx.InitErrors).Count | Should -Be 0
            }
        }

        It 'applies defaults when fixture.json is missing and fails for a missing root' {
            $root = Join-Path $TestDrive 'bare'
            New-Item -ItemType Directory -Path $root | Out-Null
            InModuleScope AIStocktake -Parameters @{ Root = $root } {
                param($Root)
                $ctx = New-AISScanContext -Root $Root
                $ctx.HostName | Should -Be 'FIXTURE-HOST'
                $ctx.UserName | Should -Be 'fixtureuser'
                $before = [datetime]::UtcNow.AddSeconds(-5)
                $ctx.Now() | Should -BeGreaterThan $before
                { New-AISScanContext -Root (Join-Path $Root 'nope') } | Should -Throw '*Fixture root not found*'
            }
        }

        It 'never prints the fingerprint key in default formatting' {
            $k = New-TestKey
            InModuleScope AIStocktake -Parameters @{ Root = $script:AISFixtureRoot; K = $k } {
                param($Root, $K)
                $ctx = New-AISScanContext -Root $Root -FingerprintKey $K
                $text = $ctx | Out-String
                $text | Should -Not -Match 'FingerprintKey'
                [Convert]::ToBase64String($ctx.FingerprintKey) | Should -Be ([Convert]::ToBase64String($K))
            }
        }
    }

    Context 'fixture providers' {
        It 'returns allowlisted uninstall entries per hive and profile' {
            InModuleScope AIStocktake -Parameters @{ Root = $script:AISFixtureRoot } {
                param($Root)
                $ctx = New-AISScanContext -Root $Root
                $hkcu = @($ctx.Registry.GetUninstallEntries('HKCU'))
                $hkcu.Count | Should -Be 1
                $hkcu[0].DisplayName | Should -Be 'Example App'
                $hkcu[0].Hive | Should -Be 'HKCU'
                @($hkcu[0].PSObject.Properties.Name) | Should -Be @('Hive', 'KeyName', 'DisplayName', 'DisplayVersion', 'Publisher', 'InstallLocation', 'InstallDate')
                @($ctx.Registry.GetUninstallEntries('HKLM')).Count | Should -Be 1
                $bob = [pscustomobject]@{ Name = 'bob' }
                @($ctx.Registry.GetUninstallEntries('HKCU', $bob)).Count | Should -Be 0
                { $ctx.Registry.GetUninstallEntries('HKXX') } | Should -Throw '*HKCU or HKLM*'
            }
        }

        It 'returns process and listener snapshots' {
            InModuleScope AIStocktake -Parameters @{ Root = $script:AISFixtureRoot } {
                param($Root)
                $ctx = New-AISScanContext -Root $Root
                $procs = @($ctx.Processes.GetSnapshot())
                $procs.Count | Should -Be 1
                $procs[0].ProcessId | Should -Be 4242
                $procs[0].Name | Should -Be 'sample.exe'
                $listeners = @($ctx.Listeners.GetListeningPorts())
                $listeners.Count | Should -Be 2
                ($listeners | Where-Object LocalPort -EQ 1234).LocalAddress | Should -Be '0.0.0.0'
            }
        }

        It 'returns empty results when snapshot files are missing' {
            $root = Join-Path $TestDrive 'empty'
            New-Item -ItemType Directory -Path $root | Out-Null
            InModuleScope AIStocktake -Parameters @{ Root = $root } {
                param($Root)
                $ctx = New-AISScanContext -Root $Root
                @($ctx.Registry.GetUninstallEntries('HKLM')).Count | Should -Be 0
                @($ctx.Processes.GetSnapshot()).Count | Should -Be 0
                @($ctx.Listeners.GetListeningPorts()).Count | Should -Be 0
            }
        }
    }

    Context 'real mode' {
        It 'builds a context for the current machine without touching the providers' {
            InModuleScope AIStocktake {
                $ctx = New-AISScanContext
                $ctx.IsFixture | Should -BeFalse
                $ctx.Mode | Should -Be 'user'
                $ctx.UserName | Should -Be ([Environment]::UserName)
                $ctx.Roots.UserProfile | Should -Not -BeNullOrEmpty
                $ctx.Registry.Mode | Should -Be 'Real'
                @('Windows', 'Linux', 'MacOS') | Should -Contain $ctx.Platform
            }
        }

        It 'real providers run without throwing on this platform' {
            InModuleScope AIStocktake {
                $ctx = New-AISScanContext
                { $null = $ctx.Registry.GetUninstallEntries('HKCU') } | Should -Not -Throw
                { $null = $ctx.Processes.GetSnapshot() } | Should -Not -Throw
                { $null = $ctx.Listeners.GetListeningPorts() } | Should -Not -Throw
            }
        }
    }

    Context 'listener output parsers' {
        It 'parses Windows netstat output' {
            InModuleScope AIStocktake {
                $text = @'
Active Connections

  Proto  Local Address          Foreign Address        State           PID
  TCP    0.0.0.0:135            0.0.0.0:0              LISTENING       1100
  TCP    127.0.0.1:11434        0.0.0.0:0              LISTENING       5120
  TCP    10.0.0.5:50000         20.1.2.3:443           ESTABLISHED     7000
  TCP    [::]:1234              [::]:0                 LISTENING       6000
'@
                $r = @(ConvertFrom-AISNetstatOutput -Text $text)
                $r.Count | Should -Be 3
                ($r | Where-Object LocalPort -EQ 11434).ProcessId | Should -Be 5120
                ($r | Where-Object LocalPort -EQ 1234).LocalAddress | Should -Be '::'
            }
        }

        It 'parses Linux ss output' {
            InModuleScope AIStocktake {
                $text = @'
LISTEN 0      4096       127.0.0.1:11434      0.0.0.0:*    users:(("ollama",pid=812,fd=3))
LISTEN 0      128          0.0.0.0:22         0.0.0.0:*
LISTEN 0      511                *:1234             *:*
'@
                $r = @(ConvertFrom-AISSsOutput -Text $text)
                $r.Count | Should -Be 3
                ($r | Where-Object LocalPort -EQ 11434).ProcessId | Should -Be 812
                ($r | Where-Object LocalPort -EQ 1234).LocalAddress | Should -Be '0.0.0.0'
                ($r | Where-Object LocalPort -EQ 22).ProcessId | Should -BeNullOrEmpty
            }
        }
    }
}
