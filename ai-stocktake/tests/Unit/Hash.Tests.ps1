BeforeDiscovery {
    $script:OnWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or [bool](Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue)
}

Describe 'Hashing helpers' -Tag 'Unit' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../TestCommon.ps1')
    }

    Context 'New-AISDeterministicId' {
        It 'is stable, 32 hex chars, and path-normalized' {
            InModuleScope AIStocktake {
                $a = New-AISDeterministicId -Parts @('finding', 'AIS-MCP-001', '/mcpServers/x') -PathParts @('C:\Users\A\.cursor\mcp.json')
                $b = New-AISDeterministicId -Parts @('finding', 'AIS-MCP-001', '/mcpServers/x') -PathParts @('c:/users/a/.cursor/mcp.json')
                $a | Should -Match '^[0-9a-f]{32}$'
                $a | Should -Be $b
            }
        }

        It 'changes when any part changes and does not confuse part boundaries' {
            InModuleScope AIStocktake {
                $base = New-AISDeterministicId -Parts @('a', 'b')
                New-AISDeterministicId -Parts @('a', 'c') | Should -Not -Be $base
                New-AISDeterministicId -Parts @('ab', '') | Should -Not -Be $base
                New-AISDeterministicId -Parts @('a', $null, 'b') | Should -Not -Be $base
            }
        }
    }

    Context 'New-AISFingerprint' {
        It 'matches RFC 4231 HMAC-SHA256 test case 1' {
            InModuleScope AIStocktake {
                $key = [byte[]](@(0x0b) * 20)
                Get-AISHmacHex -Key $key -Text 'Hi There' | Should -Be 'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7'
                New-AISFingerprint -Key $key -Value 'Hi There' | Should -Be 'hmac-sha256:b0344c61d8db3853'
            }
        }

        It 'returns an hmac-sha256 prefix with 16 hex chars, depends on the key, and never contains the value' {
            $k1 = New-TestKey
            $k2 = New-TestKey
            InModuleScope AIStocktake -Parameters @{ K1 = $k1; K2 = $k2 } {
                param($K1, $K2)
                $value = 'canary-' + [guid]::NewGuid().ToString('N')
                $fp1 = New-AISFingerprint -Key $K1 -Value $value
                $fp1 | Should -Match '^hmac-sha256:[0-9a-f]{16}$'
                New-AISFingerprint -Key $K1 -Value $value | Should -Be $fp1
                New-AISFingerprint -Key $K2 -Value $value | Should -Not -Be $fp1
                $fp1 | Should -Not -Match $value
            }
        }

        It 'refuses short keys with a message that does not echo the value' {
            InModuleScope AIStocktake {
                $err = $null
                try { New-AISFingerprint -Key ([byte[]](1..8)) -Value 'do-not-echo-me' } catch { $err = $_ }
                $err.Exception.Message | Should -BeLike '*at least 16 bytes*'
                $err.Exception.Message | Should -Not -Match 'do-not-echo-me'
            }
        }
    }

    Context 'Pseudonyms and keyed ids' {
        It 'pseudonyms are case-insensitive and differ from secret fingerprints' {
            $k = New-TestKey
            InModuleScope AIStocktake -Parameters @{ K = $k } {
                param($K)
                $p = ConvertTo-AISPseudonym -Key $K -Value 'Alice'
                $p | Should -Match '^hmac:[0-9a-f]{16}$'
                ConvertTo-AISPseudonym -Key $K -Value 'alice' | Should -Be $p
                (New-AISFingerprint -Key $K -Value 'alice').Substring(12) | Should -Not -Be $p.Substring(5)
                ConvertTo-AISKeyedId -Key $K -Id ('a' * 32) | Should -Match '^[0-9a-f]{32}$'
            }
        }
    }

    Context 'Get-AISFingerprintKey' {
        It 'creates a key once and reads the same key back' -Skip:$script:OnWindows {
            InModuleScope AIStocktake -Parameters @{ Dir = $TestDrive } {
                param($Dir)
                $path = Join-Path (Join-Path $Dir 'state') 'fingerprint.key'
                { Get-AISFingerprintKey -Path $path } | Should -Throw '*not found*'
                $k1 = Get-AISFingerprintKey -Path $path -Create
                $k1.Length | Should -Be 32
                $k2 = Get-AISFingerprintKey -Path $path -Create
                [Convert]::ToBase64String($k2) | Should -Be ([Convert]::ToBase64String($k1))
                (Get-Content -LiteralPath $path -Raw) | Should -Match '^AISKEY1 raw '
                if ($PSVersionTable.PSVersion.Major -ge 7) {
                    ((Get-Item -LiteralPath $path).UnixFileMode -eq [IO.UnixFileMode]'UserRead, UserWrite') | Should -BeTrue
                }
            }
        }

        It 'protects the key with DPAPI on Windows' -Tag 'WindowsOnly' -Skip:(-not $script:OnWindows) {
            InModuleScope AIStocktake -Parameters @{ Dir = $TestDrive } {
                param($Dir)
                $path = Join-Path $Dir 'fingerprint.key'
                $k1 = Get-AISFingerprintKey -Path $path -Create
                (Get-Content -LiteralPath $path -Raw) | Should -Match '^AISKEY1 dpapi '
                (Get-Content -LiteralPath $path -Raw) | Should -Not -Match ([regex]::Escape([Convert]::ToBase64String($k1)))
                [Convert]::ToBase64String((Get-AISFingerprintKey -Path $path)) | Should -Be ([Convert]::ToBase64String($k1))
            }
        }

        It 'rejects corrupt key files' {
            InModuleScope AIStocktake -Parameters @{ Dir = $TestDrive } {
                param($Dir)
                $path = Join-Path $Dir 'bad.key'
                Set-Content -LiteralPath $path -Value 'garbage'
                { Get-AISFingerprintKey -Path $path } | Should -Throw '*unknown format*'
            }
        }

        It 'defaults to a per-user location outside the repository' {
            InModuleScope AIStocktake {
                $p = Get-AISDefaultKeyPath
                $p | Should -BeLike '*AIStocktake*fingerprint.key'
                $repo = Split-Path (Split-Path $script:AISModuleRoot -Parent) -Parent
                $p.StartsWith($repo) | Should -BeFalse
            }
        }
    }
}
