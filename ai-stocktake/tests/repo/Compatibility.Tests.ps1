# Repo hygiene: every .ps1/.psm1/.psd1 file must use Windows PowerShell 5.1
# compatible syntax. PSScriptAnalyzer's PSUseCompatibleSyntax rule does not
# flag PowerShell 7-only operators, so this test checks the AST directly.
# On Windows PowerShell 5.1 those operators are parse errors, so the same test
# also fails there.

BeforeDiscovery {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:PowerShellFiles = @(
        Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Force |
            Where-Object {
                $_.FullName -notmatch '[\\/]\.git[\\/]' -and
                @('.ps1', '.psm1', '.psd1') -contains $_.Extension.ToLowerInvariant()
            } |
            ForEach-Object {
                @{
                    FullName     = $_.FullName
                    RelativePath = $_.FullName.Substring($repoRoot.Length).TrimStart('\', '/')
                }
            }
    )
}

Describe 'PowerShell 5.1 compatible syntax' -Tag 'Unit', 'Repo' {
    BeforeAll {
        # AST node type names that only exist in PowerShell 7+. Compared by
        # name because the types do not exist in Windows PowerShell 5.1.
        $script:Ps7OnlyAstTypes = @('TernaryExpressionAst', 'PipelineChainAst')
        $script:Ps7OnlyTokenKinds = @('QuestionQuestion', 'QuestionQuestionEquals', 'QuestionDot', 'QuestionLBracket', 'AndAnd', 'OrOr')

        function Find-Ps7OnlySyntax {
            param([string] $Text)
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref] $tokens, [ref] $errors)
            $hits = New-Object System.Collections.Generic.List[string]
            foreach ($e in $errors) {
                $hits.Add(('line {0}: parse error: {1}' -f $e.Extent.StartLineNumber, $e.Message))
            }
            foreach ($t in $tokens) {
                if ($script:Ps7OnlyTokenKinds -contains $t.Kind.ToString()) {
                    $hits.Add(('line {0}: operator {1}' -f $t.Extent.StartLineNumber, $t.Text))
                }
            }
            $nodes = $ast.FindAll({ param($n) $script:Ps7OnlyAstTypes -contains $n.GetType().Name }, $true)
            foreach ($n in $nodes) {
                $hits.Add(('line {0}: {1}' -f $n.Extent.StartLineNumber, $n.GetType().Name))
            }
            $parallel = $ast.FindAll({
                    param($n)
                    $n -is [System.Management.Automation.Language.CommandParameterAst] -and
                    $n.ParameterName -eq 'Parallel'
                }, $true)
            foreach ($n in $parallel) {
                $hits.Add(('line {0}: -Parallel' -f $n.Extent.StartLineNumber))
            }
            return , $hits.ToArray()
        }
    }

    It 'detects PowerShell 7-only syntax in generated samples (self-test)' {
        Find-Ps7OnlySyntax -Text '$a = $b ?? 1' | Should -Not -BeNullOrEmpty
        Find-Ps7OnlySyntax -Text '$a = $b ? 1 : 2' | Should -Not -BeNullOrEmpty
        Find-Ps7OnlySyntax -Text '${b}?.Name' | Should -Not -BeNullOrEmpty
        Find-Ps7OnlySyntax -Text 'Get-Item . && Get-Item .' | Should -Not -BeNullOrEmpty
        Find-Ps7OnlySyntax -Text '1..3 | ForEach-Object -Parallel { $_ }' | Should -Not -BeNullOrEmpty
        Find-Ps7OnlySyntax -Text 'if ($a) { 1 } else { 2 }' | Should -BeNullOrEmpty
    }

    It '<RelativePath> uses only Windows PowerShell 5.1 syntax' -ForEach $script:PowerShellFiles {
        $text = [System.IO.File]::ReadAllText($FullName)
        Find-Ps7OnlySyntax -Text $text | Should -BeNullOrEmpty
    }
}
