# PRD — AI Footprint Scanner (שם עבודה)

**מחבר:** Product Manager · **תאריך:** 2026-10-21 · **סטטוס:** טיוטה לאישור המנכ"ל
**בסיס:** [החלטה 003](../../decisions/003-ai-security-product.md) · [research/ai-security](../../research/ai-security/)

## 1. הבעיה
ארגונים קטנים ובינוניים לא יודעים אילו כלי AI רצים על התחנות שלהם. ה-coding agents ושרתי ה-MCP הם endpoint חדש, עם גישה ל-shell ולסודות. כבר היו תקיפות אמיתיות: postmark-mcp, Nx "s1ngularity", ו-24,008 סודות שנמצאו בקבצי MCP config. הכלים הקיימים לא פותרים את זה ל-SMB:
- **CASB/SSE** רואים רק תעבורת רשת. הם לא רואים MCP שרץ ב-stdio.
- **Snyk Agent Scan** מיועד למפתח בודד, ואין לו תמונת fleet.
- **Defender ו-Intune** דורשים רישוי E5/MDE, ונכון לעכשיו מכסים מעט כלים (Intune ב-preview מזהה רק את OpenClaw).

כל מסגרת רגולציה (EU AI Act, ISO 42001, OWASP ASI, שאלוני ביטוח) מתחילה ממלאי של כלי AI, ומלאי כזה אין לארגונים האלה היום.

**ההבטחה:** תוך 10 דקות, דרך Intune, GPO או הרצה ידנית, האדמין יודע אילו כלי AI, תוספים, שרתי MCP ו-LLMs מקומיים יש על כל תחנה, ואיפה סודות חשופים לסוכן. בלי לקרוא אף prompt.

## 2. Personas ו-JTBD

| Persona | הקשר | JTBD |
|---|---|---|
| **Dana, SMB IT/Intune admin** (50–500 עובדים, M365 Business Premium, בלי E5) | צריכה לענות להנהלה, לשאלון הביטוח או ללקוח: "איזה AI יש אצלנו?" | "כשמגיע אליי שאלון ביטוח או שאלון ספקים, אני רוצה מלאי AI אמין של כל התחנות, כדי לענות בלי לנחש." |
| **Moshe, MSP technician** (מנהל 10–40 לקוחות) | צריך כלי זול שעובד גם בלי Intune, ושאפשר להריץ דרך RMM | "כשאני מצרף לקוח חדש, אני רוצה סריקת AI exposure שאפשר להראות לו, כדי למכור לו שירות hardening." |
| **Avi, security-conscious dev lead** (צוות של 5–30 מפתחים) | הצוות שלו משתמש ב-Claude Code, Cursor ו-Copilot עם MCP servers | "לפני שאני מאשר MCP server חדש, אני רוצה לראות אילו הרשאות וסודות כבר חשופים לסוכנים של הצוות, כדי לסגור את זה לפני שתקיפה כמו s1ngularity תנצל את זה." |

## 3. עקרונות פרטיות (לא נתונים למשא ומתן)
1. **Inventory ו-config בלבד.** לא קוראים prompts, היסטוריית שיחות, clipboard או תוכן קבצים שאינם config. לא מבצעים keylogging ולא לוכדים תעבורה.
2. **סודות מדווחים כ-fingerprint בלבד.** מה שנאסף: סוג הסוד (למשל `github_pat`), מיקום (קובץ ו-JSON path), ו-fingerprint מסוג `hmac-sha256` עם מפתח מקומי לכל התקנה, שנחתך ל-16 תווי hex (מונע השוואה בין ארגונים ו-brute-force לסודות קצרים). הערך עצמו לא נכתב לזיכרון מתמשך, לא ללוג ולא לדוח. ב-SaaS המפתח יהיה ייחודי לכל tenant.
3. **Username redaction mode** (`-RedactUser`). שם המשתמש ונתיבי ה-profile מוחלפים ב-`<USER>` או ב-hash יציב. הדבר נדרש בגרמניה (BetrVG §87) ובארגונים עם ועד עובדים.
4. **Local-first.** ה-Community edition לא שולחת שום דבר לרשת. ב-SaaS כל נתון שנשלח מוגדר ב-JSON schema פומבי.
5. **שקיפות.** קוד פתוח מלא (רישיון OSI), ודגל `-WhatWouldBeCollected` שמדפיס בדיוק מה ייאסף. יחד עם המוצר מסופקות תבנית DPIA ו-transparency notice.
6. **Read-only.** ה-MVP לא משנה שום קובץ ושום הגדרה, ולא חוסם שום דבר.

