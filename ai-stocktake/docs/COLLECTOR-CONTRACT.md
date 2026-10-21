# Collector contract (v1)

A collector is one PowerShell file that finds one kind of thing on a workstation
(apps, MCP configs, browser extensions, listeners, ...) and reports it as
standard objects. `Invoke-AISScan` discovers collectors, runs each one in
isolation, and merges their output into the scan result
(`schema/scan-result.v1.schema.json`).

This document is the contract between the core (`src/AIStocktake/Private/Core`)
and collector authors. Anything not listed here is internal and may change.

## 1. File and discovery

- Location: `src/AIStocktake/Private/Collectors/<Id>.ps1`. Extra folders can be
  passed with `Invoke-AISScan -CollectorPath <dir>` (used by tests).
- The file name (without `.ps1`) must equal the collector `Id`.
- Files are UTF-8 with BOM, English only, PowerShell 5.1 syntax.
- The module does NOT dot-source collectors at import. `Import-AISCollector`
  loads each file at scan time inside the module scope, so the `Invoke`
  scriptblock can call the module's private helpers listed in section 4.
- A file that throws while loading, does not assign `$Collector`, or fails
  validation is skipped and reported in `errors[]` (`code: InvalidCollector`).
  Duplicate ids: the first one (by folder order, then file name) wins, the
  others are reported as `DuplicateCollector`.

## 2. Shape

```powershell
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'Collector', Justification = 'Read by Import-AISCollector.')]
param()

$Collector = @{
    Id                = 'McpConfigs'          # required, PascalCase, = file name
    Version           = '1.0.0'               # required, semver; bump when output changes
    Description       = 'MCP server configs'  # optional
    Platforms         = @('Windows', 'Linux', 'MacOS')  # optional, default: all three
    RequiresElevation = $false                # optional, default $false
    TimeoutSeconds    = 30                    # optional, 1..600, default 30 (soft budget)
    Invoke            = {                     # required
        param($Ctx, $Catalog)
        # emit objects created by the factories in section 4
    }
}
```

Only these keys are allowed (typos such as `Platform` are rejected). The
`param()` line with the attribute keeps PSScriptAnalyzer quiet about
`$Collector` being "assigned but never used".

## 3. Execution rules

| Situation | Result |
|---|---|
| `Platforms` does not contain `$Ctx.Platform` | status `skipped`, not run |
| `RequiresElevation` and the scan is not elevated | status `skipped`, not run |
| Not selected by `-Include` / excluded by `-Exclude` | status `skipped` (`reason: Not selected.`) |
| Invoke completes | status `ok` |
| Invoke throws (or writes a non-terminating error) | status `error`, one entry in `errors[]`, output emitted before the failure is kept |
| Run time above `TimeoutSeconds` | the collector is NOT interrupted; a `SoftTimeoutExceeded` error is added |

- `Invoke` runs with `$ErrorActionPreference = 'Stop'`: any non-terminating
  error fails the collector. Use `-ErrorAction SilentlyContinue` deliberately
  where a miss is expected (for example `Test-Path`, `Get-ChildItem` on a
  folder that may not exist).
- Collectors run one after another, sorted by `Id`. Do not rely on order.
- Output objects are routed by type name. Anything that is not created by a
  factory is dropped and counted in one `InvalidCollectorOutput` error.

### Error messages must be safe

Exception messages can quote file content (`ConvertFrom-Json` does), and file
content can contain secrets. The orchestrator therefore copies an exception
message into `errors[]` ONLY when the exception was created by
`New-AISSafeException`. Every other exception is reported as
`"Collector '<Id>' failed with <ExceptionType>. Details are withheld ..."`.

```powershell
throw (New-AISSafeException -Code 'ConfigUnreadable' -Message ('Cannot read ' + $path))
```

For a partial problem (one unreadable file among many), emit a non-fatal
error and continue:

```powershell
New-AISScanError -Collector 'McpConfigs' -Code 'ConfigUnreadable' -Message ('Skipped ' + $path)
```

