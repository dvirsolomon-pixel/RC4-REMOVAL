# Repo hygiene: .gitignore rules must never hide source, tests or fixtures,
# and must keep ignoring scan outputs and local secret files.
# Uses "git check-ignore --no-index" so tracked files are checked against the
# patterns too. Skips gracefully when git is missing or this folder is not in
# a git work tree (for example, a source zip download).

BeforeDiscovery {
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:SkipGit = $true
    if (Get-Command -Name 'git' -CommandType Application -ErrorAction SilentlyContinue) {
        $inside = & git -C $script:RepoRoot rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -eq 0 -and "$inside".Trim() -eq 'true') {
            $script:SkipGit = $false
        }
    }

    # Canonical paths that must never be ignored. They need not exist: they
    # cover names that naive rules (*token*, credentials*, .env, *.key,
    # unanchored secrets/ or reports/) used to swallow.
    $script:MustTrack = @(
        'src/AIStocktake.psm1',
        'src/AIStocktake.psd1',
        'src/Private/Register-EnrollmentToken.ps1',
        'src/Private/Collectors/McpConfigs.ps1',
        'tests/NoTokenLeak.Tests.ps1',
        'tests/fixtures/profiles/dev/home/.aws/credentials',
        'tests/fixtures/profiles/dev/home/.env',
        'tests/fixtures/profiles/dev/home/.env.local',
        'tests/fixtures/profiles/dev/home/secrets/api.json',
        'tests/fixtures/profiles/dev/home/fake.key',
        'tests/fixtures/profiles/dev/home/fake.pem',
        'tests/fixtures/profiles/dev/home/fake.key.tmpl',
        'tests/fixtures/profiles/dev/reports/report.csv',
        'tests/fixtures/profiles/dev/logs/app.log',
        'tests/fixtures/expected/clean.aistocktake.json',
        'schemas/credentials.schema.json',
        'schemas/scan-result.v1.schema.json',
        'docs/enrollment-token-flow.md',
        '.github/workflows/ci.yml',
        'PSScriptAnalyzerSettings.psd1',
        'README.md',
        'LICENSE',
        'SECURITY.md'
    ) | ForEach-Object { @{ Path = $_ } }

    # Generated outputs and local secrets that must stay ignored.
    $script:MustIgnore = @(
        'out/scan.json',
        'reports/report.html',
        'machine.aistocktake.json',
        'machine.aistocktake.html',
        '.env',
        '.env.local'
    ) | ForEach-Object { @{ Path = $_ } }
}

Describe '.gitignore rules' -Tag 'Unit', 'Repo' -Skip:$script:SkipGit {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

        # Returns the subset of relative paths that git would ignore.
        function Get-IgnoredPath {
            param([string[]] $Path)
            if (-not $Path -or $Path.Count -eq 0) { return @() }
            $out = $Path | & git -C $script:RepoRoot check-ignore --no-index --stdin 2>&1
            if ($LASTEXITCODE -gt 1) {
                throw "git check-ignore failed (exit $LASTEXITCODE): $out"
            }
            if ($LASTEXITCODE -eq 1) { return @() }
            return @($out | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
        }
    }

    It 'does not ignore canonical source path <Path>' -ForEach $script:MustTrack {
        Get-IgnoredPath -Path $Path | Should -BeNullOrEmpty
    }

    It 'ignores generated or secret path <Path>' -ForEach $script:MustIgnore {
        Get-IgnoredPath -Path $Path | Should -Be $Path
    }

    It 'does not ignore any existing file under src, tests or .github' {
        $candidates = foreach ($dir in @('src', 'tests', '.github')) {
            $full = Join-Path $script:RepoRoot $dir
            if (Test-Path -LiteralPath $full) {
                Get-ChildItem -LiteralPath $full -Recurse -File -Force | ForEach-Object {
                    $_.FullName.Substring($script:RepoRoot.Length).TrimStart('\', '/').Replace('\', '/')
                }
            }
        }
        Get-IgnoredPath -Path @($candidates) | Should -BeNullOrEmpty
    }
}
