#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Audit and remediate Kerberos RC4 encryption on AD computer and user accounts.

.DESCRIPTION
    This script provides a menu-driven interface to:
      1. List AD computer accounts with RC4 enabled or not configured
      2. List AD user accounts with RC4 enabled or not configured
      3. Remove RC4 and enforce AES128+AES256 on a single computer account
      4. Remove RC4 and enforce AES128+AES256 on a single user account
      5. Remove RC4 and enforce AES128+AES256 on ALL computer accounts
      6. Remove RC4 and enforce AES128+AES256 on ALL user accounts
      7. Restore RC4 on a single computer account (rollback)
      8. Restore RC4 on a single user account (rollback)
      9. Configure logging (set directory, file name, test write permission)
     10. Export Computer accounts report to CSV
     11. Export User accounts report to CSV

.NOTES
    Requires: ActiveDirectory module (RSAT or Domain Controller)
    Permissions: Domain Admin or delegated rights to modify msDS-SupportedEncryptionTypes
    Run as: Administrator

    msDS-SupportedEncryptionTypes bitmask (32-bit DWORD, per [MS-KILE] s2.2.7):

      Encryption type bits:
        0x0001 (1)   = DES-CBC-CRC
        0x0002 (2)   = DES-CBC-MD5
        0x0004 (4)   = RC4-HMAC
        0x0008 (8)   = AES128-CTS-HMAC-SHA1-96
        0x0010 (16)  = AES256-CTS-HMAC-SHA1-96
        0x0020 (32)  = AES256-CTS-HMAC-SHA1-96-SK  ← enforces AES session keys
                                                      even when legacy ticket
                                                      ciphers are also present

      Protocol feature flag bits (not encryption types — AD attribute only):
        0x1000 (4096)  = Resource-SID-compression-disabled
        0x2000 (8192)  = Claims-supported
        0x4000 (16384) = Compound-identity-supported
        0x8000 (32768) = FAST-supported

    "Not configured" (value = 0 or $null) means the KDC uses the domain
    default (DefaultDomainSupportedEncTypes). Pre-Nov-2022 patch this
    defaulted to RC4. This script treats 0/$null as RC4-risk.

    Common composite values:
        4   (0x04)  = RC4 only
        24  (0x18)  = AES128 + AES256
        28  (0x1C)  = RC4 + AES128 + AES256  (transitional)
        56  (0x38)  = AES128 + AES256 + AES256-SK  ← recommended post-CVE-2022-37966

    Target value after remediation:
        AES128 (0x08) + AES256 (0x10) = 24  (0x18)

        Note: AES256-SK (0x20) is intentionally not set. Persisting the 0x20
        bit requires DCs patched with the November 2022 update (KB5019966 /
        KB5020009 / KB5019081) or later. Unpatched DCs silently drop the bit
        at write time. AES128+AES256 alone removes the RC4 risk, which is
        this script's primary purpose.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Constants — msDS-SupportedEncryptionTypes bitmask ([MS-KILE] s2.2.7)
# ---------------------------------------------------------------------------
# Encryption type bits
$DES_CRC_BIT     = 0x0001   # 1   DES-CBC-CRC
$DES_MD5_BIT     = 0x0002   # 2   DES-CBC-MD5
$RC4_BIT         = 0x0004   # 4   RC4-HMAC
$AES128_BIT      = 0x0008   # 8   AES128-CTS-HMAC-SHA1-96
$AES256_BIT      = 0x0010   # 16  AES256-CTS-HMAC-SHA1-96
$AES256_SK_BIT   = 0x0020   # 32  AES256-CTS-HMAC-SHA1-96-SK (enforces AES session keys)

# Protocol feature flag bits (stored in same attribute, not encryption types)
$FLAG_NO_SID_COMPRESS = 0x1000   # Resource-SID-compression-disabled
$FLAG_CLAIMS          = 0x2000   # Claims-supported
$FLAG_COMPOUND        = 0x4000   # Compound-identity-supported
$FLAG_FAST            = 0x8000   # FAST-supported

# Target: AES128 + AES256 = 24 (0x18)
# Note: AES256-SK (0x20) was considered but requires DCs patched with the
# November 2022 update (CVE-2022-37966) or later. Without that patch, the DC
# silently drops the 0x20 bit at write time. AES128+AES256 alone still removes
# the RC4 risk, which is the primary security goal.
$TARGET_ENC_TYPE = $AES128_BIT -bor $AES256_BIT   # 24 (0x18)

# ---------------------------------------------------------------------------
# Logging state  (script-scope, initialised to disabled)
# ---------------------------------------------------------------------------
$script:LogEnabled  = $false
$script:LogFilePath = $null   # full resolved path once configured

