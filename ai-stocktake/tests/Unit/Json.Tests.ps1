Describe 'JSON helpers' -Tag 'Unit' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../TestCommon.ps1')
    }

    Context 'ConvertFrom-AISJsonC' {
        It 'strips line and block comments and trailing commas' {
            InModuleScope AIStocktake {
                $text = @'
{
  // line comment
  "a": 1, /* block
  comment */ "b": [1, 2, 3,],
  "c": { "d": true, },
}
'@
                $o = ConvertFrom-AISJsonC -Text $text
                $o.a | Should -Be 1
                @($o.b).Count | Should -Be 3
                $o.c.d | Should -BeTrue
            }
        }

        It 'keeps comment-like sequences and commas inside strings' {
            InModuleScope AIStocktake {
                $o = ConvertFrom-AISJsonC -Text '{ "url": "https://example.invalid/a//b", "s": "x /* y */ z,]", "q": "say \"hi\" // ok" }'
                $o.url | Should -Be 'https://example.invalid/a//b'
                $o.s | Should -Be 'x /* y */ z,]'
                $o.q | Should -Be 'say "hi" // ok'
            }
        }

        It 'handles a BOM and a one-element top-level array' {
            InModuleScope AIStocktake {
                $o = ConvertFrom-AISJsonC -Text ([string][char]0xFEFF + '[ { "a": 1 } ]')
                , $o | Should -BeOfType [object[]]
                $o.Count | Should -Be 1
                $o[0].a | Should -Be 1
            }
        }

        It 'never includes the content in a parse error' {
            InModuleScope AIStocktake {
                $canary = 'CANARY' + [guid]::NewGuid().ToString('N')
                $err = $null
                try { ConvertFrom-AISJsonC -Text ('{ "k": "' + $canary + '" ') } catch { $err = $_ }
                $err | Should -Not -BeNullOrEmpty
                $err.Exception.Message | Should -Not -Match $canary
                $err.Exception.Message | Should -Be 'JSON content could not be parsed.'
                (Get-AISSafeErrorInfo -ErrorObject $err).Code | Should -Be 'JsonParseError'
            }
        }

        It 'rejects empty content' {
            InModuleScope AIStocktake {
                { ConvertFrom-AISJsonC -Text '  // only a comment' } | Should -Throw 'JSON content is empty.'
            }
        }
    }

    Context 'Read-AISJsonFile' {
        It 'reads a JSONC file and reports missing or invalid files by path only' {
            InModuleScope AIStocktake -Parameters @{ Dir = $TestDrive } {
                param($Dir)
                $good = Join-Path $Dir 'good.json'
                Set-Content -LiteralPath $good -Value '{ "x": "y", // c
}' -Encoding UTF8
                (Read-AISJsonFile -LiteralPath $good).x | Should -Be 'y'

                { Read-AISJsonFile -LiteralPath (Join-Path $Dir 'missing.json') } | Should -Throw '*File not found*'

                $canary = 'CANARY' + [guid]::NewGuid().ToString('N')
                $bad = Join-Path $Dir 'bad.json'
                Set-Content -LiteralPath $bad -Value ('{ "k": ' + $canary) -Encoding UTF8
                $err = $null
                try { Read-AISJsonFile -LiteralPath $bad } catch { $err = $_ }
                $err.Exception.Message | Should -BeLike '*not valid JSON*'
                $err.Exception.Message | Should -Not -Match $canary
            }
        }

        It 'refuses files above the size limit' {
            InModuleScope AIStocktake -Parameters @{ Dir = $TestDrive } {
                param($Dir)
                $f = Join-Path $Dir 'big.json'
                Set-Content -LiteralPath $f -Value ('[' + ('1,' * 600) + '1]') -Encoding UTF8
                { Read-AISJsonFile -LiteralPath $f -MaxBytes 100 } | Should -Throw '*size limit*'
            }
        }
    }

    Context 'Write-AISJsonFile and ConvertTo-AISPlainData' {
        It 'writes UTF-8 without BOM and keeps nesting deeper than 2 levels' {
            InModuleScope AIStocktake -Parameters @{ Dir = $TestDrive } {
                param($Dir)
                $path = Join-Path (Join-Path $Dir 'sub') 'out.json'
                $obj = [ordered]@{ a = [ordered]@{ b = [ordered]@{ c = [ordered]@{ d = 'deep' } } }; e = @(); f = @('one') }
                $written = Write-AISJsonFile -LiteralPath $path -InputObject $obj
                $bytes = [IO.File]::ReadAllBytes($written)
                $bytes[0] | Should -Not -Be 0xEF
                $round = Get-Content -LiteralPath $written -Raw | ConvertFrom-Json
                $round.a.b.c.d | Should -Be 'deep'
                (Get-Content -LiteralPath $written -Raw) | Should -Match '"f":\s*\[\s*"one"\s*\]'
                (Get-Content -LiteralPath $written -Raw) | Should -Match '"e":\s*\[\s*\]'
            }
        }

        It 'produces plain, deterministic data' {
            InModuleScope AIStocktake {
                $date = [datetime]::SpecifyKind([datetime]'2026-01-02T03:04:05.678', [DateTimeKind]::Utc)
                $plain = ConvertTo-AISPlainData -InputObject @{ z = 1; a = $date; m = [pscustomobject]@{ y = $true; x = @(1, 'two') } }
                @($plain.Keys) | Should -Be @('a', 'm', 'z')
                $plain['a'] | Should -Be '2026-01-02T03:04:05.678Z'
                $plain['m']['y'] | Should -BeTrue
                $plain['m']['x'][1] | Should -Be 'two'
                , $plain['m']['x'] | Should -BeOfType [object[]]
            }
        }

        It 'unwraps strings carrying extended properties' {
            InModuleScope AIStocktake {
                $s = 'text' | Add-Member -NotePropertyName PSPath -NotePropertyValue 'x' -PassThru
                $json = ConvertTo-AISJson -InputObject (ConvertTo-AISPlainData -InputObject @{ s = $s }) -Compress
                $json | Should -Be '{"s":"text"}'
            }
        }

        It 'applies privacy rules to values but not keys' {
            InModuleScope AIStocktake {
                $rules = @(@{ Regex = [regex]'alice'; Replacement = 'U' })
                $plain = ConvertTo-AISPlainData -InputObject ([ordered]@{ alice = 'hello alice' }) -PrivacyRules $rules
                $plain['alice'] | Should -Be 'hello U'
            }
        }
    }
}
