# Repo hygiene: AI Stocktake v0.1 is offline-only. Statically scans src/ for
# commands and .NET types that perform network I/O. Comments are ignored
# (the PowerShell tokenizer is used), strings and code are not.

BeforeDiscovery {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $srcRoot = Join-Path $repoRoot 'src'
    $script:SourceFiles = @()
    if (Test-Path -LiteralPath $srcRoot) {
        $script:SourceFiles = @(
            Get-ChildItem -LiteralPath $srcRoot -Recurse -File -Force |
                Where-Object { @('.ps1', '.psm1', '.psd1') -contains $_.Extension.ToLowerInvariant() } |
                ForEach-Object {
                    @{
                        FullName     = $_.FullName
                        RelativePath = $_.FullName.Substring($repoRoot.Length).TrimStart('\', '/')
                    }
                }
        )
    }
}

Describe 'No network calls in src' -Tag 'Unit', 'Repo', 'Security' {
    BeforeAll {
        # Commands (and aliases) that reach the network.
        $script:NetworkCommands = @(
            'Invoke-WebRequest', 'Invoke-RestMethod', 'iwr', 'irm', 'curl', 'wget',
            'Start-BitsTransfer', 'Send-MailMessage', 'New-WebServiceProxy',
            'Test-NetConnection', 'Test-Connection', 'Resolve-DnsName',
            'Invoke-WSManAction', 'Enter-PSSession', 'New-PSSession',
            'Import-PSSession', 'Connect-WSMan',
            'Update-Help', 'Save-Help', 'Install-Module', 'Find-Module',
            'Save-Module', 'Update-Module', 'Install-Package', 'Register-PSRepository',
            'curl.exe', 'wget.exe', 'bitsadmin', 'bitsadmin.exe', 'certutil', 'certutil.exe'
        )

        # .NET types and APIs that perform network I/O (matched anywhere in
        # non-comment tokens, including strings passed to New-Object).
        $script:NetworkPatterns = @(
            'Net\.WebClient',
            'Net\.Http\.',
            'HttpClient',
            'HttpWebRequest',
            'Net\.WebRequest',
            '\[WebRequest\]',
            'FtpWebRequest',
            'Net\.Sockets',
            'TcpClient',
            'UdpClient',
            'TcpListener',
            'Net\.Dns\b',
            '\[Dns\]',
            'Net\.Mail',
            'SmtpClient',
            'WebSocket',
            'ServicePointManager',
            'DownloadString',
            'DownloadFile',
            'UploadString',
            'UploadFile',
            'BitsTransfer',
            'XMLHTTP',
            'WinHttp'
        )

        # Returns a list of human-readable violations for a script text.
        function Find-NetworkUse {
            param([string] $Text)
            $tokens = $null
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref] $tokens, [ref] $errors)
            $hits = New-Object System.Collections.Generic.List[string]
            $patternRegex = New-Object System.Text.RegularExpressions.Regex -ArgumentList (
                ($script:NetworkPatterns -join '|'),
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
            )
            foreach ($token in $tokens) {
                if ($token.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment) { continue }
                $isCommandName = ($token.TokenFlags -band [System.Management.Automation.Language.TokenFlags]::CommandName) -ne 0
                if ($isCommandName -and ($script:NetworkCommands -contains $token.Text)) {
                    $hits.Add(('line {0}: command {1}' -f $token.Extent.StartLineNumber, $token.Text))
                    continue
                }
                $m = $patternRegex.Match($token.Text)
                if ($m.Success) {
                    $hits.Add(('line {0}: {1}' -f $token.Extent.StartLineNumber, $m.Value))
                }
            }
            return , $hits.ToArray()
        }
    }

    It 'detects network use in generated samples (self-test)' {
        (Find-NetworkUse -Text 'Invoke-WebRequest -Uri $u').Count | Should -Be 1
        (Find-NetworkUse -Text 'irm $u').Count | Should -Be 1
        (Find-NetworkUse -Text '$c = New-Object System.Net.WebClient').Count | Should -Be 1
        (Find-NetworkUse -Text '$h = [System.Net.Http.HttpClient]::new()').Count | Should -BeGreaterThan 0
        (Find-NetworkUse -Text 'Start-BitsTransfer -Source $s').Count | Should -BeGreaterThan 0
        (Find-NetworkUse -Text '# Invoke-WebRequest is not used here').Count | Should -Be 0
        (Find-NetworkUse -Text 'Get-NetTCPConnection -State Listen').Count | Should -Be 0
    }

    It '<RelativePath> makes no network calls' -ForEach $script:SourceFiles {
        $text = [System.IO.File]::ReadAllText($FullName)
        Find-NetworkUse -Text $text | Should -BeNullOrEmpty
    }
}