# ---------------------------------------------------------------------------
# Logging engine
# ---------------------------------------------------------------------------
function Write-Log {
    <#
    Appends a structured line to the log file when logging is enabled.
    Called by every Write-* wrapper so all console output is also captured.

    Format:
        2025-06-18 14:32:01  [INFO ]  Message text
    #>
    param(
        [Parameter(Mandatory)][string]$Level,   # INFO | OK | WARN | ERROR | AUDIT
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $script:LogEnabled -or -not $script:LogFilePath) { return }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line      = "$timestamp  [$($Level.PadRight(5))]  $Message"

    try {
        Add-Content -LiteralPath $script:LogFilePath -Value $line -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        # Disable logging and warn — don't let a log failure break operations
        $script:LogEnabled = $false
        Write-Host "[WARN] Logging disabled — could not write to '$($script:LogFilePath)': $_" `
            -ForegroundColor Red
    }
}

# ---------------------------------------------------------------------------
# Logging configuration  (option 9)
# ---------------------------------------------------------------------------
function Set-LogConfig {
    $line = '=' * 70
    Write-Host "`n$line" -ForegroundColor Cyan
    Write-Host '  Logging Configuration' -ForegroundColor Cyan
    Write-Host "$line`n" -ForegroundColor Cyan

    # Show current state
    if ($script:LogEnabled) {
        Write-Host "  Logging is currently : ENABLED" -ForegroundColor Green
        Write-Host "  Log file             : $($script:LogFilePath)`n" -ForegroundColor Green
    }
    else {
        Write-Host "  Logging is currently : DISABLED`n" -ForegroundColor Yellow
    }

    # Ask whether to enable or disable
    Write-Host '  Options:' -ForegroundColor Cyan
    Write-Host '   E  — Enable / reconfigure logging'  -ForegroundColor White
    Write-Host '   D  — Disable logging'               -ForegroundColor White
    Write-Host '   B  — Back to main menu'             -ForegroundColor Gray
    Write-Host ''

    $sub = (Read-Host '  Choose [E/D/B]').Trim().ToUpper()

    switch ($sub) {
        'D' {
            $script:LogEnabled  = $false
            $script:LogFilePath = $null
            Write-Host "`n  Logging disabled.`n" -ForegroundColor Yellow
            return
        }
        'B' { return }
        'E' { }   # fall through to configuration below
        default {
            Write-Host "`n  Invalid choice — returning to menu.`n" -ForegroundColor Red
            return
        }
    }

    # ---- Directory ----
    Write-Host ''
    Write-Host '  Enter the directory where the log file should be saved.' -ForegroundColor Cyan
    Write-Host '  Examples:  C:\Logs\AD     \\server\share\logs     D:\Audit' -ForegroundColor Gray
    Write-Host ''

    $dirInput = (Read-Host '  Log directory').Trim()
    if ([string]::IsNullOrWhiteSpace($dirInput)) {
        Write-Host "`n  [ERR] No directory entered — logging not configured.`n" -ForegroundColor Red
        return
    }

    # Resolve to absolute path
    try {
        $resolvedDir = [System.IO.Path]::GetFullPath($dirInput)
    }
    catch {
        Write-Host "`n  [ERR] Invalid path '$dirInput': $_`n" -ForegroundColor Red
        return
    }

    # Create directory if it doesn't exist
    if (-not (Test-Path -LiteralPath $resolvedDir -PathType Container)) {
        Write-Host "  Directory does not exist. Attempting to create it..." -ForegroundColor Yellow
        try {
            $null = New-Item -ItemType Directory -Path $resolvedDir -Force -ErrorAction Stop
            Write-Host "  Directory created: $resolvedDir" -ForegroundColor Green
        }
        catch {
            Write-Host "`n  [ERR] Could not create directory '$resolvedDir': $_`n" -ForegroundColor Red
            return
        }
    }

    # ---- File name ----
    Write-Host ''
    Write-Host '  Enter the log file name (with or without .log extension).' -ForegroundColor Cyan
    Write-Host '  Leave blank to use the default:  KerberosRC4_<date>.log' -ForegroundColor Gray
    Write-Host ''

    $fileInput = (Read-Host '  Log file name').Trim()

    if ([string]::IsNullOrWhiteSpace($fileInput)) {
        $fileInput = "KerberosRC4_$(Get-Date -Format 'yyyyMMdd').log"
        Write-Host "  Using default file name: $fileInput" -ForegroundColor Gray
    }
    else {
        # Ensure .log extension
        if (-not $fileInput.EndsWith('.log', [System.StringComparison]::OrdinalIgnoreCase)) {
            $fileInput = "$fileInput.log"
        }
    }

    # Reject file names with illegal characters
    $illegalChars = [System.IO.Path]::GetInvalidFileNameChars()
    if ($fileInput.IndexOfAny($illegalChars) -ge 0) {
        Write-Host "`n  [ERR] File name contains illegal characters.`n" -ForegroundColor Red
        return
    }

    $fullPath = [System.IO.Path]::Combine($resolvedDir, $fileInput)

    # ---- Write-permission test ----
    Write-Host ''
    Write-Host "  Testing write access to: $fullPath" -ForegroundColor Cyan

    try {
        # Try to open the file for append — creates it if new, appends if existing
        $testStream = [System.IO.File]::Open(
            $fullPath,
            [System.IO.FileMode]::Append,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::Read
        )
        $testStream.Close()
        $testStream.Dispose()
        Write-Host "  Write access confirmed.`n" -ForegroundColor Green
    }
    catch {
        Write-Host ''
        Write-Host "  [ERR] Cannot write to '$fullPath'" -ForegroundColor Red
        Write-Host "        Reason : $_" -ForegroundColor Red
        Write-Host ''
        Write-Host '  Possible causes:' -ForegroundColor Yellow
        Write-Host '    - You do not have write permission to this directory' -ForegroundColor Yellow
        Write-Host '    - The path is on a read-only network share' -ForegroundColor Yellow
        Write-Host '    - The file is locked by another process' -ForegroundColor Yellow
        Write-Host ''
        Write-Host '  Logging has NOT been enabled. Please choose a different path.' -ForegroundColor Red
        Write-Host ''
        return
    }

    # ---- Commit configuration ----
    $script:LogFilePath = $fullPath
    $script:LogEnabled  = $true

    # Write session header to the log
    $separator = '-' * 70
    $domainName = try { (Get-ADDomain -ErrorAction Stop).DNSRoot } catch { '(unavailable)' }
    $header    = @(
        $separator
        "  AD Kerberos RC4 Audit & Remediation Tool — Log Session Start"
        "  Started by : $env:USERDOMAIN\$env:USERNAME  on  $env:COMPUTERNAME"
        "  Time       : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "  Domain     : $domainName"
        $separator
    )
    try {
        Add-Content -LiteralPath $script:LogFilePath -Value $header -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Host "  [WARN] Could not write session header: $_" -ForegroundColor Red
    }

    Write-Host "  Logging enabled." -ForegroundColor Green
    Write-Host "  Log file : $script:LogFilePath`n" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Get-EncryptionLabel {
    param([object]$EncValue)
    if ($null -eq $EncValue -or $EncValue -eq 0) {
        return 'Not Configured (KDC uses domain default — RC4 risk on unpatched DCs)'
    }
    $val   = [int]$EncValue
    $enc   = [System.Collections.Generic.List[string]]::new()
    $flags = [System.Collections.Generic.List[string]]::new()

    # Encryption type bits
    if ($val -band 0x0001) { $enc.Add('DES-CBC-CRC') }
    if ($val -band 0x0002) { $enc.Add('DES-CBC-MD5') }
    if ($val -band 0x0004) { $enc.Add('RC4-HMAC') }
    if ($val -band 0x0008) { $enc.Add('AES128') }
    if ($val -band 0x0010) { $enc.Add('AES256') }
    if ($val -band 0x0020) { $enc.Add('AES256-SK') }

    # Protocol feature flag bits
    if ($val -band 0x1000) { $flags.Add('NoSIDCompress') }
    if ($val -band 0x2000) { $flags.Add('Claims') }
    if ($val -band 0x4000) { $flags.Add('CompoundId') }
    if ($val -band 0x8000) { $flags.Add('FAST') }

    $label = if ($enc.Count -gt 0) { $enc -join ' | ' } else { '(none)' }
    if ($flags.Count -gt 0) { $label += "  [flags: $($flags -join ', ')]" }
    return $label
}

function Test-HasRC4Risk {
    <# Returns $true if the account has RC4 bit set OR is not configured (0/$null) #>
    param([object]$EncValue)
    if ($null -eq $EncValue -or $EncValue -eq 0) { return $true }
    return (([int]$EncValue -band $RC4_BIT) -ne 0)
}

# ---------------------------------------------------------------------------
# Test-ComputerAESCompatible
# Returns a PSCustomObject with .Compatible (bool) and .Reason (string).
#
# Authoritative rule: AES Kerberos requires operatingSystemVersion >= 6.0
# (Windows Vista / Server 2008 introduced AES support). Anything 5.x
# (XP / Server 2003) does NOT support AES — the AD attribute is ignored on
# those OSes and only RC4 is honored. Applying AES to such accounts will
# break Kerberos authentication for that machine.
#
# Sources:
#   - Microsoft: "Detect and Remediate RC4 Usage in Kerberos"
#     (Server 2003 was the last Windows version without AES-SHA1)
#   - MS-KILE / Argon Systems: Server 2000, 2003 and XP do not support AES
#
# Edge cases:
#   - $null OS / version (computer object never reported) → assume compatible
#     since we can't tell; let the user decide. We flag it as 'Unknown'.
#   - Non-Windows / appliance with version <6.0 (e.g. NAS reporting 5.x) →
#     incompatible per the same rule.
# ---------------------------------------------------------------------------
function Test-ComputerAESCompatible {
    param(
        [string]$OperatingSystem,
        [string]$OperatingSystemVersion
    )

    # No version reported at all — treat as incompatible (safer default).
    # Without a known AES-capable OS we can't guarantee the machine will
    # honor msDS-SupportedEncryptionTypes, so refuse to remediate.
    if ([string]::IsNullOrWhiteSpace($OperatingSystemVersion)) {
        return [PSCustomObject]@{
            Compatible = $false
            Reason     = 'OS version not reported — treated as incompatible (safer default)'
            OS         = if ($OperatingSystem) { $OperatingSystem } else { '(unknown)' }
            Version    = '(none)'
        }
    }

    # Parse "major.minor" — handle "5.2 (3790)" style strings too
    $verMatch = [regex]::Match($OperatingSystemVersion, '^\s*(\d+)\.(\d+)')
    if (-not $verMatch.Success) {
        return [PSCustomObject]@{
            Compatible = $false
            Reason     = "Could not parse OS version '$OperatingSystemVersion' — treated as incompatible (safer default)"
            OS         = if ($OperatingSystem) { $OperatingSystem } else { '(unknown)' }
            Version    = $OperatingSystemVersion
        }
    }

    $major = [int]$verMatch.Groups[1].Value
    $minor = [int]$verMatch.Groups[2].Value

    # AES requires major >= 6 (Vista / 2008 = 6.0, Win7 / 2008R2 = 6.1, Win10 = 10.0)
    if ($major -ge 6) {
        return [PSCustomObject]@{
            Compatible = $true
            Reason     = "OS version $major.$minor supports AES"
            OS         = if ($OperatingSystem) { $OperatingSystem } else { '(unknown)' }
            Version    = "$major.$minor"
        }
    }
    else {
        return [PSCustomObject]@{
            Compatible = $false
            Reason     = "OS version $major.$minor predates AES support (Vista/2008 = 6.0). Applying AES will break Kerberos auth for this machine."
            OS         = if ($OperatingSystem) { $OperatingSystem } else { '(unknown)' }
            Version    = "$major.$minor"
        }
    }
}

function Write-Header {
    param([string]$Title)
    $line = '=' * 70
    Write-Host "`n$line" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$line`n" -ForegroundColor Cyan
    Write-Log -Level 'AUDIT' -Message "=== $Title ==="
}

function Write-Success { param([string]$Msg) Write-Host "[OK]  $Msg" -ForegroundColor Green;  Write-Log -Level 'OK'    -Message $Msg }
function Write-Info    { param([string]$Msg) Write-Host "[..]  $Msg" -ForegroundColor Yellow; Write-Log -Level 'INFO'  -Message $Msg }
function Write-Fail    { param([string]$Msg) Write-Host "[ERR] $Msg" -ForegroundColor Red;    Write-Log -Level 'ERROR' -Message $Msg }

# ---------------------------------------------------------------------------
# 1. List Computer Accounts with RC4 enabled or not configured
# ---------------------------------------------------------------------------
function Get-RC4Computers {
    Write-Header 'Computer Accounts — RC4 Enabled or Not Configured'

    Write-Info 'Querying all enabled computer accounts...'
    $computers = @(Get-ADComputer -Filter { Enabled -eq $true } `
        -Properties msDS-SupportedEncryptionTypes, OperatingSystem, OperatingSystemVersion, DistinguishedName |
        Where-Object { Test-HasRC4Risk $_.'msDS-SupportedEncryptionTypes' } |
        Sort-Object Name)

    if ($computers.Count -eq 0) {
        Write-Success 'No computer accounts found with RC4 risk.'
        return
    }

    Write-Host "Found $($computers.Count) computer(s) with RC4 risk:`n" -ForegroundColor Yellow

    $computers | ForEach-Object {
        $compat = Test-ComputerAESCompatible -OperatingSystem $_.OperatingSystem `
                                              -OperatingSystemVersion $_.OperatingSystemVersion
        $compatLabel = if ($compat.Compatible) { 'YES' } else { 'NO' }
        [PSCustomObject]@{
            Name            = $_.Name
            OS              = $_.OperatingSystem
            OSVersion       = $_.OperatingSystemVersion
            'AES-Capable'   = $compatLabel
            EncryptionValue = $_.'msDS-SupportedEncryptionTypes'
            EncryptionTypes = Get-EncryptionLabel $_.'msDS-SupportedEncryptionTypes'
        }
    } | Format-Table -AutoSize -Wrap

    # Warn if any incompatible accounts were found
    $incompat = @($computers | Where-Object {
        -not (Test-ComputerAESCompatible -OperatingSystem $_.OperatingSystem `
                                          -OperatingSystemVersion $_.OperatingSystemVersion).Compatible
    })
    if ($incompat.Count -gt 0) {
        Write-Host ''
        Write-Host "  WARNING: $($incompat.Count) computer(s) above are NOT AES-compatible." -ForegroundColor Red
        Write-Host '           Reasons: legacy OS (pre-Vista/2008) or OS version not reported.' -ForegroundColor Red
        Write-Host '           Bulk remediation (option 5) will skip them automatically.'     -ForegroundColor Red
    }

    Write-Host "`nTotal at risk: $($computers.Count)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 2. List User Accounts with RC4 enabled or not configured
