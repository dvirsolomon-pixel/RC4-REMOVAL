# AI Footprint Scanner — ארכיטקטורה הנדסית (v0.1)

**מאת:** ארכיטקט התוכנה · **תאריך:** 2026-10-21 · **סטטוס:** טיוטה לאישור המנכ"ל
**מבוסס על:** `decisions/003-ai-security-product.md` (מאושר), `research/ai-security/03-pain-feasibility.md`, `.gitignore`

**מגבלות מחייבות:** תקציב 0. GitHub בלבד. כל מחרוזות המוצר באנגלית. אין סודות בריפו. אין telemetry בלי רישום מפורש. תאימות ל-PowerShell 5.1. סריקה per-user בלי הרשאות admin. המהנדסים הם סוכני AI בקונטיינר Linux, ו-**`pwsh` לא מותקן בו** (`which pwsh` החזיר rc=1). לכן אמת המידה היא CI ב-GitHub Actions (סעיף 6). אם רשת הקונטיינר מאפשרת, מהנדס יכול להתקין pwsh מקומית, אבל זו לא דרישה.

---

## 1. מבנה הריפו ודו-קיום עם הכלי הישן

המוצר החדש יושב בתיקייה אחת בשורש, `footprint/`. כך אין התנגשות עם `Manage-KerberosEncryption.ps1`, עם `tests/Fixtures` שתוכנן ל-AuthShift, ועם `src/AuthShift`. בנוסף, path filters ב-CI פשוטים.

```
footprint/
  agent/AIFootprint/            # PowerShell module (PS 5.1+)
    AIFootprint.psd1 / .psm1
    Public/   Invoke-AIFootprintScan.ps1, Export-AIFootprintReport.ps1, Register-AIFootprintDevice.ps1 (v0.2)
    Private/  Core/ (ScanContext, PathResolver, Finding, JsonC, Hmac)
              Collectors/ (Apps, BrowserExtensions, CodingAgents, McpConfigs, Secrets, LocalLlm, Processes)
              Render/ (Html, Json)
    Templates/report.html        # inline CSS/JS, placeholders only
  catalog/                       # data-driven, community-extended (JSON)
    tools/*.json  extensions.json  mcp-clients.json  risk-rules.json  secret-rules.json
    catalog.schema.json
  schema/scan-result.v1.schema.json
  tests/
    Unit/ Collectors/ Integration/ Security/   # Pester 5
    fixtures/profiles/<name>/    # fake user profiles (templates, no real-looking secrets)
    fixtures/system/<name>/      # fake registry/process/port snapshots as JSON
  tools/ Invoke-Build.ps1, Test-Catalog.ps1, Test-GitIgnore.ps1
  dashboard/                     # v0.2+: worker/, web/, migrations/ (design only, section 5)
.github/workflows/footprint-ci.yml
```

- הכלי הישן לא משתנה. ה-workflow החדש רץ רק על `footprint/**`, וכל workflow של AuthShift רץ רק על הנתיבים שלו.
- ה-README בשורש מקבל קישור אחד ל-`footprint/README.md`. ב-v0.1 אין פיצול לריפו נפרד. אפשר לשקול פיצול כשנגיע לכ-30 כוכבים.
- נקודת כניסה: `Invoke-AIFootprintScan -OutputPath .\out [-MachineWide] [-PrivacyMode] [-Root <fixtureDir>]`.

## 2. תכנון ה-agent

### 2.1 ScanContext וההפשטה של הנתיבים
כל collector מקבל אובייקט `ScanContext` ולא נוגע ישירות ב-`$env:`, ב-registry או ב-CIM:

```powershell
$ctx.Roots      # @{ UserProfile; AppData; LocalAppData; ProgramData; ProgramFiles; ... }
$ctx.Registry   # provider: Get-UninstallEntries -Hive HKCU|HKLM
$ctx.Processes  # provider: Get-ProcessSnapshot
$ctx.Listeners  # provider: Get-TcpListeners (Get-NetTCPConnection, or a netstat -ano fallback)
$ctx.Clock; $ctx.FingerprintKey; $ctx.PrivacyMode; $ctx.IsElevated
```
- **מצב אמיתי:** הנתיבים מגיעים מ-`[Environment]::GetFolderPath`, וה-providers פונים למערכת.
- **מצב fixture** (`-Root`): כל הנתיבים מתמפים לתיקיות בתוך fixture. גם ה-providers קוראים קבצי JSON מ-`fixtures/system/*`, למשל `registry.HKCU.json`, `processes.json` ו-`listeners.json`. כך כמעט כל הבדיקות רצות על Linux.
- הקטלוג כותב נתיבים בצורה `{AppData}\Claude\claude_desktop_config.json`, ופונקציה אחת בשם `Resolve-AifPath` פותרת אותם עם `Join-Path`. בגלל זה הקוד נייד בין Windows ל-Linux.
- **מצב machine-wide** (`-MachineWide` עם admin): הסורק עובר על כל הפרופילים ב-`C:\Users\*` וגם על HKLM. אם אין הרשאה, הוא מתעד שגיאה ב-`errors[]` וממשיך. ריצה שקורסת באמצע לא מקובלת.

### 2.2 Collectors שאפשר להוסיף כ-plugins
כל collector הוא קובץ שמממש חוזה אחד:
```powershell
# Private/Collectors/McpConfigs.ps1
$Collector = @{ Id='McpConfigs'; Version='1.0.0'; RequiresElevation=$false; Platforms=@('Windows','Linux','MacOS')
                Invoke = { param($Ctx, $Catalog) <# returns InventoryItem[] and Finding[] #> } }
```
הרשמה נעשית באמצעות סריקת התיקייה, וכל collector רץ בתוך `try/catch` משלו עם timeout רך. הפרמטרים `-Include`/`-Exclude` מאפשרים לבחור אילו collectors ירוצו.

| Collector | מקור | מה הוא מפיק |
|---|---|---|
| Apps | Uninstall HKCU/HKLM, Appx, `{LocalAppData}\Programs` | InventoryItem kind=`app` |
| BrowserExtensions | Chrome/Edge/Brave `*/Extensions/*/*/manifest.json`, Firefox `extensions.json` | `extension` + finding על הרשאות כמו `<all_urls>` |
| CodingAgents | Claude Code, Cursor, Copilot, Gemini CLI, Codex, Windsurf (settings) | `agent` + findings על הרשאות מסוכנות |
| McpConfigs | 7 clients לפי `mcp-clients.json` | `mcp-server` + findings (npx בלי גרסה נעולה, shell/fs) |
| Secrets | ערכים בתוך configs שנמצאו + `.env` בנתיבים מוכרים | `secret` (fingerprint בלבד, סעיף 3) |
| LocalLlm | listeners על 11434, 1234 וכו' | finding אם ה-bind הוא `0.0.0.0` או `::` |
| Processes | `Win32_Process` (שם ושורת פקודה מקוצרת) | התאמה ל-`tools/*.json` |

שורות פקודה עלולות להכיל סודות, ולכן הן עוברות דרך ה-redactor של סעיף 3 **לפני** שהן נשמרות באובייקט כלשהו.

### 2.3 אובייקטים סטנדרטיים
```powershell
[pscustomobject]@{ PSTypeName='AIF.InventoryItem'; id; kind; toolId; name; version; scope='user|machine';
                   profile; source='registry|file|process|port'; path; properties=@{} }
[pscustomobject]@{ PSTypeName='AIF.Finding'; id; ruleId='AIF-MCP-001'; category; severity='info|low|medium|high|critical';
                   title; toolId; inventoryRef; evidence=@{ path; jsonPointer; detail }; remediation; references=@() }
```
ה-`id` דטרמיניסטי: hash של `ruleId`, נתיב מנורמל ו-`jsonPointer`. כך ה-SaaS יכול לחשב diff בין סריקות.

### 2.4 הקטלוג
הקטלוג כתוב ב-JSON ולא ב-YAML, כי ל-PS 5.1 אין parser מובנה ל-YAML. דוגמה לכלי:
```json
{ "id": "cursor", "name": "Cursor", "category": "coding-agent",
  "detect": { "uninstallDisplayName": ["^Cursor"], "paths": ["{LocalAppData}\\Programs\\cursor"], "processes": ["Cursor.exe"] },
  "configs": [ { "path": "{UserProfile}\\.cursor\\mcp.json", "format": "jsonc", "mcpRoot": "mcpServers" } ],
  "riskySettings": [ { "ruleId": "AIF-AGENT-003", "jsonPointer": "/yoloMode", "equals": true, "severity": "high" } ] }
```
- כל כלל ב-`risk-rules.json` מצהיר על אופרטור מתוך רשימה סגורה: `equals`, `matches`, `exists`, `contains`, `unpinnedPackage`. אין `eval` ואין scriptblocks בקטלוג, כדי ש-PR מהקהילה לא יוכל להריץ קוד.
- `Test-Catalog.ps1` מאמת את הקטלוג מול `catalog.schema.json` ב-CI, וגם בודק ייחודיות של `id`/`ruleId` ושה-regex מתקמפל.
- הסריקה רושמת `catalogVersion` (semver) בכל פלט.
- קבצי `jsonc` (VS Code, Gemini) עוברים דרך `ConvertFrom-JsonC`, שמסיר הערות ופסיקים מיותרים לפני `ConvertFrom-Json`, כי ב-5.1 אין `-AsHashtable` ואין תמיכה בהערות.

