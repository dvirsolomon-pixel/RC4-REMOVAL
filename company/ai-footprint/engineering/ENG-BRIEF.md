# Engineering brief — AI Stocktake v0.1 (shared by all engineers)

**Product name:** AI Stocktake. PowerShell module name: `AIStocktake`. Command prefix: `AIS` (e.g. `Invoke-AISScan`).
**Staging location:** all code lives under `ai-stocktake/` at the repo root (it will later be moved, as-is, to a new public repo `ai-stocktake`, so treat `ai-stocktake/` as the repo root: its own README.md, LICENSE (MIT), `.github/workflows/` inside it is fine for now and will move).
**Sources of truth:** `company/ai-footprint/product/PRD.md`, `company/ai-footprint/product/ROADMAP.md`, `company/ai-footprint/engineering/ARCHITECTURE.md`. Where ARCHITECTURE.md says `footprint/`, read `ai-stocktake/`.

## Non-negotiable rules
- All code, comments, CLI output, report text and docs under `ai-stocktake/` are **English only**.
- **Never** commit real secrets, tokens, passwords, personal data. Test secrets must be generated at test time from templates (never literal realistic keys in the repo), per ARCHITECTURE.md.
- Secret values must never appear in any output, log or exception message. Only fingerprints.
- No network calls in v0.1 (the scanner is offline-only). No telemetry.
- PowerShell **5.1 compatible** syntax (no `??`, `?.`, ternary, `-Parallel`, `using namespace` tricks etc.), UTF-8 with BOM for .ps1/.psm1/.psd1.
- Read-only: the scanner never modifies the machine.
- Do not modify files outside `ai-stocktake/` except `.gitignore` (only the E1 engineer, per ARCHITECTURE.md §7) and your status note in `company/ai-footprint/engineering/`.
- Do NOT git commit or push — the CEO reviews and commits.

## Local toolchain (Linux container)
```
PWSH=/tmp/claude-0/-home-user-RC4-REMOVAL/5cbe3a4e-7315-5522-b0c4-35d5567efe9e/scratchpad/pwsh/pwsh
export PSModulePath=/tmp/claude-0/-home-user-RC4-REMOVAL/5cbe3a4e-7315-5522-b0c4-35d5567efe9e/scratchpad/psmods
$PWSH -NoProfile -c 'Invoke-Pester ./ai-stocktake/tests -Output Detailed'
$PWSH -NoProfile -c 'Invoke-ScriptAnalyzer -Path ./ai-stocktake -Recurse -Settings ./ai-stocktake/PSScriptAnalyzerSettings.psd1'
```
Pester 5.7.1, PSScriptAnalyzer 1.23.0, PowerShell 7.4.6. PSGallery is blocked from this container; Windows PowerShell 5.1 is only available in GitHub Actions CI (windows-latest). Windows-only APIs (registry, Get-Process details, Get-NetTCPConnection) must go through the scan-context abstraction so tests on Linux use fixtures.

## Definition of done for any task
Tests written and passing locally, PSScriptAnalyzer clean (per settings), no Hebrew characters under `ai-stocktake/`, no secret leaks, short status note appended to `company/ai-footprint/engineering/STATUS.md` (what was done, what is left, anything unverified).