# ---------------------------------------------------------------------------
function Get-RC4Users {
    Write-Header 'User Accounts — RC4 Enabled or Not Configured'

    Write-Info 'Querying all enabled user accounts...'
    $users = @(Get-ADUser -Filter { Enabled -eq $true } `
        -Properties msDS-SupportedEncryptionTypes, Department, DistinguishedName |
        Where-Object { Test-HasRC4Risk $_.'msDS-SupportedEncryptionTypes' } |
        Sort-Object SamAccountName)

    if ($users.Count -eq 0) {
        Write-Success 'No user accounts found with RC4 risk.'
        return
    }

    Write-Host "Found $($users.Count) user(s) with RC4 risk:`n" -ForegroundColor Yellow

    $users | ForEach-Object {
        [PSCustomObject]@{
            SamAccountName  = $_.SamAccountName
            DisplayName     = $_.DisplayName
            Department      = $_.Department
            EncryptionValue = $_.'msDS-SupportedEncryptionTypes'
            EncryptionTypes = Get-EncryptionLabel $_.'msDS-SupportedEncryptionTypes'
            DN              = $_.DistinguishedName
        }
    } | Format-Table -AutoSize -Wrap

    Write-Host "Total at risk: $($users.Count)" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Read back msDS-SupportedEncryptionTypes from AD after a write.
# MUST use Get-ADUser/Get-ADComputer -Properties — Get-ADObject reads through
# a different schema path and can return stale null even after a successful write.
# ---------------------------------------------------------------------------
function Get-ADEncValidation {
    param(
        [Parameter(Mandatory)][string]$DN,
        [Parameter(Mandatory)][string]$ObjectType,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$BeforeValue,
        [Parameter(Mandatory)][int]$ExpectedValue
    )

    try {
        $actualRaw = $null

        if ($ObjectType -eq 'User') {
            $refreshed = Get-ADUser -Identity $DN `
                -Properties msDS-SupportedEncryptionTypes `
                -ErrorAction Stop
            $actualRaw = $refreshed.'msDS-SupportedEncryptionTypes'
        }
        else {
            $refreshed = Get-ADComputer -Identity $DN `
                -Properties msDS-SupportedEncryptionTypes `
                -ErrorAction Stop
            $actualRaw = $refreshed.'msDS-SupportedEncryptionTypes'
        }

        $actualInt = if ($null -eq $actualRaw) { 0 } else { [int]$actualRaw }
        $verified  = ($actualInt -eq $ExpectedValue)

        return [PSCustomObject]@{
            ObjectType    = $ObjectType
            Name          = $Name
            BeforeRaw     = $BeforeValue
            BeforeLabel   = Get-EncryptionLabel $BeforeValue
            AfterRaw      = $actualInt
            AfterLabel    = Get-EncryptionLabel $actualInt
            ExpectedRaw   = $ExpectedValue
            ExpectedLabel = Get-EncryptionLabel $ExpectedValue
            Verified      = $verified
            Error         = $null
        }
    }
    catch {
        return [PSCustomObject]@{
            ObjectType    = $ObjectType
            Name          = $Name
            BeforeRaw     = $BeforeValue
            BeforeLabel   = Get-EncryptionLabel $BeforeValue
            AfterRaw      = $null
            AfterLabel    = '(read-back failed)'
            ExpectedRaw   = $ExpectedValue
            ExpectedLabel = Get-EncryptionLabel $ExpectedValue
            Verified      = $false
            Error         = $_.ToString()
        }
    }
}

# ---------------------------------------------------------------------------
# Show a single-account before/after validation block
# ---------------------------------------------------------------------------
function Show-ValidationResult {
    param([Parameter(Mandatory)][PSCustomObject]$Result)

    Write-Host ''
    Write-Host '  ┌─ Validation ──────────────────────────────────────────────────' -ForegroundColor DarkCyan
    Write-Host "  │  Account  : $($Result.ObjectType) '$($Result.Name)'" -ForegroundColor DarkCyan
    Write-Host "  │  Before   : $($Result.BeforeLabel)  (raw: $($Result.BeforeRaw))" -ForegroundColor Gray
    Write-Host "  │  Expected : $($Result.ExpectedLabel)  (raw: $($Result.ExpectedRaw))" -ForegroundColor Gray

    if ($Result.Verified) {
        Write-Host "  │  After    : $($Result.AfterLabel)  (raw: $($Result.AfterRaw))" -ForegroundColor Green
        Write-Host '  │  Status   : [VERIFIED] AD value matches expected value' -ForegroundColor Green
        Write-Log -Level 'OK'    -Message "VERIFIED  | $($Result.ObjectType) '$($Result.Name)' | Before: $($Result.BeforeRaw) | After: $($Result.AfterRaw) | Expected: $($Result.ExpectedRaw)"
    }
    elseif ($null -eq $Result.AfterRaw) {
        Write-Host "  │  After    : $($Result.AfterLabel)" -ForegroundColor Red
        Write-Host "  │  Status   : [WARN] Could not read back value — $($Result.Error)" -ForegroundColor Red
        Write-Log -Level 'WARN'  -Message "READ-FAIL | $($Result.ObjectType) '$($Result.Name)' | Before: $($Result.BeforeRaw) | ReadBack failed: $($Result.Error)"
    }
    else {
        Write-Host "  │  After    : $($Result.AfterLabel)  (raw: $($Result.AfterRaw))" -ForegroundColor Red
        Write-Host '  │  Status   : [MISMATCH] AD value does not match expected — verify manually' -ForegroundColor Red
        Write-Log -Level 'ERROR' -Message "MISMATCH  | $($Result.ObjectType) '$($Result.Name)' | Before: $($Result.BeforeRaw) | After: $($Result.AfterRaw) | Expected: $($Result.ExpectedRaw)"
    }
    Write-Host '  └───────────────────────────────────────────────────────────────' -ForegroundColor DarkCyan
    Write-Host ''
}

# ---------------------------------------------------------------------------
# Write AES128+AES256 to msDS-SupportedEncryptionTypes via the dedicated
# -KerberosEncryptionType parameter on Set-ADUser / Set-ADComputer.
#
# Uses -Identity <DN>. Note: -Instance and -KerberosEncryptionType belong to
# different parameter sets and cannot be combined.
# ---------------------------------------------------------------------------
function Set-ADEncryptionType {
    param(
        [Parameter(Mandatory)][Microsoft.ActiveDirectory.Management.ADObject]$ADObject,
        [Parameter(Mandatory)][string]$ObjectType   # 'Computer' or 'User'
    )

    if ($ObjectType -eq 'User') {
        Set-ADUser -Identity $ADObject.DistinguishedName `
            -KerberosEncryptionType 'AES128,AES256' `
            -ErrorAction Stop
    }
    else {
        Set-ADComputer -Identity $ADObject.DistinguishedName `
            -KerberosEncryptionType 'AES128,AES256' `
            -ErrorAction Stop
    }
}

# ---------------------------------------------------------------------------
# Safe raw integer write — used only by Restore-RC4 which needs to set an
# arbitrary bitmask (including RC4) that -KerberosEncryptionType won't accept.
# Handles null attribute by using -Add, existing attribute by using -Replace.
# ---------------------------------------------------------------------------
function Set-ADEncryptionTypeRaw {
    param(
        [Parameter(Mandatory)][string]$DN,
        [object]$CurrentRaw = $null,
        [Parameter(Mandatory)][int]$NewValue
    )

    if ($null -eq $CurrentRaw -or ($CurrentRaw -is [int] -and $CurrentRaw -eq 0) -or
        ($CurrentRaw -is [string] -and $CurrentRaw -eq '')) {
        Set-ADObject -Identity $DN `
            -Add @{ 'msDS-SupportedEncryptionTypes' = $NewValue } `
            -ErrorAction Stop
    }
    else {
        Set-ADObject -Identity $DN `
            -Replace @{ 'msDS-SupportedEncryptionTypes' = $NewValue } `
            -ErrorAction Stop
    }
}

# ---------------------------------------------------------------------------
# Core remediation — sets AES128+AES256, clears RC4
# Returns a result object for bulk callers
# ---------------------------------------------------------------------------
function Set-AESOnly {
    param(
        [Parameter(Mandatory)][Microsoft.ActiveDirectory.Management.ADObject]$ADObject,
        [Parameter(Mandatory)][string]$ObjectType,   # 'Computer' or 'User'
        [switch]$Silent   # suppress per-item validation output (used by bulk callers)
    )

    $name       = if ($ObjectType -eq 'Computer') { $ADObject.Name } else { $ADObject.SamAccountName }
    $currentRaw = $ADObject.'msDS-SupportedEncryptionTypes'
    $beforeInt  = if ($null -eq $currentRaw) { 0 } else { [int]$currentRaw }

    Write-Info "Processing $ObjectType '$name'  (before: $(Get-EncryptionLabel $beforeInt))"

    try {
        Set-ADEncryptionType -ADObject $ADObject -ObjectType $ObjectType
    }
    catch {
        Write-Fail "Failed to write to $ObjectType '$name': $_"
        return [PSCustomObject]@{
            ObjectType  = $ObjectType; Name       = $name
            BeforeRaw   = $beforeInt;  AfterRaw   = $null
            BeforeLabel = Get-EncryptionLabel $beforeInt; AfterLabel = '(write failed)'
            ExpectedRaw = $TARGET_ENC_TYPE; ExpectedLabel = Get-EncryptionLabel $TARGET_ENC_TYPE
            Verified    = $false; Error = $_.ToString()
        }
    }

    $result = Get-ADEncValidation -DN $ADObject.DistinguishedName -ObjectType $ObjectType `
                  -Name $name -BeforeValue $beforeInt -ExpectedValue $TARGET_ENC_TYPE

    if (-not $Silent) { Show-ValidationResult -Result $result }
    return $result
}

function Show-PostComputerChangeInfo {
    <#
    Shown after one or more computer accounts have been successfully changed.
    Points the user at the Microsoft KB explaining how to ensure target OSes
    are properly updated to handle the disablement of RC4 / enforcement of AES.
    #>
    $url = 'https://support.microsoft.com/en-us/topic/microsoft-security-advisory-update-for-disabling-rc4-479fd6f0-c7b5-0671-975b-c45c3f2c0540'

    Write-Host ''
    Write-Host '  ┌─ Post-change reference ─────────────────────────────────────────────────' -ForegroundColor DarkCyan
    Write-Host '  │  Microsoft Security Advisory — Update for disabling RC4:'                  -ForegroundColor DarkCyan
    Write-Host "  │  $url"                                                                     -ForegroundColor Cyan
    Write-Host '  │'                                                                           -ForegroundColor DarkCyan
    Write-Host '  │  Make sure the affected machines have the relevant Windows update'         -ForegroundColor DarkCyan
    Write-Host '  │  installed so AES Kerberos works correctly after this change.'             -ForegroundColor DarkCyan
    Write-Host '  └─────────────────────────────────────────────────────────────────────────' -ForegroundColor DarkCyan
    Write-Host ''

    Write-Log -Level 'INFO' -Message "Post-change reference: $url"
}

# ---------------------------------------------------------------------------
# 3. Remediate single Computer
# ---------------------------------------------------------------------------
function Set-SingleComputer {
    Write-Header 'Fix Single Computer Account (Remove RC4, Set AES128+AES256)'

    $computerName = Read-Host 'Enter computer name (SAMAccountName or hostname, without $)'

    try {
        $computer = Get-ADComputer -Identity $computerName `
            -Properties msDS-SupportedEncryptionTypes, OperatingSystem, OperatingSystemVersion, DistinguishedName -ErrorAction Stop
    }
    catch {
        Write-Fail "Computer '$computerName' not found in AD: $_"
        return
    }

    if (-not (Test-HasRC4Risk $computer.'msDS-SupportedEncryptionTypes')) {
        Write-Success "Computer '$computerName' already has RC4-safe encryption: $(Get-EncryptionLabel $computer.'msDS-SupportedEncryptionTypes')"
        return
    }

    # ---- OS compatibility check ----
    $compat = Test-ComputerAESCompatible -OperatingSystem $computer.OperatingSystem `
                                          -OperatingSystemVersion $computer.OperatingSystemVersion
    Write-Host ''
    Write-Host "  OS               : $($compat.OS)" -ForegroundColor Cyan
    Write-Host "  OS Version       : $($compat.Version)" -ForegroundColor Cyan

    if ($compat.Compatible) {
        Write-Host "  AES Compatible   : YES — $($compat.Reason)" -ForegroundColor Green
    }
    else {
        Write-Host "  AES Compatible   : NO" -ForegroundColor Red
        Write-Host "  Reason           : $($compat.Reason)" -ForegroundColor Red
        Write-Host ''
        Write-Host '  BLOCKED: This computer is not AES-compatible.' -ForegroundColor Red
        Write-Host '          Applying AES would break Kerberos authentication for this machine.' -ForegroundColor Red
        Write-Host '          Recommended actions:' -ForegroundColor Yellow
        Write-Host '            - Verify the OS reports a version >= 6.0 (Vista / Server 2008)' -ForegroundColor Yellow
        Write-Host '            - Upgrade or decommission legacy OSes' -ForegroundColor Yellow
        Write-Host '            - Or leave this computer account as-is (RC4)' -ForegroundColor Yellow
        Write-Log -Level 'WARN' -Message "BLOCKED incompatible OS | Computer '$($computer.Name)' | OS: $($compat.OS) | Version: $($compat.Version)"
        return
    }
    Write-Host ''

    $confirm = Read-Host "Confirm: remove RC4 and set AES128+AES256 on '$computerName'? [y/N]"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host 'Cancelled.' -ForegroundColor Gray
        return
    }

    $changeResult = Set-AESOnly -ADObject $computer -ObjectType Computer

    if ($changeResult -and $changeResult.Verified) {
        Show-PostComputerChangeInfo
    }
}

# ---------------------------------------------------------------------------
# 4. Remediate single User
# ---------------------------------------------------------------------------
function Set-SingleUser {
    Write-Header 'Fix Single User Account (Remove RC4, Set AES128+AES256)'

    $userName = Read-Host 'Enter username (SamAccountName or UPN)'

    try {
        $user = Get-ADUser -Identity $userName `
            -Properties msDS-SupportedEncryptionTypes, DistinguishedName -ErrorAction Stop
    }
    catch {
        Write-Fail "User '$userName' not found in AD: $_"
        return
    }

    if (-not (Test-HasRC4Risk $user.'msDS-SupportedEncryptionTypes')) {
        Write-Success "User '$userName' already has RC4-safe encryption: $(Get-EncryptionLabel $user.'msDS-SupportedEncryptionTypes')"
        return
    }

    $confirm = Read-Host "Confirm: remove RC4 and set AES128+AES256 on user '$userName'? [y/N]"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host 'Cancelled.' -ForegroundColor Gray
        return
    }

    Set-AESOnly -ADObject $user -ObjectType User
}