## 3. זיהוי סודות

**כללים** (`secret-rules.json`): לכל כלל יש `type`, `regex` ו-`keywordHint`. הכללים מכסים `sk-ant-`, `sk-`/`sk-proj-`, `ghp_`/`github_pat_`, `xoxb-`, `AKIA[0-9A-Z]{16}`, `AIza`, `hf_`, JWT ו-PEM header. כלל גנרי נוסף מחפש מפתח בשם `*KEY*|*TOKEN*|*SECRET*|*PASSWORD*` שהערך שלו ארוך מ-16 תווים, עם Shannon entropy של 3.5 ומעלה. הסריקה עוברת רק על ערכי מחרוזת ב-`env`, `args`, `headers` ו-`url` (query/userinfo) של configs, ועל קבצי `.env` שהקטלוג מצביע עליהם. היא לא סורקת דיסק מלא.

**Fingerprint:**
```
fp = "hmac-sha256:" + hex(HMAC_SHA256(key, utf8(rawValue)))[0..15]   # 64 bits
```
- `key` הוא מפתח אקראי של 32 בתים שנוצר בהתקנה ונשמר ב-`{LocalAppData}\AIFootprint\` מוגן DPAPI CurrentUser. אחרי הרישום ל-SaaS המפתח הוא פר-tenant, כדי לזהות את אותו סוד על כמה תחנות. בלי המפתח אי אפשר לבצע brute-force מול ה-hash.
- מה מדווח: `type`, `fp`, `ruleId`, `location` (נתיב ו-jsonPointer), `lengthBucket` (`<20`, `20-40`, `>40`), ו-`knownPrefix` רק כשהוא חלק מהתבנית הציבורית (למשל `ghp_`). **אף פעם לא תו מתוך החלק הסודי**, כולל 4 התווים האחרונים.

**ערבות שהערך הגולמי לא יוצא:**
1. פונקציה אחת, `Get-SecretMatches`, מחזירה רק אובייקטי `AIF.SecretFinding`. הערך הגולמי קיים רק כמשתנה מקומי בתוכה.
2. אין לוג, `Write-Verbose` או `Write-Debug` עם ערכי config. חריגות נתפסות ונזרקות מחדש עם הודעה גנרית, כי `ErrorRecord` של ConvertFrom-Json עלול לצטט תוכן.
3. אובייקטי config גולמיים לא נשמרים ב-`properties`. ה-collector מעתיק רק שדות מ-allowlist, כמו `command` ושם החבילה, ואחרי redaction.
4. מגבלה: ב-.NET אי אפשר לאפס string בזיכרון. הפתרון הוא לקצר את אורך החיים של הערך ולא להחזיק הפניות אליו. זה מתועד ב-SECURITY.md.

**בדיקות** (`tests/Security/NoSecretLeak.Tests.ps1`):
- הסודות ב-fixtures נוצרים **בזמן הבדיקה**. תבניות כמו `{{SECRET:github_pat}}` מוחלפות בערכים אקראיים בתוך `TestDrive:`, כך שאין בריפו מחרוזות שנראות כמו סוד אמיתי, ו-push protection לא מופעל.
- הבדיקה מריצה סריקה מלאה עם `*>&1` וגם transcript, ואז מחפשת כל ערך שנוצר, וכל תת-מחרוזת שלו באורך 8 ומעלה. החיפוש עובר על JSON, HTML, כל ה-streams, `errors[]` ו-transcript, ונכשל על כל התאמה.
- בדיקה חיובית מוודאת שכל סוד שנוצר זוהה עם ה-`type` הנכון וה-`fp` הצפוי.

## 4. JSON Schema v1 ודוח HTML

```json
{ "schemaVersion": "1.0.0",
  "scan":   { "id": "uuid", "startedAt": "ISO-8601Z", "durationMs": 0, "agentVersion": "0.1.0",
              "catalogVersion": "2026.10.0", "mode": "user|machine", "elevated": false, "privacyMode": false,
              "collectors": [ { "id": "McpConfigs", "version": "1.0.0", "status": "ok|error|skipped" } ] },
  "device": { "hostname": "PC-01 | hmac:..", "os": { "family": "Windows", "version": "10.0.26100" }, "users": ["hmac:.."] },
  "inventory": [ /* AIF.InventoryItem */ ], "findings": [ /* AIF.Finding */ ],
  "secrets":   [ { "id": "", "type": "github_pat", "fp": "hmac-sha256:…", "ruleId": "", "location": {}, "lengthBucket": "" } ],
  "errors":    [ { "collector": "", "code": "", "message": "" } ],
  "summary":   { "bySeverity": { "high": 0 }, "tools": 0, "mcpServers": 0 } }
