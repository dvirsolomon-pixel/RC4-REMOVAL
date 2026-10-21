# PSScriptAnalyzer settings for AI Stocktake.
# Used locally and by the CI "lint" job:
#   Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
@{
    # Errors and warnings fail CI. Information-level findings are advisory.
    Severity     = @('Error', 'Warning')

    IncludeDefaultRules = $true

    ExcludeRules = @(
        # The scanner is read-only by design: New-/Set-/Remove- helpers only
        # build or reshape in-memory objects (findings, inventory items, scan
        # context). They never change machine state, so -WhatIf/-Confirm
        # support would be misleading noise.
        'PSUseShouldProcessForStateChangingFunctions'
    )

    Rules = @{
        # The module must run unchanged on Windows PowerShell 5.1 and
        # PowerShell 7.x. This flags syntax not available in every target
        # (for example [type]::new() on old versions, classes, using).
        # NOTE: in PSScriptAnalyzer 1.23 it does NOT flag PowerShell 7-only
        # operators (??, ??=, ?., ?[], ternary, && / ||). Those are caught by
        # tests/repo/Compatibility.Tests.ps1 and by the Windows PowerShell 5.1
        # CI job, which fails to parse them.
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.0')
        }

        # Flag cmdlets that do not exist in Windows PowerShell 5.1 or in
        # PowerShell 7 (Core) on Windows.
        PSUseCompatibleCmdlets = @{
            compatibility = @(
                'desktop-5.1.14393.206-windows',
                'core-6.1.0-windows'
            )
        }

        # .ps1/.psm1/.psd1 files must be UTF-8 with BOM so Windows
        # PowerShell 5.1 does not misread non-ASCII characters.
        PSUseBOMForUnicodeEncodedFile = @{
            Enable = $true
        }
    }
}