# ---------------------------------------------------------------------------
# 5. Remediate ALL Computers
# ---------------------------------------------------------------------------
function Set-AllComputers {
    Write-Header 'Fix ALL Computer Accounts (Remove RC4, Set AES128+AES256)'

    Write-Info 'Querying all enabled computer accounts with RC4 risk...'
    $allCandidates = @(Get-ADComputer -Filter { Enabled -eq $true } `
        -Properties msDS-SupportedEncryptionTypes, OperatingSystem, OperatingSystemVersion, DistinguishedName |
        Where-Object { Test-HasRC4Risk $_.'msDS-SupportedEncryptionTypes' })

    if ($allCandidates.Count -eq 0) {
        Write-Success 'No computer accounts require remediation.'
        return
    }

    # Partition by AES compatibility (strict two-state)
    $compatible   = [System.Collections.Generic.List[object]]::new()
    $incompatible = [System.Collections.Generic.List[object]]::new()

    foreach ($c in $allCandidates) {
        $check = Test-ComputerAESCompatible -OperatingSystem $c.OperatingSystem `
                                             -OperatingSystemVersion $c.OperatingSystemVersion
        if ($check.Compatible) {
            $compatible.Add($c)
        }
        else {
            $incompatible.Add($c)
        }
    }

    # Report skipped incompatible machines up-front
    if ($incompatible.Count -gt 0) {
        Write-Host ''
        Write-Host "  SKIPPED — $($incompatible.Count) computer(s) not AES-compatible:" -ForegroundColor Red
        $incompatible | ForEach-Object {
            $reason = (Test-ComputerAESCompatible -OperatingSystem $_.OperatingSystem `
                                                   -OperatingSystemVersion $_.OperatingSystemVersion).Reason
            [PSCustomObject]@{
                Name      = $_.Name
                OS        = $_.OperatingSystem
                OSVersion = $_.OperatingSystemVersion
                Reason    = $reason
            }
        } | Format-Table -AutoSize -Wrap
        foreach ($skip in $incompatible) {
            Write-Log -Level 'WARN' -Message "SKIPPED incompatible | Computer '$($skip.Name)' | OS: $($skip.OperatingSystem) | Version: $($skip.OperatingSystemVersion)"
        }
    }

    if ($compatible.Count -eq 0) {
        Write-Host ''
        Write-Host '  No AES-compatible computers to remediate.' -ForegroundColor Yellow
        return
    }

    $computers = @($compatible)

    Write-Host "`nThe following $($computers.Count) computer(s) will be updated:`n" -ForegroundColor Yellow
    $computers | Select-Object Name, OperatingSystem,
        @{N='CurrentEncryption'; E={ Get-EncryptionLabel $_.'msDS-SupportedEncryptionTypes' }} |
        Format-Table -AutoSize

    $confirm = Read-Host "Confirm: apply AES128+AES256 to ALL $($computers.Count) computer(s)? [y/N]"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host 'Cancelled.' -ForegroundColor Gray
        return
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($comp in $computers) {
        $r = Set-AESOnly -ADObject $comp -ObjectType Computer -Silent
        $results.Add($r)
    }

    # Per-account validation summary table
    Write-Host "`n--- Validation Results ---`n" -ForegroundColor Cyan
    $results | ForEach-Object {
        $status = if ($_.Verified) { 'VERIFIED' }
                  elseif ($_.AfterLabel -eq '(write failed)') { 'WRITE-FAIL' }
                  elseif ($null -eq $_.AfterRaw) { 'READ-FAIL' }
                  else { 'MISMATCH' }
        [PSCustomObject]@{
            Name       = $_.Name
            Before     = $_.BeforeLabel
            After      = $_.AfterLabel
            'Raw After'= $_.AfterRaw
            Status     = $status
        }
    } | Format-Table -AutoSize

    $success = @($results | Where-Object { $_.Verified }).Count
    $failed  = @($results | Where-Object { -not $_.Verified }).Count
    Write-Host "--- Summary ---" -ForegroundColor Cyan
    Write-Host "  Verified : $success" -ForegroundColor Green
    Write-Host "  Failed   : $failed"  -ForegroundColor $(if ($failed) { 'Red' } else { 'Gray' })
    Write-Host "  Skipped  : $($incompatible.Count) (not AES-compatible)" -ForegroundColor $(if ($incompatible.Count) { 'Yellow' } else { 'Gray' })

    if ($success -gt 0) {
        Show-PostComputerChangeInfo
    }
}

# ---------------------------------------------------------------------------
# 6. Remediate ALL Users
# ---------------------------------------------------------------------------
function Set-AllUsers {
    Write-Header 'Fix ALL User Accounts (Remove RC4, Set AES128+AES256)'

    Write-Info 'Querying all enabled user accounts with RC4 risk...'
    $users = @(Get-ADUser -Filter { Enabled -eq $true } `
        -Properties msDS-SupportedEncryptionTypes, DistinguishedName |
        Where-Object { Test-HasRC4Risk $_.'msDS-SupportedEncryptionTypes' })

    if ($users.Count -eq 0) {
        Write-Success 'No user accounts require remediation.'
        return
    }

    Write-Host "`nThe following $($users.Count) user(s) will be updated:`n" -ForegroundColor Yellow
    $users | Select-Object SamAccountName, DisplayName,
        @{N='CurrentEncryption'; E={ Get-EncryptionLabel $_.'msDS-SupportedEncryptionTypes' }} |
        Format-Table -AutoSize

    $confirm = Read-Host "Confirm: apply AES128+AES256 to ALL $($users.Count) user(s)? [y/N]"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host 'Cancelled.' -ForegroundColor Gray
        return
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($user in $users) {
        $r = Set-AESOnly -ADObject $user -ObjectType User -Silent
        $results.Add($r)
    }

    # Per-account validation summary table
    Write-Host "`n--- Validation Results ---`n" -ForegroundColor Cyan
    $results | ForEach-Object {
        $status = if ($_.Verified) { 'VERIFIED' }
                  elseif ($_.AfterLabel -eq '(write failed)') { 'WRITE-FAIL' }
                  elseif ($null -eq $_.AfterRaw) { 'READ-FAIL' }
                  else { 'MISMATCH' }
        [PSCustomObject]@{
            SamAccountName = $_.Name
            Before         = $_.BeforeLabel
            After          = $_.AfterLabel
            'Raw After'    = $_.AfterRaw
            Status         = $status
        }
    } | Format-Table -AutoSize

    $success = @($results | Where-Object { $_.Verified }).Count
    $failed  = @($results | Where-Object { -not $_.Verified }).Count
    Write-Host "--- Summary ---" -ForegroundColor Cyan
    Write-Host "  Verified : $success" -ForegroundColor Green
    Write-Host "  Failed   : $failed"  -ForegroundColor $(if ($failed) { 'Red' } else { 'Gray' })
}

# ---------------------------------------------------------------------------
# Core restore — re-adds RC4 bit on top of existing AES flags
# Returns a result object for callers
# ---------------------------------------------------------------------------
function Restore-RC4 {
    param(
        [Parameter(Mandatory)][Microsoft.ActiveDirectory.Management.ADObject]$ADObject,
        [Parameter(Mandatory)][string]$ObjectType,   # 'Computer' or 'User'
        [switch]$Silent
    )

    $name        = if ($ObjectType -eq 'Computer') { $ADObject.Name } else { $ADObject.SamAccountName }
    $currentRaw  = $ADObject.'msDS-SupportedEncryptionTypes'
    $beforeInt   = if ($null -eq $currentRaw -or $currentRaw -eq 0) { 0 } else { [int]$currentRaw }
    $expectedInt = $beforeInt -bor $RC4_BIT

    Write-Info "Processing $ObjectType '$name'  (before: $(Get-EncryptionLabel $beforeInt))"

    try {
        Set-ADEncryptionTypeRaw -DN $ADObject.DistinguishedName `
            -CurrentRaw $currentRaw -NewValue $expectedInt
    }
    catch {
        Write-Fail "Failed to write to $ObjectType '$name': $_"
        return [PSCustomObject]@{
            ObjectType  = $ObjectType; Name       = $name
            BeforeRaw   = $beforeInt;  AfterRaw   = $null
            BeforeLabel = Get-EncryptionLabel $beforeInt; AfterLabel = '(write failed)'
            ExpectedRaw = $expectedInt; ExpectedLabel = Get-EncryptionLabel $expectedInt
            Verified    = $false; Error = $_.ToString()
        }
    }

    $result = Get-ADEncValidation -DN $ADObject.DistinguishedName -ObjectType $ObjectType `
                  -Name $name -BeforeValue $beforeInt -ExpectedValue $expectedInt

    if (-not $Silent) { Show-ValidationResult -Result $result }
    return $result
}

# ---------------------------------------------------------------------------
# 7. Restore RC4 on single Computer
# ---------------------------------------------------------------------------
function Restore-RC4Computer {
    Write-Header 'Restore RC4 — Single Computer Account'
    Write-Host '  WARNING: Re-enabling RC4 reduces Kerberos security.' -ForegroundColor Red
    Write-Host '  Only use this for temporary compatibility rollback.' -ForegroundColor Red
    Write-Host ''

    $computerName = Read-Host 'Enter computer name (SAMAccountName or hostname, without $)'

    try {
        $computer = Get-ADComputer -Identity $computerName `
            -Properties msDS-SupportedEncryptionTypes, DistinguishedName -ErrorAction Stop
    }
    catch {
        Write-Fail "Computer '$computerName' not found in AD: $_"
        return
    }

    $currentEnc = $computer.'msDS-SupportedEncryptionTypes'
    $currentInt = if ($null -eq $currentEnc -or $currentEnc -eq 0) { 0 } else { [int]$currentEnc }
    Write-Host "  Current encryption : $(Get-EncryptionLabel $currentInt)  (raw: $currentInt)" -ForegroundColor Cyan

    if ($null -ne $currentEnc -and ([int]$currentEnc -band $RC4_BIT) -ne 0) {
        Write-Success "Computer '$computerName' already has RC4 enabled — no change needed."
        return
    }

    $previewInt = $currentInt -bor $RC4_BIT
    Write-Host "  After restore      : $(Get-EncryptionLabel $previewInt)  (raw: $previewInt)" -ForegroundColor Yellow
    Write-Host ''

    $confirm = Read-Host "Confirm: re-enable RC4 on computer '$computerName'? [y/N]"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host 'Cancelled.' -ForegroundColor Gray
        return
    }

    $null = Restore-RC4 -ADObject $computer -ObjectType Computer
}

# ---------------------------------------------------------------------------
# 8. Restore RC4 on single User
# ---------------------------------------------------------------------------
function Restore-RC4User {
    Write-Header 'Restore RC4 — Single User Account'
    Write-Host '  WARNING: Re-enabling RC4 reduces Kerberos security.' -ForegroundColor Red
    Write-Host '  Only use this for temporary compatibility rollback.' -ForegroundColor Red
    Write-Host ''

    $userName = Read-Host 'Enter username (SamAccountName or UPN)'

    try {
        $user = Get-ADUser -Identity $userName `
            -Properties msDS-SupportedEncryptionTypes, DistinguishedName -ErrorAction Stop
    }
    catch {
        Write-Fail "User '$userName' not found in AD: $_"
        return
    }

    $currentEnc = $user.'msDS-SupportedEncryptionTypes'
    $currentInt = if ($null -eq $currentEnc -or $currentEnc -eq 0) { 0 } else { [int]$currentEnc }
    Write-Host "  Current encryption : $(Get-EncryptionLabel $currentInt)  (raw: $currentInt)" -ForegroundColor Cyan

    if ($null -ne $currentEnc -and ([int]$currentEnc -band $RC4_BIT) -ne 0) {
        Write-Success "User '$userName' already has RC4 enabled — no change needed."
        return
    }

    $previewInt = $currentInt -bor $RC4_BIT
    Write-Host "  After restore      : $(Get-EncryptionLabel $previewInt)  (raw: $previewInt)" -ForegroundColor Yellow
    Write-Host ''

    $confirm = Read-Host "Confirm: re-enable RC4 on user '$userName'? [y/N]"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host 'Cancelled.' -ForegroundColor Gray
        return
    }

    $null = Restore-RC4 -ADObject $user -ObjectType User
}

# ---------------------------------------------------------------------------
# CSV report helpers
# ---------------------------------------------------------------------------

function Get-CsvOutputPath {
    <#
    Interactive prompt: asks the user for output directory + file name,
    creates the directory if missing, ensures .csv extension, validates
    file name, tests write access. Returns the full resolved path or
    $null on any failure / cancel.
    #>
    param([Parameter(Mandatory)][string]$ReportLabel)   # e.g. 'computers' or 'users'

    Write-Host ''
    Write-Host "  Enter the directory where the $ReportLabel report will be saved." -ForegroundColor Cyan
    Write-Host '  Examples:  C:\Reports\AD     \\server\share\reports     D:\Audit' -ForegroundColor Gray
    Write-Host ''

    $dirInput = (Read-Host '  Report directory').Trim()
    if ([string]::IsNullOrWhiteSpace($dirInput)) {
        Write-Host "`n  [ERR] No directory entered — report cancelled.`n" -ForegroundColor Red
        return $null
    }

    # Resolve to absolute path
    try {
        $resolvedDir = [System.IO.Path]::GetFullPath($dirInput)
    }
    catch {
        Write-Host "`n  [ERR] Invalid path '$dirInput': $_`n" -ForegroundColor Red
        return $null
    }

    # Create directory if it doesn't exist
    if (-not (Test-Path -LiteralPath $resolvedDir -PathType Container)) {
        Write-Host "  Directory does not exist. Attempting to create it..." -ForegroundColor Yellow
        try {
            $null = New-Item -ItemType Directory -Path $resolvedDir -Force -ErrorAction Stop
            Write-Host "  Directory created: $resolvedDir" -ForegroundColor Green
        }
        catch {
            Write-Host "`n  [ERR] Could not create directory '$resolvedDir': $_`n" -ForegroundColor Red
            return $null
        }
    }

    # File name
    Write-Host ''
    Write-Host '  Enter the report file name (with or without .csv extension).' -ForegroundColor Cyan
    Write-Host "  Leave blank to use the default:  KerberosRC4_${ReportLabel}_<date>.csv" -ForegroundColor Gray
    Write-Host ''

    $fileInput = (Read-Host '  Report file name').Trim()

    if ([string]::IsNullOrWhiteSpace($fileInput)) {
        $fileInput = "KerberosRC4_${ReportLabel}_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        Write-Host "  Using default file name: $fileInput" -ForegroundColor Gray
    }
    else {
        if (-not $fileInput.EndsWith('.csv', [System.StringComparison]::OrdinalIgnoreCase)) {
            $fileInput = "$fileInput.csv"
        }
    }

    $illegalChars = [System.IO.Path]::GetInvalidFileNameChars()
    if ($fileInput.IndexOfAny($illegalChars) -ge 0) {
        Write-Host "`n  [ERR] File name contains illegal characters.`n" -ForegroundColor Red
        return $null
    }

    $fullPath = [System.IO.Path]::Combine($resolvedDir, $fileInput)

    # Refuse to overwrite without consent
    if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
        Write-Host ''
        Write-Host "  File already exists: $fullPath" -ForegroundColor Yellow
        $owr = (Read-Host '  Overwrite? [y/N]').Trim().ToUpper()
        if ($owr -ne 'Y') {
            Write-Host "  Report cancelled — file not overwritten.`n" -ForegroundColor Gray
            return $null
        }
    }

    # Write-permission test
    Write-Host ''
    Write-Host "  Testing write access to: $fullPath" -ForegroundColor Cyan
    try {
        $testStream = [System.IO.File]::Open(
            $fullPath,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::Read
        )
        $testStream.Close()
        $testStream.Dispose()
        Write-Host "  Write access confirmed.`n" -ForegroundColor Green
    }
    catch {
        Write-Host ''
        Write-Host "  [ERR] Cannot write to '$fullPath'" -ForegroundColor Red
        Write-Host "        Reason : $_" -ForegroundColor Red
        Write-Host ''
        Write-Host '  Possible causes:' -ForegroundColor Yellow
        Write-Host '    - You do not have write permission to this directory' -ForegroundColor Yellow
        Write-Host '    - The path is on a read-only network share' -ForegroundColor Yellow
        Write-Host '    - The file is locked by another process' -ForegroundColor Yellow
        Write-Host ''
        return $null
    }

    return $fullPath
}

# ---------------------------------------------------------------------------
# 10. CSV report — Computer accounts
# ---------------------------------------------------------------------------
function Export-ComputerReport {
    Write-Header 'Export Computer Accounts Report (CSV)'

    Write-Info 'Querying all enabled computer accounts...'
    $computers = @(Get-ADComputer -Filter { Enabled -eq $true } `
        -Properties msDS-SupportedEncryptionTypes, OperatingSystem, OperatingSystemVersion, `
                    LastLogonDate, DistinguishedName |
        Sort-Object Name)

    if ($computers.Count -eq 0) {
        Write-Success 'No enabled computer accounts found.'
        return
    }

    Write-Host "  Found $($computers.Count) enabled computer account(s)." -ForegroundColor Cyan

    $outPath = Get-CsvOutputPath -ReportLabel 'computers'
    if (-not $outPath) { return }

    Write-Info 'Building report rows...'
    $rows = $computers | ForEach-Object {
        $encRaw    = $_.'msDS-SupportedEncryptionTypes'
        $encInt    = if ($null -eq $encRaw) { 0 } else { [int]$encRaw }
        $hasRC4    = Test-HasRC4Risk $encRaw
        $compat    = Test-ComputerAESCompatible -OperatingSystem $_.OperatingSystem `
                                                 -OperatingSystemVersion $_.OperatingSystemVersion

        [PSCustomObject]@{
            Name                  = $_.Name
            DNSHostName           = $_.DNSHostName
            OperatingSystem       = $_.OperatingSystem
            OperatingSystemVersion= $_.OperatingSystemVersion
            LastLogonDate         = if ($_.LastLogonDate) { $_.LastLogonDate.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
            EncryptionRaw         = $encInt
            EncryptionTypes       = Get-EncryptionLabel $encRaw
            HasRC4Risk            = $hasRC4
            AESCompatible         = [bool]$compat.Compatible
            AESCompatibilityReason= $compat.Reason
            DistinguishedName     = $_.DistinguishedName
        }
    }

    try {
        $rows | Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        $rc4count   = @($rows | Where-Object { $_.HasRC4Risk }).Count
        $incompat   = @($rows | Where-Object { -not $_.AESCompatible }).Count

        Write-Host ''
        Write-Success "Report saved: $outPath"
        Write-Host "  Total computers       : $($rows.Count)" -ForegroundColor Cyan
        Write-Host "  RC4 at risk           : $rc4count"      -ForegroundColor $(if ($rc4count)  { 'Yellow' } else { 'Gray' })
        Write-Host "  Not AES-compatible    : $incompat"      -ForegroundColor $(if ($incompat)  { 'Yellow' } else { 'Gray' })
        Write-Log -Level 'AUDIT' -Message "Computer CSV report exported | Path: $outPath | Total: $($rows.Count) | RC4 risk: $rc4count | Not AES-compatible: $incompat"
    }
    catch {
        Write-Fail "Failed to write CSV report: $_"
    }
}

# ---------------------------------------------------------------------------
# 11. CSV report — User accounts
# ---------------------------------------------------------------------------
function Export-UserReport {
    Write-Header 'Export User Accounts Report (CSV)'

    Write-Info 'Querying all enabled user accounts...'
    $users = @(Get-ADUser -Filter { Enabled -eq $true } `
        -Properties msDS-SupportedEncryptionTypes, DisplayName, Department, `
                    UserPrincipalName, ServicePrincipalNames, PasswordLastSet, `
                    LastLogonDate, DistinguishedName |
        Sort-Object SamAccountName)

    if ($users.Count -eq 0) {
        Write-Success 'No enabled user accounts found.'
        return
    }

    Write-Host "  Found $($users.Count) enabled user account(s)." -ForegroundColor Cyan

    $outPath = Get-CsvOutputPath -ReportLabel 'users'
    if (-not $outPath) { return }

    Write-Info 'Building report rows...'
    $rows = $users | ForEach-Object {
        $encRaw  = $_.'msDS-SupportedEncryptionTypes'
        $encInt  = if ($null -eq $encRaw) { 0 } else { [int]$encRaw }
        $hasRC4  = Test-HasRC4Risk $encRaw
        $hasSpn  = @($_.ServicePrincipalNames).Count -gt 0

        [PSCustomObject]@{
            SamAccountName    = $_.SamAccountName
            DisplayName       = $_.DisplayName
            UserPrincipalName = $_.UserPrincipalName
            Department        = $_.Department
            HasSPN            = $hasSpn
            SPNCount          = @($_.ServicePrincipalNames).Count
            EncryptionRaw     = $encInt
            EncryptionTypes   = Get-EncryptionLabel $encRaw
            HasRC4Risk        = $hasRC4
            PasswordLastSet   = if ($_.PasswordLastSet) { $_.PasswordLastSet.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
            LastLogonDate     = if ($_.LastLogonDate)   { $_.LastLogonDate.ToString('yyyy-MM-dd HH:mm:ss')   } else { '' }
            DistinguishedName = $_.DistinguishedName
        }
    }

    try {
        $rows | Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        $rc4count = @($rows | Where-Object { $_.HasRC4Risk }).Count
        $spncount = @($rows | Where-Object { $_.HasSPN }).Count

        Write-Host ''
        Write-Success "Report saved: $outPath"
        Write-Host "  Total users     : $($rows.Count)"  -ForegroundColor Cyan
        Write-Host "  RC4 at risk     : $rc4count"       -ForegroundColor $(if ($rc4count) { 'Yellow' } else { 'Gray' })
        Write-Host "  With SPN (Kerberoastable surface) : $spncount" -ForegroundColor $(if ($spncount) { 'Yellow' } else { 'Gray' })
        Write-Log -Level 'AUDIT' -Message "User CSV report exported | Path: $outPath | Total: $($rows.Count) | RC4 risk: $rc4count | With SPN: $spncount"
    }
    catch {
        Write-Fail "Failed to write CSV report: $_"
    }
}

# ---------------------------------------------------------------------------
# Menu
# ---------------------------------------------------------------------------
function Show-Menu {
    # Build logging status line
    $logStatus = if ($script:LogEnabled) {
        "ENABLED  →  $($script:LogFilePath)"
    } else {
        'DISABLED'
    }
    $logColor = if ($script:LogEnabled) { 'Green' } else { 'Yellow' }

    Write-Host "`n"
    Write-Host '╔══════════════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '║       AD Kerberos RC4 Audit & Remediation Tool                  ║' -ForegroundColor Cyan
    Write-Host '╠══════════════════════════════════════════════════════════════════╣' -ForegroundColor Cyan
    Write-Host '║  AUDIT                                                           ║' -ForegroundColor Cyan
    Write-Host '║   1. List Computer accounts with RC4 enabled / not configured   ║' -ForegroundColor White
    Write-Host '║   2. List User accounts with RC4 enabled / not configured       ║' -ForegroundColor White
    Write-Host '╠══════════════════════════════════════════════════════════════════╣' -ForegroundColor Cyan
    Write-Host '║  REMEDIATE (single)                                              ║' -ForegroundColor Cyan
    Write-Host '║   3. Fix single Computer account (remove RC4, set AES128+256)   ║' -ForegroundColor White
    Write-Host '║   4. Fix single User account    (remove RC4, set AES128+256)   ║' -ForegroundColor White
    Write-Host '╠══════════════════════════════════════════════════════════════════╣' -ForegroundColor Cyan
    Write-Host '║  REMEDIATE (bulk — use with caution!)                            ║' -ForegroundColor Cyan
    Write-Host '║   5. Fix ALL Computer accounts  (remove RC4, set AES128+256)   ║' -ForegroundColor Yellow
    Write-Host '║   6. Fix ALL User accounts      (remove RC4, set AES128+256)   ║' -ForegroundColor Yellow
    Write-Host '╠══════════════════════════════════════════════════════════════════╣' -ForegroundColor Cyan
    Write-Host '║  RESTORE RC4 (rollback — use with caution!)                      ║' -ForegroundColor Cyan
    Write-Host '║   7. Restore RC4 on single Computer account                      ║' -ForegroundColor Magenta
    Write-Host '║   8. Restore RC4 on single User account                          ║' -ForegroundColor Magenta
    Write-Host '╠══════════════════════════════════════════════════════════════════╣' -ForegroundColor Cyan
    Write-Host '║  REPORTS (CSV export)                                            ║' -ForegroundColor Cyan
    Write-Host '║  10. Export Computer accounts report (CSV)                       ║' -ForegroundColor White
    Write-Host '║  11. Export User accounts report (CSV)                           ║' -ForegroundColor White
    Write-Host '╠══════════════════════════════════════════════════════════════════╣' -ForegroundColor Cyan
    Write-Host '║  SETTINGS                                                        ║' -ForegroundColor Cyan
    Write-Host '║   9. Configure logging                                           ║' -ForegroundColor White
    Write-Host '╠══════════════════════════════════════════════════════════════════╣' -ForegroundColor Cyan
    Write-Host '║   Q. Quit                                                        ║' -ForegroundColor Gray
    Write-Host '╠══════════════════════════════════════════════════════════════════╣' -ForegroundColor Cyan
    Write-Host "  Logging: " -NoNewline -ForegroundColor Gray
    Write-Host $logStatus -ForegroundColor $logColor
    Write-Host '╚══════════════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
# Verify AD module is available
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error 'ActiveDirectory module not found. Install RSAT or run from a Domain Controller.'
    exit 1
}
Import-Module ActiveDirectory -ErrorAction Stop

# Verify we can reach AD
try {
    $null = Get-ADDomain -ErrorAction Stop
}
catch {
    Write-Error "Cannot connect to Active Directory: $_"
    exit 1
}

do {
    Show-Menu
    $choice = (Read-Host "`nSelect option [1-11, Q]").Trim().ToUpper()

    switch ($choice) {
        '1'  { Get-RC4Computers }
        '2'  { Get-RC4Users }
        '3'  { Set-SingleComputer }
        '4'  { Set-SingleUser }
        '5'  { Set-AllComputers }
        '6'  { Set-AllUsers }
        '7'  { Restore-RC4Computer }
        '8'  { Restore-RC4User }
        '9'  { Set-LogConfig }
        '10' { Export-ComputerReport }
        '11' { Export-UserReport }
        'Q' {
            Write-Log -Level 'AUDIT' -Message "=== Session ended by $env:USERDOMAIN\$env:USERNAME ==="
            Write-Host "`nGoodbye.`n" -ForegroundColor Gray
        }
        default { Write-Host "`nInvalid option. Please choose 1-11 or Q." -ForegroundColor Red }
    }

    if ($choice -ne 'Q') {
        Read-Host "`nPress Enter to return to menu"
    }

} while ($choice -ne 'Q')
