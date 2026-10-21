Describe 'Resolve-AISPath' -Tag 'Unit' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../TestCommon.ps1')
    }

    It 'resolves a token template with backslashes' {
        InModuleScope AIStocktake {
            $roots = [ordered]@{ AppData = (Join-Path ([IO.Path]::GetTempPath()) 'ais-appdata') }
            $p = Resolve-AISPath -Template '{AppData}\Claude\claude_desktop_config.json' -Roots $roots
            $expected = Join-Path (Join-Path $roots.AppData 'Claude') 'claude_desktop_config.json'
            $p | Should -Be $expected
        }
    }

    It 'resolves forward slashes and repeated separators the same way' {
        InModuleScope AIStocktake {
            $roots = [ordered]@{ UserProfile = (Join-Path ([IO.Path]::GetTempPath()) 'u') }
            $a = Resolve-AISPath -Template '{UserProfile}/.cursor//mcp.json' -Roots $roots
            $b = Resolve-AISPath -Template '{UserProfile}\.cursor\mcp.json' -Roots $roots
            $a | Should -Be $b
        }
    }

    It 'uses the current-user roots of a context' {
        InModuleScope AIStocktake -Parameters @{ Root = $script:AISFixtureRoot } {
            param($Root)
            $ctx = New-AISScanContext -Root $Root
            $p = Resolve-AISPath -Template '{UserProfile}\.claude.json' -Context $ctx
            $p | Should -Be (Join-Path (Join-Path (Join-Path $ctx.FixtureRoot 'Users') 'alice') '.claude.json')
        }
    }

    It 'rejects unknown tokens, tokens in the middle and unavailable roots' {
        InModuleScope AIStocktake {
            $roots = [ordered]@{ AppData = '/x'; ProgramFiles = '' }
            { Resolve-AISPath -Template '{Nope}\a' -Roots $roots } | Should -Throw '*Unknown path token*'
            { Resolve-AISPath -Template 'a\{AppData}\b' -Roots $roots } | Should -Throw '*first segment*'
            { Resolve-AISPath -Template '{ProgramFiles}\a' -Roots $roots } | Should -Throw '*not available*'
            { Resolve-AISPath -Template '{LocalAppData}\a' -Roots $roots } | Should -Throw '*not available*'
        }
    }

    It 'passes through templates without a token' {
        InModuleScope AIStocktake {
            $sep = [IO.Path]::DirectorySeparatorChar
            Resolve-AISPath -Template 'a\b/c' -Roots @{} | Should -Be ('a' + $sep + 'b' + $sep + 'c')
        }
    }
}

Describe 'ConvertTo-AISNormalizedPath' -Tag 'Unit' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../TestCommon.ps1')
    }

    It 'normalizes separators, case and trailing separators' {
        InModuleScope AIStocktake {
            ConvertTo-AISNormalizedPath 'C:\Users\Alice\\X.json\' | Should -Be 'c:/users/alice/x.json'
            ConvertTo-AISNormalizedPath '' | Should -Be ''
            ConvertTo-AISNormalizedPath $null | Should -Be ''
            ConvertTo-AISNormalizedPath '/' | Should -Be '/'
        }
    }
}
