# Engineering status (AI Stocktake v0.1)


## E3 (QA/CI) - Q1 - 2026-10-21

**Done**
- Repo-root `.gitignore` rewritten per ARCHITECTURE.md §6: root-anchored secret rules (`/.env*`, `/secrets/`, `/credentials`, `/credentials.*`, `*.key/*.pem/*.pfx/*.p12/*.token/*.secret`), legacy RC4 `*.log`/`*.csv` and AuthShift outputs still ignored, `!/ai-stocktake/**` so nothing under `ai-stocktake/` (incl. `tests/fixtures/**`) is ignored by root rules. Verified `*token*`, `credentials*`, `.env`, `*.key`, unanchored `reports/`/`secrets/` regressions are gone.
- `ai-stocktake/.gitignore` (standalone-repo ready): scan outputs (`*.aistocktake.json/html`, `/out/`, `/reports/`), test/build outputs, root `.env`; `!/tests/fixtures/**`.
- `ai-stocktake/PSScriptAnalyzerSettings.psd1`: Error+Warning, PSUseCompatibleSyntax (5.1, 7.0), PSUseCompatibleCmdlets (desktop-5.1, core-6.1 Windows), BOM rule; excludes only PSUseShouldProcessForStateChangingFunctions (read-only scanner; justified in file).
- `ai-stocktake/.github/workflows/ci.yml`: jobs hygiene (Hebrew grep + `git check-ignore --no-index` on src/tests/.github), lint, test-linux (excludes `WindowsOnly`), test-windows-ps51 (`shell: powershell`), test-windows-pwsh. Pester >=5.5 / PSScriptAnalyzer from PSGallery, actions pinned to major (`checkout@v4`, `upload-artifact@v4`), `permissions: contents: read`, no secrets. YAML parsed with PyYAML.
- `ai-stocktake/tests/repo/`: NoHebrew, GitIgnore (skips outside a git work tree; verified), Encoding (BOM + strict UTF-8), NoNetworkCalls (tokenizer-based, comments ignored), plus Compatibility.Tests.ps1 (AST check for `??`, `?.`, ternary, `&&`/`||`, `-Parallel`), because PSSA 1.23 PSUseCompatibleSyntax was verified NOT to flag PS7-only operators. All tests include self-tests on generated samples.
- `ai-stocktake/LICENSE` (MIT, "AI Stocktake contributors"), `ai-stocktake/SECURITY.md` (GitHub private vulnerability reporting, no emails).

**Results (local, pwsh 7.4.6 / Pester 5.7.1 / PSSA 1.23.0)**: repo tests pass on my files; PSScriptAnalyzer clean. At time of writing E1's in-progress `src/AIStocktake/AIStocktake.psd1` and `.psm1` fail Encoding.Tests (no UTF-8 BOM) - E1 to fix.

**Left / unverified**
- CI never run: workflow lives in `ai-stocktake/.github/` and only runs once moved to its own repo (or copied to the repo-root `.github/`). Windows PS 5.1 job (NuGet bootstrap, Pester install) unverified.
- ARCHITECTURE.md asks for actions pinned to SHA + Dependabot; brief for Q1 said major versions. Follow-up: SHA pins + `dependabot.yml` once in its own repo.
- Pester is `-MinimumVersion 5.5.0`, not locked (`-RequiredVersion`) as ARCHITECTURE.md suggests.

## E1 (Core) - C1-C4 - 2026-10-21