## 4. היקף לפי מהדורה

| יכולת | Community (OSS) | SaaS Free | Pro (מתוכנן, ~$3–5 לתחנה לחודש, לא נגבה עד אישור הדירקטוריון) |
|---|---|---|---|
| סריקה מקומית, כל ה-detections | ✅ | ✅ | ✅ |
| דוח HTML offline ו-JSON | ✅ | ✅ | ✅ |
| קטלוג פתוח (YAML) שהקהילה מתחזקת | ✅ | ✅ | ✅ |
| Fleet dashboard | — | עד 25 תחנות | ללא הגבלה |
| היסטוריה | — | 7 ימים | 12 חודשים |
| Drift alerts (Teams, Slack, email) | — | — | ✅ |
| Policy (allowlist ל-MCP servers ולאפליקציות) | — | — | ✅ |
| דוחות compliance (ISO 42001, EU AI Act, ביטוח) | — | — | ✅ |
| Multi-tenant ל-MSP | — | — | ✅ |

## 5. Detections (לפי סדר עדיפות)
הדירוג נקבע לפי חומרה, תקריות אמיתיות וקלות המימוש. ה-severity ניתן לשינוי ב-catalog.

| ID | מה | מקור נתונים | Sev | שלב |
|---|---|---|---|---|
| AIS-MCP-001 | Inventory של כל שרתי ה-MCP: client, שם, transport, command או URL | קבצי config (טבלה 5.1) | Info | MVP |
| AIS-SEC-001 | סוד בטקסט גלוי בתוך `env`, `args`, `headers` או `url` של MCP server | קבצי MCP config, עם regex ו-entropy (`sk-`, `sk-ant-`, `ghp_`, `github_pat_`, `xox[bp]-`, `AKIA`, `AIza`) | High | MVP |
| AIS-PERM-001 | Claude Code במצב `bypassPermissions`, או allow גורף (`Bash`, `Bash(*)`) | `~/.claude/settings.json`, `.claude/settings*.json` | High | MVP |
| AIS-PERM-002 | Agent שרץ עם דגל לדילוג על אישורים: `--dangerously-skip-permissions`, `--yolo`, `--full-auto` וכדומה | `Win32_Process.CommandLine` | High | MVP |
| AIS-LLM-001 | LLM runtime מקומי שמאזין על כתובת שאינה loopback (Ollama 11434, LM Studio 1234) | `Get-NetTCPConnection -State Listen` ו-owning process | High | MVP |
| AIS-MCP-002 | MCP server שמורץ דרך `npx` או `uvx` בלי גרסה נעולה (`pkg@latest` או בלי `@x.y.z`) | `command` ו-`args` | Medium | MVP |
| AIS-MCP-003 | MCP server עם גישה ל-shell או ל-filesystem רחב (למשל `server-filesystem` עם `C:\` או `~`) | `args` מול רשימה בקטלוג | Medium | MVP |
| AIS-MCP-004 | Remote MCP (http/sse) שנגיש ב-`http://` לא מוצפן, או לדומיין שאינו בקטלוג | שדה `url` | Medium | MVP |
| AIS-APP-001 | אפליקציות AI מותקנות (קטלוג של ~40 כלים, כולל התקנות per-user ב-AppData) | `HKLM`/`HKCU\...\Uninstall`, `Get-AppxPackage`, `%LOCALAPPDATA%\Programs` | Info | MVP |
| AIS-AGT-001 | Coding agents ו-CLI agents: Claude Code, Cursor, Copilot, Gemini CLI, Windsurf, Codex CLI ועוד | קבצים ותיקיות ב-profile, npm global (`%APPDATA%\npm`), extensions של VS Code | Info | MVP |
| AIS-EXT-001 | תוספי דפדפן של AI | `manifest.json` תחת `User Data\*\Extensions` ב-Chrome, Edge ו-Brave | Info | MVP |
| AIS-EXT-002 | תוסף AI עם הרשאות רחבות (`<all_urls>`, `webRequest`, `clipboardRead`) | `manifest.json` | Medium | MVP |
| AIS-ID-001 | Agent שרץ בהקשר elevated או תחת חשבון שחבר ב-local Administrators | token של התהליך, `Get-LocalGroupMember` | High | MVP |
| AIS-SEC-002 | קבצי `.env` או credentials בתוך תיקיית פרויקט שיש בה config של agent | סריקה מוגבלת לעומק 2 מה-roots של הפרויקטים שנמצאו ב-`~/.claude.json` | Medium | v0.2 |
| AIS-PERM-003 | Auto-approve גלובלי ב-VS Code (`chat.tools.autoApprove`), Gemini `autoAccept`/YOLO, ו-Codex `approval_policy="never"` | קבצי settings (needs verification) | High | v0.2 |
| AIS-MCP-005 | MCP server שנוסף או שונה מאז הסריקה הקודמת (drift) | השוואה ל-JSON הקודם | Medium | v0.2 (מקומי), v0.3 (התראה) |
| AIS-MCP-006 | Hash של ה-config לזיהוי tool poisoning ושינוי בקטלוג | hash של בלוק השרת | Low | v0.3 |
| AIS-ID-002 | Agent שרץ תחת חשבון AD עם הרשאות מועדפות (Domain Admins ודומיה) | בדיקת קבוצות ב-AD (אופציונלי, דורש RSAT/LDAP) | Critical | v1.0 |
| AIS-NET-001 | Snapshot של יעדי DNS של שירותי AI | `Get-DnsClientCache` | Info | later |
| AIS-MAC-* | אותן בדיקות ב-macOS (script) | `~/Library/Application Support/...` | — | v1.0 |

### 5.1 מיקומי MCP config (Windows)
"מתועד" = מופיע במקור שצוטט במחקר 03 [14]. **אף נתיב עוד לא נבדק בפועל על מכונה.** בדיקת fixtures על Windows אמיתי היא חלק מתנאי הקבלה.

| Client | נתיב | Root key | סטטוס |
|---|---|---|---|
| Claude Desktop | `%APPDATA%\Claude\claude_desktop_config.json` | `mcpServers` | מתועד |
| Claude Code (user/local) | `%USERPROFILE%\.claude.json`, כולל `projects.<path>.mcpServers` | `mcpServers` | מתועד |
| Claude Code (project) | `<repo>\.mcp.json` | `mcpServers` | מתועד |
| Claude Code (managed) | `C:\Program Files\ClaudeCode\managed-mcp.json` (או `C:\ProgramData\ClaudeCode\`) | `mcpServers` | needs verification |
| Cursor (global / project) | `%USERPROFILE%\.cursor\mcp.json` · `<repo>\.cursor\mcp.json` | `mcpServers` | מתועד |
| VS Code / GitHub Copilot (workspace) | `<repo>\.vscode\mcp.json` | `servers` | מתועד |
| VS Code / Copilot (user) | `%APPDATA%\Code\User\mcp.json`, או המפתח `mcp` ב-`settings.json` | `servers` | needs verification |
| Windsurf | `%USERPROFILE%\.codeium\windsurf\mcp_config.json` | `mcpServers` | needs verification |
| Gemini CLI | `%USERPROFILE%\.gemini\settings.json` · `<repo>\.gemini\settings.json` | `mcpServers` | needs verification |
| OpenAI Codex CLI | `%USERPROFILE%\.codex\config.toml` (TOML) | `[mcp_servers.*]` | needs verification |
| Cline (VS Code ext.) | `%APPDATA%\Code\User\globalStorage\saoudrizwan.claude-dev\settings\cline_mcp_settings.json` | `mcpServers` | needs verification |
| Continue | `%USERPROFILE%\.continue\config.yaml` · `.continue\mcpServers\` | `mcpServers` | needs verification |
| Zed | `%APPDATA%\Zed\settings.json` | `context_servers` | needs verification |
| Amazon Q Developer | `%USERPROFILE%\.aws\amazonq\mcp.json` | `mcpServers` | needs verification |

**איך מוצאים project roots:** מתוך המפתחות של `projects` ב-`~/.claude.json`, ה-recent workspaces של VS Code ו-Cursor (needs verification), ונתיבים שהאדמין מגדיר בפרמטר `-ProjectRoots`. לא סורקים את כל הדיסק.

המיפוי נשמר ב-`catalog/clients.yaml` כדי שהקהילה תוכל לעדכן אותו ב-PR בלי לגעת בקוד.

## 6. דרישות דוח
- **JSON** (`aif-report.json`): מאומת מול JSON Schema פומבי ב-`schema/report.v1.json`. השדה `schemaVersion: "1.0.0"` עובד לפי SemVer: שינוי שובר מעלה את ה-major, ושדות חדשים מעלים את ה-minor. מבנה: `scanner{version}`, `device{hostnameHash|hostname, os, scanTime}`, `user{redacted}`, `inventory{apps[], agents[], extensions[], mcpServers[], runtimes[]}`, `findings[{id, severity, title, evidence{path, jsonPath, fingerprint}, remediation, references[OWASP ASI]}]`, `summary{counts by severity}`.
- **HTML** (`aif-report.html`): קובץ יחיד שכל ה-CSS וה-JS שלו inline. עובד offline, בלי CDN ובלי בקשות רשת (נבדק ב-CSP `default-src 'none'`). כולל סיכום מנהלים, findings לפי חומרה, הוראות remediation לכל ID, טבלאות inventory וחותמת זמן. נפתח בדפדפן בלי שום התקנה.
- **Guardrail:** בדיקת CI מוודאת שאף ערך שנראה כמו סוד לא מופיע בפלט (canary secrets ב-fixtures).
- **Exit codes:** `0` אין findings מעל ה-threshold · `1` יש findings · `2` שגיאה. כך אפשר להשתמש בסורק ב-Intune Remediation detection.

## 7. מדדי הצלחה (נמדדים ב-GitHub בלבד)

| מדד | מקור | יעד 14 יום | יעד 90 יום |
|---|---|---|---|
| Stars | GitHub API | **≥30 (קריטריון עצירה)** | ≥300 |
| Downloads (release assets + clones) | Releases API, Traffic | **≥100 (קריטריון עצירה)** | ≥1,000 |
| Issues/Discussions מגורמים חיצוניים | GitHub | ≥5 | ≥30 |
| PRs חיצוניים ל-catalog | GitHub | ≥1 | ≥10 |
| Forks | GitHub | ≥5 | ≥40 |

**קריטריון עצירה:** אם 14 יום אחרי release v0.1 אין לפחות 30 כוכבים **וגם** לפחות 100 הורדות, חוזרים לדירקטוריון. Traffic נשמר רק 14 יום, ולכן מריצים snapshot יומי ב-GitHub Action ל-`metrics/` (מספרים מצטברים בלבד, בלי נתונים אישיים).

## 8. תנאי קבלה ל-MVP (v0.1)
1. `Invoke-AIFootprintScan` רץ על Windows 10/11 ב-PowerShell 5.1 וב-7.x, בלי admin. כשיש admin, הוא מוסיף נתונים מעבר לפרופיל של המשתמש הנוכחי.
2. כל ה-detections שמסומנים MVP מזוהים נכון על fixtures. יש לפחות 3 fixtures לכל ID: חיובי, שלילי ו-edge.
3. Parser ל-MCP config של לפחות 7 clients: Claude Desktop, Claude Code, Cursor, VS Code/Copilot, Windsurf, Gemini CLI ו-Codex. כל הנתיבים ב-5.1 שנבדקו על Windows אמיתי מסומנים "verified" בקטלוג.
4. אפס ערכי סודות בפלט, בלוגים וב-transcript (נבדק ב-CI עם canaries).
5. `-RedactUser` מסיר כל מופע של שם המשתמש ושל ה-profile path מה-HTML ומה-JSON.
6. JSON עובר validation מול `report.v1.json`. HTML נפתח offline בלי שום בקשת רשת.
7. סריקה טיפוסית מסתיימת תוך 60 שניות או פחות.
8. אין תעבורת רשת יוצאת (נבדק בבדיקה עם firewall חסום).
9. README באנגלית, quickstart בשורה אחת, דוח לדוגמה, תבנית DPIA ו-`SECURITY.md`.
10. Pester tests ירוקים ב-GitHub Actions (windows-latest). ה-script עובר PSScriptAnalyzer בלי errors.

## 9. מחוץ להיקף
חסימה או אכיפה, ניטור prompts, DLP, proxy, kernel driver, Copilot oversharing, וגביית תשלום.