```
- בכל האובייקטים `additionalProperties:false`. בשדות סוד אין שדה בשם `value`. שינוי minor מוסיף רק שדות אופציונליים, ושינוי שובר מחייב `2.0.0`.
- ב-`PrivacyMode` שמות משתמשים ושם המחשב הופכים ל-HMAC, ונתיבים מנורמלים ל-`{UserProfile}\...`.
- כתיבה ב-5.1: תמיד `ConvertTo-Json -Depth 20` (ברירת המחדל היא 2) ו-`[IO.File]::WriteAllText` עם UTF-8 בלי BOM.
- ב-5.1 אין `Test-Json`. האימות מול הסכמה נעשה ב-CI עם pwsh 7 (`Test-Json -SchemaFile`).

**דוח HTML:** קובץ יחיד, `aif-report-<host>-<date>.html`.
- CSS ו-JS (מיון וסינון, וניל) מוטמעים בקובץ. אין `http(s)://` ב-`src`/`href`, אין fonts חיצוניים ואין CDN.
- `<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-…'; img-src data:">`.
- כל ערך שמוצג עובר `[System.Net.WebUtility]::HtmlEncode`. הקוד לא בונה HTML משרשור לא מקודד.
- ה-JSON המלא מוטמע ב-`<script type="application/json" id="data">`, ותווים מסוכנים (`<`, `>`, `&`, U+2028/2029) מומרים ל-`\u003c` וכדומה.
- בדיקות: (1) fixture עם שם שרת MCP `"><script>alert(1)</script>` שחייב להופיע מקודד; (2) regex שמוודא שאין משאב חיצוני; (3) הדוח נפתח ונקרא offline.

## 5. SaaS עתידי (תכנון בלבד, v0.2)

**זרימת רישום:**
1. אדמין נכנס לדשבורד (GitHub OAuth, או Entra OIDC כאפליקציה multi-tenant חינמית). אין magic link, כי שליחת מייל אינה חינמית ואמינה.
2. האדמין יוצר enrollment token עם הקידומת `aif_enr_`, 32 בתים אקראיים, תוקף ב-`expiresAt` ו-`maxDevices`. הטוקן מוצג פעם אחת ונשמר רק כ-SHA-256.
3. על התחנה: `Register-AIFootprintDevice -EnrollmentToken … -Endpoint …`, דרך פרמטר ב-Intune או GPO. הפקודה שולחת `POST /v1/enroll`, ומקבלת `deviceId`, `deviceSecret` ו-`fingerprintKey` של ה-tenant. הם נשמרים ב-DPAPI (LocalMachine כשהריצה כ-SYSTEM).
4. ingest: `POST /v1/ingest` עם `Authorization: AIF-HMAC deviceId:ts:sig` על הגוף. ה-Worker בודק סטייה של עד 5 דקות ונונס.
5. **אין קוד רשת** בנתיב הסריקה. העלאה קורית רק אם `-Upload` צוין והתחנה רשומה. זה נבדק בבדיקה סטטית: המחרוזות `Invoke-WebRequest`/`Invoke-RestMethod` מותרות רק בקובץ `Public/Send-*`.

