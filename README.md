# AD Kerberos RC4 Audit & Remediation Tool

A menu-driven PowerShell script to audit and remediate weak RC4 Kerberos encryption on Active Directory user and computer accounts. Replaces RC4 with AES128 + AES256 (`msDS-SupportedEncryptionTypes = 24`), with built-in safety gates, validation, logging, CSV reporting, and rollback.

## Why this exists

RC4-HMAC has been deprecated for Kerberos since Windows Server 2008 and is the encryption used by virtually every published Kerberoasting attack. Microsoft began enforcing AES defaults in the November 2022 update (CVE-2022-37966) and Windows updates starting April 2026 disable RC4 by default for accounts without an explicit encryption setting. This tool helps you find the at-risk accounts and remediate them safely before that enforcement bites.

## Features

- **Audit** — list computer and user accounts with RC4 enabled or no encryption type configured at all (treated as RC4 risk because the KDC falls back to RC4 when the attribute is null).
- **Single-account remediation** — fix one computer or one user, with a before/after validation block read directly from AD.
- **Bulk remediation** — fix all at-risk computer or user accounts in one run, with a per-account verification table.
- **OS compatibility gate** — automatically detects and refuses to apply AES to legacy machines (Windows 2000 / XP / Server 2003) that do not support AES. Safer default: anything with a missing or unparseable `operatingSystemVersion` is treated as incompatible.
- **Rollback** — restore RC4 on a single account if a change broke something.
- **CSV reports** — export all enabled computers or users with their encryption state, AES compatibility, last logon date, SPN presence, and password age. Excel-friendly UTF-8.
- **Logging** — optional structured log file with timestamps, before/after values, and verification results.
- **Validation** — every write is followed by a fresh AD read-back; mismatches are flagged loudly.

## Requirements

- PowerShell 5.1 or later
- ActiveDirectory module (RSAT-AD-PowerShell, or run on a Domain Controller)
- Permissions: Domain Admin, or delegated rights to modify `msDS-SupportedEncryptionTypes` on the target OUs
- DCs ideally patched with the November 2022 cumulative update or later

Install RSAT on Windows 10/11:

```powershell
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

## Quick start

```powershell
# Run from an elevated PowerShell on a DC or a machine with RSAT
.\Manage-KerberosEncryption.ps1
```

The menu:

```
╔══════════════════════════════════════════════════════════════════╗
║       AD Kerberos RC4 Audit & Remediation Tool                  ║
╠══════════════════════════════════════════════════════════════════╣
║  AUDIT                                                           ║
║   1. List Computer accounts with RC4 enabled / not configured   ║
║   2. List User accounts with RC4 enabled / not configured       ║
║  REMEDIATE (single)                                              ║
║   3. Fix single Computer account                                ║
║   4. Fix single User account                                    ║
║  REMEDIATE (bulk — use with caution!)                            ║
║   5. Fix ALL Computer accounts                                  ║
║   6. Fix ALL User accounts                                      ║
║  RESTORE RC4 (rollback)                                          ║
║   7. Restore RC4 on single Computer account                     ║
║   8. Restore RC4 on single User account                         ║
║  REPORTS (CSV export)                                            ║
║  10. Export Computer accounts report                            ║
║  11. Export User accounts report                                ║
║  SETTINGS                                                        ║
║   9. Configure logging                                          ║
║   Q. Quit                                                        ║
╚══════════════════════════════════════════════════════════════════╝
```

## Recommended rollout

The order matters. Don't start with bulk.

1. **Enable logging first (option 9)** — pick a directory and filename. The script tests write access before enabling.
2. **Export both CSV reports (options 10 and 11)** — this is your before-state baseline. Keep it.
3. **Fix one test computer (option 3)** — pick a non-critical, low-traffic machine. Reboot it. Confirm the user can log in.
4. **Fix one test service account (option 4)** — coordinate with the application owner. Confirm the service still authenticates.
5. **Wait 24 hours.** Existing Kerberos tickets stay RC4 until they expire (up to 10 hours by default). Real-world issues surface during this window.
6. **Monitor DC System log** for Event 14, 16, 27 spikes — see [Troubleshooting](#troubleshooting) below.
7. **If quiet → proceed with bulk (options 5 and 6)**, ideally outside business hours.
8. **Re-export CSV reports** as evidence of the change.

`LastLogonDate` in the CSV exports is your friend — stale accounts that haven't logged on in months are the safest first candidates because nobody will notice if they break.

## Encryption bitmask reference

`msDS-SupportedEncryptionTypes` is a 32-bit bitmask. Decoded:

| Bit value | Hex | Meaning |
|---|---|---|
| 1 | 0x01 | DES-CBC-CRC (obsolete) |
| 2 | 0x02 | DES-CBC-MD5 (obsolete) |
| 4 | 0x04 | RC4-HMAC |
| 8 | 0x08 | AES128-CTS-HMAC-SHA1-96 |
| 16 | 0x10 | AES256-CTS-HMAC-SHA1-96 |
| 32 | 0x20 | AES256-CTS-HMAC-SHA1-96-SK (session-key enforcement, post-Nov-2022) |

Common composite values:

| Value | Decoded |
|---|---|
| 0 / null | Not configured — KDC falls back to RC4 (this script flags as at-risk) |
| 4 | RC4 only |
| 24 (0x18) | AES128 + AES256 — **this script's target** |
| 28 (0x1C) | RC4 + AES128 + AES256 (transitional) |
| 56 (0x38) | AES128 + AES256 + AES256-SK (requires patched DCs) |

Why not target 56? The AES256-SK bit (0x20) requires DCs patched with the November 2022 update or later. Unpatched DCs silently drop the bit at write time, leading to mismatch reports even though the write was issued correctly. 24 is the safe universal target.

## OS compatibility for computer accounts

Windows Vista / Server 2008 (`operatingSystemVersion = 6.0`) introduced AES Kerberos. Anything older does not honor `msDS-SupportedEncryptionTypes` at all — applying AES to a Server 2003 box will break its Kerberos authentication.

| OS version | OS | AES support |
|---|---|---|
| 5.0 | Windows 2000 | NO |
| 5.1 | Windows XP | NO |
| 5.2 | Server 2003 / R2 | NO |
| 6.0 | Vista / Server 2008 | yes |
| 6.1 | Windows 7 / Server 2008 R2 | yes |
| 6.2–6.3 | Windows 8/8.1 / Server 2012/R2 | yes |
| 10.0 | Windows 10/11 / Server 2016+ | yes |

The script enforces this automatically on options 3 and 5. If `operatingSystemVersion` is missing or unparseable on a computer object (typical for third-party appliances), the script treats it as incompatible by default. This is intentional — better to skip than break.

## Troubleshooting

### Symptom: User can't log in / app can't authenticate after the change

Most common cause: the account password was last set before Windows Server 2008, so it has no AES keys in AD. The KDC sees "AES required" but has no AES key to encrypt with.

**Where to look:**
- DC Event Viewer → Windows Logs → System
- Filter by Source `Microsoft-Windows-Kerberos-Key-Distribution-Center`
- Look for **Event ID 14** (AS_REQ failed) or **Event ID 16** (TGS_REQ failed)
- The event text says something like `The requested etypes were 18 17. The accounts available etypes were 23.` — 18/17 are AES, 23 is RC4

**Fix:**
- User account: have them change their password (or admin-reset it)
- Computer account: on the affected machine, run `Reset-ComputerMachinePassword` as admin, or just reboot
- Service account: rotate the password and update the application configuration

### Symptom: Existing sessions keep working but new ones fail

Kerberos tickets are cached for up to 10 hours by default. After the change, existing tickets remain RC4-encrypted and continue to work until expiry. Force a refresh on a test client:

```powershell
klist purge
# Then trigger any AD-authenticated action
```

### Symptom: Third-party appliances stop authenticating

NAS, printers, Linux servers, Java apps using JAAS — the `msDS-SupportedEncryptionTypes` setting only governs what AD will issue. If the client itself refuses AES, you still have a problem.

- Linux: check `/etc/krb5.conf` for `permitted_enctypes` or `default_tkt_enctypes`
- NetApp/EMC: check the array's CIFS/SMB security configuration
- Old appliances: they may have a fixed `operatingSystemVersion` below 6.0, which is why this script treats unknown OS as incompatible by default

### Symptom: Cross-forest authentication breaks

Old trusts may not have AES enabled on the trust object itself.

```powershell
Get-ADTrust -Filter * |
    Select-Object Name, Direction, msDS-SupportedEncryptionTypes
```

If a trust has null or RC4-only encryption, enable AES on it with `netdom trust /enableaes:yes` on a DC of the trusting domain.

### Symptom: The script reports MISMATCH even though everything looks right

If you see this on a Server 2003 or older DC, your domain controllers are missing the November 2022 cumulative update. The 0x20 bit (AES256-SK) gets silently filtered. This script targets value 24, not 56, specifically to avoid that — but if you're seeing it, run:

```powershell
(Get-ADDomainController -Discover).HostName |
    ForEach-Object {
        Get-HotFix -ComputerName $_ |
            Where-Object { $_.HotFixID -match 'KB502[0-9]{4}' } |
            Select-Object PSComputerName, HotFixID, InstalledOn
    }
