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