(`collector` is overwritten with the emitting collector's id.) Messages may
contain paths, never configuration values.

## 4. What a collector may use

### `$Ctx` (AIS.ScanContext)

| Member | Meaning |
|---|---|
| `Mode` | `'user'` or `'machine'` (machine only when `-MachineWide` and elevated) |
| `Platform` | `'Windows'`, `'Linux'`, `'MacOS'` (from `fixture.json` in fixture mode) |
| `Os`, `PowerShell` | `@{ family; version }`, `@{ version; edition }` |
| `HostName`, `UserName` | raw values; privacy mode redacts them in the output automatically |
| `IsElevated`, `PrivacyMode`, `IsFixture` | booleans |
| `Roots` | current-user roots: `UserProfile, AppData, LocalAppData, ProgramData, ProgramFiles, ProgramFilesX86, SystemDrive, UsersRoot` |
| `Profiles` | profiles to scan: `@{ Name; Sid; IsCurrent; Roots }`. One entry in user mode, all profiles in machine mode. Iterate this for per-user locations. |
| `Registry.GetUninstallEntries('HKCU'\|'HKLM' [, $profile])` | uninstall entries: `Hive, KeyName, DisplayName, DisplayVersion, Publisher, InstallLocation, InstallDate` |
| `Processes.GetSnapshot()` | `ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine` |
| `Listeners.GetListeningPorts()` | TCP listeners: `Protocol, LocalAddress, LocalPort, ProcessId` |
| `Now()` | scan clock (UTC); fixed by `fixture.json` in tests |
| `FingerprintKey` | key bytes for `New-AISFingerprint`; never log, emit or store it |

Never call the registry, CIM, `Get-Process`, `Get-NetTCPConnection` or
`$env:` paths directly: go through `$Ctx` so the collector works against
fixtures on Linux CI.

**`CommandLine` is raw and may contain secrets.** Pass it through the
command-line redactor (task S1) before anything derived from it is stored.

### `$Catalog` (AIS.Catalog)

`Version` and `Data`: every `catalog/**/*.json` parsed with JSONC support,
keyed by relative path without extension (`Data['mcp-clients']`,
`Data['tools/cursor']`). The catalog schema is owned by task K1.

### Helpers

| Function | Use |
|---|---|
| `Resolve-AISPath -Template '{AppData}\Claude\x.json' -Roots $profile.Roots` | template to full path (also `-Context $Ctx`) |
| `Read-AISJsonFile -LiteralPath $p` | JSON/JSONC file to object; size-limited; errors never contain content |
| `ConvertFrom-AISJsonC -Text $t` | same for text |
| `Get-AISFieldValue -InputObject $o -Name 'x'` | read an optional property without errors |
| `New-AISInventoryItem` | inventory item (section 5) |
| `New-AISFinding` | finding (section 5) |
| `New-AISSecretFinding` | secret by fingerprint (section 5) |
| `New-AISScanError` | non-fatal error |
| `New-AISSafeException` | fatal error with a message safe for the output |
| `New-AISFingerprint -Key $Ctx.FingerprintKey -Value $raw` | `hmac-sha256:<16 hex>` |
| `New-AISDeterministicId` | custom stable ids if ever needed |

## 5. Output objects

All ids are deterministic (SHA-256 of normalized parts, 32 hex chars), so the
same thing gets the same id on every scan. Paths in ids are normalized
(`\` and `/`, case-insensitive). In privacy mode the orchestrator re-keys all
ids and `inventoryRef`s consistently; collectors do nothing special.

**InventoryItem**: `-Kind app|agent|extension|mcp-server|runtime|host`,
`-Name`, optional `-ToolId` (catalog id, lower-case), `-Version`,
`-Scope user|machine`, `-UserProfileName` (profile `Name`), `-Source
registry|file|process|port|system`, `-Path`, `-Properties`,
`-IdDiscriminator`. id = (kind, toolId, scope, profile, name,
discriminator, path).

`-Properties` is a small allowlist of facts: camelCase keys; values are
strings (max 1024 chars), numbers, booleans or arrays of those (max 100).
Names that could carry a secret are rejected (`value, raw, secret, password,
token, apiKey, key, credential, authorization, cookie, connectionString, env,
headers`, ...). **Never copy a raw config object into properties.** Copy
named, non-secret fields (for example `command`, the package name) after
redaction.

**Finding**: `-RuleId` (`AIS-MCP-002` style), `-Category`, `-Severity
info|low|medium|high|critical`, `-Title`, optional `-ToolId`,
`-InventoryRef` (an inventory id), `-EvidencePath`, `-JsonPointer`,
`-Detail`, `-Remediation`, `-References`, `-IdDiscriminator`. id = (ruleId,
evidence path, jsonPointer, discriminator). `-Detail` must never contain a
secret value or an unredacted command line.

**SecretFinding**: takes `-Fingerprint` (never a value), `-Type`, `-RuleId`,
`-Path`, `-JsonPointer`, `-LengthBucket '<20'|'20-40'|'>40'`, optional
`-KnownPrefix` (the public prefix of the pattern only, such as `ghp_`) and
`-InventoryRef`. A secret should also produce a normal Finding (for example
`AIS-SEC-001`) so it affects the exit code.

Strings over the schema limits are truncated by the factories.

## 6. Exit codes (Invoke-AISScan)

| Code | Meaning |
|---|---|
| 0 | no finding at or above `-FailOnSeverity` (default `high`) and no errors |
| 1 | at least one finding at or above `-FailOnSeverity` (wins over errors) |
| 2 | fatal error (nothing written), or errors[] not empty and no finding at the threshold |

Only findings count toward the threshold, not inventory or secrets entries.

## 7. Fixtures

`Invoke-AISScan -Root <dir>` replaces the machine with a fixture folder:

```
<dir>/fixture.json                     hostName, userName, os{family,version},
                                       powershell{version,edition}, isElevated, now
<dir>/Users/<user>/                    {UserProfile}  (AppData/Roaming, AppData/Local below it)
<dir>/ProgramData/  <dir>/Program Files/  <dir>/Program Files (x86)/
<dir>/system/registry.HKLM.json        array of uninstall entries
<dir>/system/registry.HKCU.json        current fixture user
<dir>/system/registry.HKCU.<user>.json other profiles (machine-wide)
<dir>/system/processes.json            array of processes
<dir>/system/listeners.json            array of {LocalAddress, LocalPort, ProcessId}
```

A missing snapshot file means "no data". In fixture mode the scan uses a
random in-memory fingerprint key unless `-FingerprintKey` or
`-FingerprintKeyPath` is given; tests pass a generated key.

Fixture files must never contain realistic secrets. Secret test values are
generated at test time from templates (task S2).

## 8. Testing a collector

- Unit tests go in `tests/Collectors/<Id>.Tests.ps1` (Pester 5), tag `Collector`.
- Build a fixture under `tests/fixtures/profiles/<name>/` or in `TestDrive:`,
  then either call the collector through the orchestrator:
  `Invoke-AISScan -Root $fixture -Include '<Id>' -FingerprintKey $key`
  or run it directly with `InModuleScope AIStocktake { Invoke-AISCollector ... }`.
- Cover a positive, a negative and an edge case per detection (PRD section 8).