**API:** `POST /v1/enroll` · `POST /v1/ingest` · `GET /v1/devices` · `GET /v1/devices/:id/scans` · `GET /v1/findings?severity=` · `POST|DELETE /v1/enrollment-tokens` · `DELETE /v1/devices/:id` · `GET /v1/me`.

**סכמת D1:**
```sql
tenants(id, name, plan, created_at)
users(id, provider, provider_sub, email_hash)      memberships(tenant_id, user_id, role)
enrollment_tokens(id, tenant_id, token_sha256, expires_at, max_devices, used, revoked_at)
devices(id, tenant_id, secret_sha256, hostname, os, last_seen, agent_version)
scans(id, tenant_id, device_id, started_at, schema_version, summary_json)
findings_current(tenant_id, device_id, finding_id, rule_id, severity, first_seen, last_seen, data_json, PRIMARY KEY(tenant_id, device_id, finding_id))
finding_events(tenant_id, device_id, finding_id, event 'added|resolved', at)
-- every index starts with tenant_id
```

**בידוד tenants:** DB אחד עם `tenant_id` בכל טבלה. ה-`tenant_id` נגזר רק מה-session או מה-device credential, ולעולם לא מה-body או מה-URL. כל השאילתות עוברות דרך שכבת repository שמחייבת `tenantId` כפרמטר ראשון. בדיקת אינטגרציה (Miniflare/wrangler dev, מקומי) מוודאת שמשתמש של tenant A מקבל 404 על משאבים של tenant B. ה-ingest מאומת מול אותה JSON Schema, עם גודל מקסימלי של 256KB.

**מגבלות free tier** (לאמת שוב לפני שבוע 3): Workers עם כ-100K requests ליום. D1 עם 5M קריאות ו-100K כתיבות ליום, ו-500MB לכל DB. לכן ה-ingest שומר **diff בלבד** מול `findings_current`, מגביל לסריקה אחת ביום לתחנה, מגביל ל-25 תחנות ב-SaaS Free, ושומר היסטוריה 30 יום (מחיקה ב-Cron Trigger). Rate limiting נעשה לפי device ולפי IP.

## 6. בדיקות ו-CI

- **Pester 5** בגרסה נעולה (`-RequiredVersion 5.6.x`) ו-**PSScriptAnalyzer** עם `PSScriptAnalyzerSettings.psd1`, כולל `PSUseCompatibleSyntax` ו-`PSUseCompatibleCmdlets` מול 5.1. בדיקות עם tags: `Unit`, `Collector`, `Security`, `WindowsOnly`.
- **GitHub Actions** (`footprint-ci.yml`, חינם לריפו ציבורי):
  | Job | Runner | Shell | מה |
  |---|---|---|---|
  | lint | ubuntu-latest | pwsh | PSScriptAnalyzer, `Test-Catalog`, schema של הקטלוג, `Test-GitIgnore` |
  | test-linux | ubuntu-latest | pwsh | כל הבדיקות חוץ מ-`WindowsOnly` (fixtures) |
  | test-win51 | windows-latest | `powershell` (5.1) | הכול, כולל providers אמיתיים (registry, CIM) |
  | test-win7 | windows-latest | `pwsh` | הכול, ובנוסף אימות JSON מול schema עם `Test-Json` ו-artifact של דוח לדוגמה |
- **סוכנים בלי pwsh:** כותבים קוד ובדיקות, פותחים PR ומסתמכים על ה-CI. קוד שאפשר לבדוק בלי PowerShell (סכמות JSON, קטלוג) נבדק גם עם `python3 -m json.tool`. אישור קוד דורש CI ירוק בכל ארבעת ה-jobs.
- **אבטחה:** GitHub secret scanning ו-push protection (חינם לריפו ציבורי), Dependabot ל-actions, ו-actions מוצמדים ל-SHA.

### `.gitignore` — תיקונים נדרשים
הבעיות:
- `*token*` יתעלם מ-`Register-…Token…`, `enrollment-tokens.ts`, `NoTokenLeak.Tests.ps1` ו-`docs/enrollment-token-flow.md`.
- `credentials*` יתעלם מ-fixture של `.aws/credentials` ומ-`credentials.schema.json`.
- `*.key` ו-`.env` חוסמים fixtures.
- `reports/`, `snapshots/` ו-`secrets/` לא מעוגנים, ולכן תופסים כל תיקייה בשם הזה בכל עומק, כולל `tests/fixtures/.../secrets/`. Git **לא יכול** להחזיר עם `!` קובץ שתיקיית האב שלו הוחרגה.
- ב-Windows `core.ignorecase=true`, ולכן `*token*` תופס גם `Token`. ב-Linux הוא לא תופס, והתוצאה היא התנהגות שונה בין מהנדסים.