**Done** (all under `ai-stocktake/`; naming `AIS` / module `AIStocktake`)
- C1: `src/AIStocktake/` module (psd1 v0.1.0, PS 5.1 Desktop+Core; psm1 dot-sources `Private/Core`, `Private/Render`, `Public`; exports `Invoke-AISScan`, `Get-AISCollector`). `New-AISScanContext` (real mode via `[Environment]::GetFolderPath`, or fixture mode via `-Root <dir>` with Windows-like layout + `fixture.json` + `system/*.json`). Registry/process/listener providers in Real and Fixture modes (`$Ctx.Registry.GetUninstallEntries()`, `$Ctx.Processes.GetSnapshot()`, `$Ctx.Listeners.GetListeningPorts()`; netstat/ss fallback parsers). `Resolve-AISPath` ({Token}\rest templates).
- C2: factories `New-AISInventoryItem`, `New-AISFinding`, `New-AISSecretFinding` (takes a fingerprint, never a value), `New-AISScanError`; deterministic 32-hex ids (normalized paths); property bags restricted to camelCase scalar facts with secret-like names rejected. 5.1-safe JSON: `ConvertFrom-AISJsonC` (comments/trailing commas, string-aware), `Read-AISJsonFile` (size limit, errors never quote content), `Write-AISJsonFile` (Depth 20, UTF-8 no BOM), `ConvertTo-AISPlainData`. `New-AISFingerprint` = `hmac-sha256:` + 16 hex (verified against RFC 4231), `ConvertTo-AISPseudonym` (domain-separated). Key: 32 random bytes in `<LocalAppData>/AIStocktake/fingerprint.key` (DPAPI CurrentUser on Windows, mode 0600 elsewhere), refused if inside `-OutputPath`; fixture scans use an in-memory key; tests pass generated keys. `New-AISSafeException`: only messages declared safe reach `errors[]`.
- C3: `schema/scan-result.v1.schema.json` (draft-07, URN `$id`, every object `additionalProperties:false`, secret object has no value field, `fp` pattern-locked, property bag names/values constrained) + `Write-AISScanResult` (`scan-<host>-<UTC stamp>.aistocktake.json`, matches E3's ignore rules).
- C4: `Invoke-AISScan`: discovery from `Private/Collectors/*.ps1` (+ `-CollectorPath`), validation, `-Include/-Exclude` wildcards, platform/elevation skips, per-collector try/catch with `$ErrorActionPreference='Stop'`, soft timeout, typed output routing, `-MachineWide` (NotElevated error + continue), `-PrivacyMode` (alias `-RedactUser`: profile paths -> `{UserProfile}`, user/host -> `hmac:` pseudonyms, ids re-keyed), `-FailOnSeverity` (default high). Exit codes: 1 findings >= threshold (wins), 2 fatal or errors, else 0; `scripts/ai-stocktake.ps1` turns it into the process exit code. Example collector `Environment` (host OS/PS). Contract: `docs/COLLECTOR-CONTRACT.md`.
- Tests: `tests/Unit/*` (Module, PathResolver, ScanContext, Json, Hash, Objects, Collectors, Schema, Redaction) + `tests/Integration/Scan.EndToEnd.Tests.ps1` against `tests/fixtures/profiles/dev-basic/` (incl. schema validation with Test-Json, privacy, machine-wide, exit codes, CLI wrapper).

**Results (local, pwsh 7.4.6 / Pester 5.7.1 / PSSA 1.23.0)**: full suite 267 passed, 0 failed, 1 skipped (DPAPI test, WindowsOnly); of these 107 are E1 tests (+1 skipped), 160 are E3 repo tests. PSScriptAnalyzer with `PSScriptAnalyzerSettings.psd1`: 0 findings. All .ps1/.psm1/.psd1 have a BOM; no Hebrew.

**Left / unverified**
- Not run on Windows PowerShell 5.1 or real Windows: DPAPI key storage, real registry/CIM/Get-NetTCPConnection providers, `Win32_UserProfile` enumeration for machine-wide. CI windows jobs must confirm.
- Soft timeout does not interrupt a hung collector (would need runspaces); it only reports `SoftTimeoutExceeded`.
- Catalog loading is a minimal stub (`Import-AISCatalog`: all `catalog/**/*.json`, version from `catalog/catalog.json`); K1 owns the catalog schema.
- Kind enum is closed (`app, agent, extension, mcp-server, runtime, host`); new kinds need a schema + factory change. RuleId pattern is `^[A-Z]{2,5}-[A-Z0-9]{2,10}-[0-9]{3}$` (PRD `AIF-*` ids should be renamed `AIS-*`).
- Creating the key file on first real scan is the one write outside `-OutputPath` (documented; `-EphemeralKey` avoids it). PRD says `sha256` truncated to 12 hex for secrets; implementation follows ARCHITECTURE.md (keyed HMAC, 16 hex). PM/CEO should align the PRD.
