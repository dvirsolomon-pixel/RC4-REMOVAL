# Repo hygiene: every .ps1/.psm1/.psd1 file must be UTF-8 with BOM, so that
# Windows PowerShell 5.1 reads non-ASCII characters correctly.

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

Describe 'PowerShell source files are UTF-8 with BOM' -Tag 'Unit', 'Repo' {
    It '<RelativePath> starts with a UTF-8 BOM' -ForEach $script:PowerShellFiles {
        $stream = [System.IO.File]::OpenRead($FullName)
        try {
            $buffer = New-Object byte[] 3
            $read = $stream.Read($buffer, 0, 3)
        }
        finally {
            $stream.Dispose()
        }

        $read | Should -Be 3 -Because "$RelativePath must not be empty"
        ('{0:X2}{1:X2}{2:X2}' -f $buffer[0], $buffer[1], $buffer[2]) | Should -Be 'EFBBBF'
    }

    It '<RelativePath> is valid UTF-8' -ForEach $script:PowerShellFiles {
        $strict = New-Object System.Text.UTF8Encoding -ArgumentList $true, $true
        $bytes = [System.IO.File]::ReadAllBytes($FullName)
        { $null = $strict.GetString($bytes) } | Should -Not -Throw
    }
}