ההחלפה המוצעת:
```gitignore
# Secrets — never commit (precise, anchored)
/.env
/.env.*
!/.env.example
/secrets/
/credentials*
*.pem
*.pfx
*.p12
*.key
*.token
*.secret
# Local logs / reports (root only)
*.log
*.csv
/reports/
/journal/
/snapshots/
*.authshift.html
*.authshift.json
# AI Footprint outputs
/out/
footprint/out/
aif-report-*.html
aif-scan-*.json
# Fixtures are fake by design; templates hold placeholders, never real secrets
!tests/Fixtures/*.json
!footprint/tests/fixtures/**
```
- fixtures שנראים כמו סודות נשמרים כתבניות (`.env.tmpl`, `fake.key.tmpl`) ומופקים בזמן ריצה, כך שלא צריך להחליש כללים.
- `tools/Test-GitIgnore.ps1` מוודא בכל CI ש-`git ls-files -oi --exclude-standard -- footprint` ריק (חוץ מ-`out/`), ושרשימת נתיבים קנונית לא מוחרגת (`git check-ignore -v`).
- לוודא אחרי השינוי ש-`git status` לא מציג קבצי פלט קיימים של AuthShift.

## 7. פירוק משימות v0.1 (שבועיים, 3 מהנדסים)

| # | משימה | בעלים | תלוי ב- |
|---|---|---|---|
| C1 | שלד מודול, psd1, build, `ScanContext`, `Resolve-AifPath`, providers מזויפים (**יום 1–2, חוסם**) | E1 Core | — |
| C2 | טיפוסי Inventory/Finding, id דטרמיניסטי, `ConvertFrom-JsonC`, `New-AifHmac` | E1 | C1 |
| C3 | `scan-result.v1.schema.json` וכותב JSON (5.1-safe) | E1 | C2 |
| C4 | Orchestrator: רישום collectors, timeout, `errors[]`, `-Include/-Exclude`, `-MachineWide`, `-PrivacyMode` | E1 | C2 |
| K1 | `catalog.schema.json`, `Test-Catalog`, מנוע risk-rules (אופרטורים סגורים) | E2 Collectors | C2 |
| K2 | Apps, Processes, LocalLlm, כולל fixtures של registry, processes ו-listeners | E2 | C1, K1 |
| K3 | McpConfigs (7 clients) ו-CodingAgents (הרשאות מסוכנות) | E2 | K1, S1 (redactor) |
| K4 | BrowserExtensions (Chromium x3, Firefox) ורשימת ~40 כלים בקטלוג | E2 | K1 |
| Q1 | CI skeleton (4 jobs), PSScriptAnalyzer settings, תיקון `.gitignore` ו-`Test-GitIgnore` (**יום 1**) | E3 QA | — |
| S1 | `secret-rules.json`, `Get-SecretMatches`, entropy, redactor לשורות פקודה | E3 | C2 |
| S2 | מחולל fixtures עם סודות בזמן ריצה ו-`NoSecretLeak.Tests` | E3 | S1, C4 |
| R1 | דוח HTML (template, encoding, CSP, נתונים מוטמעים) ובדיקות XSS ו-offline | E3 | C3 |
| I1 | 3 פרופילי fixture מלאים (נקי, מפתח עם MCP מסוכן, machine-wide), בדיקת אינטגרציה end-to-end, README, SECURITY.md | E2 + E3 | K2–K4, S2, R1 |

**נתיב קריטי:** C1 ← C2 ← (K1, S1) ← K3 ← S2 ← I1.

**חוזה יום 1:** E1 ממזג את C1 עם stubs של הטיפוסים, כדי ש-E2 ו-E3 יעבדו במקביל. במקביל E3 ממזג את Q1, כך שכל PR מהיום הראשון נבדק ב-CI.

**הגדרת "סיום" ל-v0.1:** סריקת per-user בלי admin מסתיימת בפחות מ-60 שניות על windows-latest. ה-JSON עובר אימות מול הסכמה. דוח HTML אחד נפתח offline. ארבעת ה-jobs ירוקים. בדיקת הדליפה עוברת.
