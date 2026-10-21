# Repo hygiene: everything under ai-stocktake/ must be English only.
# Fails if any file contains Hebrew characters (U+0590-U+05FF, U+FB1D-U+FB4F).
# The character class is built from code points so this file stays ASCII.

Describe 'No Hebrew characters under the repo' -Tag 'Unit', 'Repo' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

        $hebrewClass = '[{0}-{1}{2}-{3}]' -f [char]0x0590, [char]0x05FF, [char]0xFB1D, [char]0xFB4F
        $script:HebrewRegex = New-Object System.Text.RegularExpressions.Regex -ArgumentList $hebrewClass

        $script:BinaryExtensions = @(
            '.png', '.jpg', '.jpeg', '.gif', '.ico', '.bmp', '.webp',
            '.zip', '.gz', '.7z', '.nupkg', '.dll', '.exe', '.pdb',
            '.woff', '.woff2', '.ttf', '.otf', '.eot', '.pdf'
        )

        function Get-HebrewHit {
            param([string] $Text)
            $m = $script:HebrewRegex.Match($Text)
            if ($m.Success) { return $m.Index }
            return -1
        }
    }

    It 'detects Hebrew in a generated sample (self-test)' {
        $sample = 'English text ' + [char]0x05E9 + [char]0x05DC + [char]0x05D5 + [char]0x05DD
        Get-HebrewHit -Text $sample | Should -BeGreaterThan -1
        Get-HebrewHit -Text 'Plain English only.' | Should -Be -1
    }

    It 'contains no file with Hebrew characters' {
        $utf8 = New-Object System.Text.UTF8Encoding -ArgumentList $false
        $offenders = New-Object System.Collections.Generic.List[string]

        $files = Get-ChildItem -LiteralPath $script:RepoRoot -Recurse -File -Force |
            Where-Object {
                $_.FullName -notmatch '[\\/]\.git[\\/]' -and
                $script:BinaryExtensions -notcontains $_.Extension.ToLowerInvariant()
            }

        foreach ($file in $files) {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $text = $utf8.GetString($bytes)
            if ((Get-HebrewHit -Text $text) -ge 0) {
                $offenders.Add($file.FullName.Substring($script:RepoRoot.Length).TrimStart('\', '/'))
            }
        }

        $offenders | Should -BeNullOrEmpty -Because 'all content under ai-stocktake/ must be English only'
    }
}