```

### Where the script's own log lives

If you enabled logging via option 9 before running changes, the log is at the path shown in the menu footer. Every account change has a structured entry:

```
2025-06-18 14:32:01  [OK   ]  VERIFIED  | User 'demo' | Before: 0 | After: 24 | Expected: 24
2025-06-18 14:32:02  [ERROR]  MISMATCH  | Computer 'demo' | Before: 28 | After: 28 | Expected: 24
2025-06-18 14:32:03  [WARN ]  SKIPPED legacy OS | Computer 'OLDSRV' | OS: Windows Server 2003 | Version: 5.2
```

If logging was off when the change ran, only what scrolled by in the console exists. Enable logging before every bulk operation as a habit.

### Auditing what etype was actually used

Enable in DC audit policy: **Audit Kerberos Authentication Service** and **Audit Kerberos Service Ticket Operations** (Advanced Audit Policy → Account Logon). Then look at:

- **Event 4768** — AS-REQ (ticket-granting ticket issued)
- **Event 4769** — TGS-REQ (service ticket issued)

Both events have a `Ticket Encryption Type` field. The January 2025 cumulative update for Server 2016+ added richer fields including client-supported etypes.

Quick PowerShell to surface recent Kerberos events on a DC:

```powershell
Get-WinEvent -ComputerName <DC> -FilterHashtable @{
    LogName       = 'System'
    ProviderName  = 'Microsoft-Windows-Kerberos-Key-Distribution-Center'
    Id            = 14, 16, 27, 42
    StartTime     = (Get-Date).AddHours(-24)
} | Select-Object TimeCreated, Id, Message | Format-Table -Wrap
```

## References

Authoritative documentation:

- **Microsoft — Microsoft Security Advisory: Update for disabling RC4** — <https://support.microsoft.com/en-us/topic/microsoft-security-advisory-update-for-disabling-rc4-479fd6f0-c7b5-0671-975b-c45c3f2c0540>
- **Microsoft — Detect and Remediate RC4 Usage in Kerberos** — <https://learn.microsoft.com/en-us/windows-server/security/kerberos/detect-remediate-rc4-kerberos>
- **Microsoft — KB5021131: Kerberos protocol changes related to CVE-2022-37966** — <https://support.microsoft.com/en-us/topic/kb5021131-how-to-manage-the-kerberos-protocol-changes-related-to-cve-2022-37966-fd837ac3-cdec-4e76-a6ec-86e67501407d>
- **Microsoft Community Hub — Active Directory Hardening Series Part 4: Enforcing AES for Kerberos** — <https://techcommunity.microsoft.com/blog/coreinfrastructureandsecurityblog/active-directory-hardening-series---part-4-%E2%80%93-enforcing-aes-for-kerberos/4114965>
- **Microsoft Community Hub — Decrypting the Selection of Supported Kerberos Encryption Types** — <https://techcommunity.microsoft.com/blog/coreinfrastructureandsecurityblog/decrypting-the-selection-of-supported-kerberos-encryption-types/1628797>
- **MS-KILE specification, section 2.2.7** — Kerberos Protocol Extensions, Supported Encryption Types Bit Flags

CVE references:

- **CVE-2022-37966** — Windows Kerberos Elevation of Privilege Vulnerability (the change that flipped Kerberos defaults to AES)

## Known limitations

- The script does **not** touch the krbtgt account. That's intentional. The krbtgt encryption type is controlled by domain functional level and the account's password state, not by `msDS-SupportedEncryptionTypes`. If your krbtgt password was last set before AES support, your TGTs will still be RC4 even after every other account is AES-only. Reset krbtgt twice, at least 10 hours apart, once everything else is remediated.
- Bulk operations run sequentially with no progress bar. For 1000+ accounts you'll want to wait a while; no `Write-Progress` is shown.
- The script targets value 24 (AES128+AES256), not 56 (with AES256-SK). If your DCs are patched November 2022 or later and you want maximum hardening, change `$TARGET_ENC_TYPE` to `$AES128_BIT -bor $AES256_BIT -bor $AES256_SK_BIT` near the top of the script.
- Computer accounts join their own `msDS-SupportedEncryptionTypes` via the netlogon service. If you manually set a value and Group Policy `Network security: Configure encryption types allowed for Kerberos` is also defined on the computer, the GPO setting will overwrite your manual value at next refresh. Manage computer accounts via GPO when possible.

## License

MIT — see LICENSE file.

## Contributing

Issues and PRs welcome. Before opening a PR for behavior changes, please open an issue first so we can discuss the change. Especially for anything touching the write path — AD attribute writes are surprisingly subtle and easy to get wrong (see the commit history).

## Disclaimer

This script modifies Active Directory in ways that can break authentication for users, services, and computers if applied carelessly. Test with options 3 and 4 on individual accounts before using the bulk options. The author is not responsible for downtime caused by skipping the recommended rollout sequence.
