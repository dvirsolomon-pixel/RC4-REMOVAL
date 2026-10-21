# 03: כאבי לקוחות והיתכנות טכנית (AI Security)

**אנליסט:** Customer Pain & Technical Feasibility · **תאריך:** 2026-10-21 · **בסיס:** החלטה 002
**הערה:** רוב הנתונים כאן מגיעים מסקרים של ספקים וממקורות משניים, ולכן צריך להתייחס אליהם כאל אינדיקציה בלבד. מקור לכל טענה מופיע בסוף הדוח.

---

## 1. כאבי לקוחות אמיתיים (2025–2026)

### א. Shadow AI ודליפת מידע לכלי AI
- לפי TELUS Digital (ינואר 2025), **57%** מהעובדים בחברות גדולות בארה"ב הזינו מידע חסוי ל-ChatGPT, Gemini או Copilot [1].
- לפי BlackFog/Sapio (נובמבר 2025), **49%** משתמשים בכלי AI שהמעסיק לא אישר, ו-**34%** משתמשים בגרסה החינמית של כלי שכן אושר [1].
- לפי IBM Cost of a Data Breach 2025, בערך **אחד מכל חמישה** ארגונים דיווח על פריצה שקשורה ל-shadow AI. פריצות כאלה הוסיפו בממוצע כ-**$670K** לעלות, והנתונים שנחשפו בהן היו בעיקר PII (65%) ו-IP (40%) [2].
- לפי Pentera 2026 (300 CISOs), **אף CISO לא דיווח על נראות מלאה** לשימוש ב-AI בארגון, ו-66% דיווחו על נראות מוגבלת [3].

### ב. תוספי דפדפן ואפליקציות AI לא מאושרות
- בינואר 2026 נחשפו שני תוספי Chrome עם כ-**900K משתמשים** שהתחזו ל-AI sidebar. הם גנבו שיחות ChatGPT ו-DeepSeek וגם כתובות URL פנימיות. התופעה קיבלה את השם "Prompt Poaching" [4].
- אפליקציות AI לשולחן העבודה מותקנות לעיתים קרובות per-user ב-AppData (התקנות Squirrel), ולכן **לא נראות בזיהוי הרגיל של Intune** [5].

### ג. Coding agents, שרתי MCP וסודות
- **postmark-mcp** (ספטמבר 2025) נחשב לשרת ה-MCP הזדוני הראשון שנמצא in-the-wild. החבילה ב-npm הוסיפה BCC לכל מייל שנשלח דרכה, והגיעה לכ-1,500 הורדות בשבוע [6].
- **Nx "s1ngularity"** (אוגוסט 2025) הייתה תקיפת שרשרת אספקה שהפעילה את Claude Code, Gemini CLI ו-Amazon Q שהיו מותקנים מקומית, עם דגלים שמדלגים על בקשות האישור, כדי לאתר סודות ולגנוב אותם. נגנבו בה יותר מ-2,000 סודות מאומתים [7].
- לפי GitGuardian (State of Secrets Sprawl 2026), נמצאו **24,008 סודות ייחודיים** בקבצי תצורה של MCP. מספר הדליפות שקשורות לשירותי AI עלה ב-**81%** בשנה. הסיבה העיקרית היא שתיעוד של שרתי MCP ממליץ לשים מפתחות API ישירות ב-`mcp.json` [8].
- לפי סריקות של Censys ו-LeakIX, בין **12K ל-21K** שרתי Ollama חשופים לאינטרנט בלי אימות (פורט 11434) [9].

### ד. Copilot ו-Prompt Injection
- **EchoLeak** (CVE-2025-32711, CVSS 9.3) הייתה חולשת zero-click ב-M365 Copilot: מייל אחד שנבנה במיוחד הספיק כדי להוציא מידע מהארגון [10].
- **Oversharing:** לפי Concentric AI, כ-16% מהמידע הקריטי בטננט M365 ממוצע משותף יותר מדי. Copilot מציף את מה שהמשתמש כבר יכול לגשת אליו, כמו הקבוצה EEEU, הורשת הרשאות שבורה וקישורים אנונימיים. הבעיה היא בהרשאות ולא ב-AI עצמו [11].

### מה חסר ל-SMB ול-mid-market
1. **נראות זולה.** הגילוי של Defender for Cloud Apps דורש Business Premium או E3/E5 יחד עם onboarding ל-MDE [12]. הרבה SMB לא נמצאים שם.
2. **נראות לשכבת ה-agent ו-MCP.** פתרונות CASB ו-SSE רואים תעבורה ל-chatgpt.com, אבל לא רואים איזה MCP server רץ מקומית, עם איזה token, ועם גישה ל-shell.
3. **הכלי של Microsoft עדיין צר.** ביוני 2026 Intune הוסיף זיהוי של "Local AI Agent" ב-preview, אבל הוא מכסה **רק את OpenClaw** [13]. מצד אחד זה מאשר שהבעיה אמיתית ושהקונה הוא אדמין Intune. מצד שני זה איום: Microsoft עלולה להרחיב את הכיסוי.
4. **מדיניות בלי אכיפה.** לפי ESET 2026, ל-69% מה-SMB יש מדיניות נגד shadow AI [3b], אבל אין להם כלי שבודק אם היא נאכפת בפועל.

---

## 2. היתכנות טכנית של agent מקומי

### מה אפשר לראות (Windows, user-mode, בלי driver)
| אות | מקור | מורכבות |
|---|---|---|
| אפליקציות AI מותקנות (ChatGPT, Claude, Cursor, Windsurf, LM Studio, Ollama) | `HKLM/HKCU\...\Uninstall`, `Get-AppxPackage` (MSIX), סריקת `%LOCALAPPDATA%\Programs` | נמוכה |
| תוספי דפדפן | `%LOCALAPPDATA%\Google\Chrome\User Data\*\Extensions\*\manifest.json`, ואותו דבר ב-Edge ו-Brave. Firefox: `extensions.json` | נמוכה |
| קבצי MCP config | `%APPDATA%\Claude\claude_desktop_config.json`, `~/.cursor/mcp.json`, `.vscode/mcp.json` (root key `servers`), `~/.claude.json`, `.mcp.json` ברמת הפרויקט, `~/.codeium/windsurf/mcp_config.json`, `~/.gemini/settings.json` [14] | נמוכה. צריך לתחזק מפת נתיבים |
| סודות ב-configs | regex/entropy על `env` ו-`args` (תבניות כמו `sk-`, `ghp_`, `xoxb-`, `AKIA`). **מדווחים רק fingerprint או hash ואת סוג הסוד, אף פעם לא את הערך עצמו** | בינונית |
| ניתוח סיכון של שרת MCP | `command` (npx/uvx עם גרסה לא נעולה), חבילה מ-registry, הרשאות fs/shell | בינונית |
| תהליכים פעילים | `Get-CimInstance Win32_Process` (שורת הפקודה של node, python, ollama) | נמוכה |
| LLM runtimes מקומיים | האזנה על 11434 (Ollama) או 1234 (LM Studio), והאם ה-bind הוא ל-`0.0.0.0` | נמוכה |
| יעדי DNS ל-AI | DNS Client ETW, או `Get-DnsClientCache` כ-snapshot | בינונית. ETW דורש הרשאות admin/service |

**macOS (שלב 2):** אותם נתיבים תחת `~/Library/Application Support/`, ובנוסף `/Applications` ו-`launchctl`. לא צריך Full Disk Access אם קוראים רק בתוך ה-home של המשתמש. נדרשים notarization ו-Apple Developer ID שעולה $99 לשנה, וזה מתנגש עם תקציב 0. לכן ב-macOS נתחיל עם script או CLI שמופץ דרך brew tap.

### פרטיות וחוק
- **בלי תוכן.** לא קוראים prompts, לא לוכדים clipboard ולא מבצעים keylogging. אוספים inventory ותצורה בלבד, וכך מצמצמים מאוד את הסיכון בעיני GDPR.
- הבסיס החוקי הוא legitimate interest (Art. 6(1)(f)) עם LIA. **הסכמה של עובד אינה בסיס תקף**, בגלל פערי הכוחות (EDPB Opinion 2/2017) [15]. נספק ללקוח תבנית DPIA ו-transparency notice.
- בגרמניה ובמדינות דומות יש זכות codetermination של ועד העובדים (§87(1)6 BetrVG). מצב "privacy mode" שמסיר את שם המשתמש ושומר רק את שם המחשב יקל על ההטמעה שם.
- ה-agent ייבנה open-source כדי שאפשר יהיה לבדוק בדיוק מה הוא אוסף. זה יתרון ממשי באמון.

### Code signing ופריסה
- **SignPath Foundation** נותן חתימה חינמית לפרויקטי OSS עם רישיון OSI. הבנייה חייבת לרוץ ב-CI ציבורי, והחותם הרשום הוא SignPath [16]. **Azure Artifact Signing** בתשלום, וזמין רק לארגונים בארה"ב, קנדה, EU ו-UK [16].
- **הפריסה מתאימה בדיוק ליכולות של המייסד:** Intune Platform Script או Remediation (PowerShell) עם scheduled task, GPO Startup Script, או SCCM. גרסה 0 תהיה **מודול PowerShell חתום**, בלי binary ובלי service. כך עוקפים כמעט את כל חסמי ה-AV וה-EDR וחוסכים את הצורך ב-installer.

---

## 3. ארכיטקטורת SaaS בתקציב 0

| אפשרות | Free tier | הערות |
|---|---|---|
| **Cloudflare Workers + D1** | כ-100K requests ביום, D1: 5M rows read ו-100K rows written ביום, 5GB [17] | לא נרדם, edge גלובלי. **ההמלצה** |
| Supabase | DB של 500MB, 50K MAU, **הפרויקט מושהה אחרי שבוע בלי פעילות** [18] | Auth מובנה, אבל ההשהיה מסוכנת ל-SaaS |
| Vercel Hobby | אסור לשימוש מסחרי | מתאים לדמו בלבד |
| GitHub Pages | סטטי בלבד | לאתר שיווקי ולתיעוד |

**חישוב קיבולת:** endpoint ששולח report אחד ביום (diff בלבד) מייצר בערך 5 עד 20 שורות. כלומר 100K writes ביום מספיקים ל**כ-5,000 תחנות**, וזה יותר מדי לשלב ה-MVP.

**עיצוב מינימלי:**
```
[PowerShell agent (OSS, signed)] --HTTPS POST JSON (tenant token)--> [CF Worker /ingest]
                                                                         |
                                                    [D1: tenants, devices, findings]
[Dashboard: static SPA on CF Pages] <--- [CF Worker /api] (auth: GitHub/Entra OIDC, magic link)
```
- **Offline-first:** ה-agent עובד גם בלי SaaS, ויודע להפיק דוח HTML או JSON מקומי. כך יש לו ערך גם כ-OSS עצמאי ומשמש כ-funnel ל-SaaS.
- **מודל אבטחה:** token נפרד לכל tenant עם הרשאת write בלבד, rate-limit לכל device, בלי סודות ב-payload (hash בלבד), ו-JSON Schema validation.

---

## 4. ה-MVP המומלץ: "AI Footprint & MCP Exposure Scanner"

**הבטחה:** תוך 10 דקות דרך Intune או GPO, האדמין רואה אילו כלי AI, תוספים, שרתי MCP ו-local LLMs רצים בארגון, ואיפה יש סודות חשופים, בלי לקרוא אף prompt.

**למה דווקא זה:**
- **כאב:** אין נראות, MCP ו-coding agents הם וקטור תקיפה חדש עם תקריות אמיתיות, ויש secrets sprawl.
- **היתכנות:** קריאת קבצים ו-registry בלבד, ב-user-mode, בלי driver ובלי proxy.
- **התאמה למייסד:** PowerShell, Intune, GPO ו-AD. הקונה הוא אדמין Windows, שזה הקהל שהמייסד מכיר.
- **פער:** Intune מזהה רק את OpenClaw. ‏mcp-scan של Snyk/Invariant הוא כלי למפתח בודד ולא מתאים ל-fleet [19]. CASBs לא מגיעים לשכבת ה-MCP המקומית.

**היקף ל-4 עד 6 שבועות:**
| שבוע | תוצר |
|---|---|
| 1 | מודול PowerShell: inventory של אפליקציות AI (קטלוג YAML פתוח של כ-40 כלים), תוספי דפדפן מול רשימת AI ידועה, פלט JSON ו-HTML מקומי |
| 2 | Parser ל-MCP configs (7 clients) וזיהוי סודות (redacted), כללי סיכון: גרסה לא נעולה, shell או fs, חבילה לא מוכרת, Ollama על 0.0.0.0 |
| 3 | CF Worker ingest, D1 schema ו-tenant tokens. Dashboard סטטי: devices, findings וחומרה |
| 4 | חבילות פריסה: Intune Remediation, GPO ו-scheduled task. חתימה דרך SignPath, ו-README עם תבנית DPIA |
| 5–6 | Pilot עם 3 עד 5 אדמינים מהקהילה (r/sysadmin, r/Intune, MVPs). ‏diff ו-alert ל-Teams או Slack webhook. גרסת macOS ב-bash או zsh (קריאה בלבד) |

**מחוץ להיקף:** חסימה או אכיפה, ניטור תוכן, DLP, proxy, kernel driver ו-Copilot oversharing (זה כבר מוצר M365 נפרד שמתאים כהמשך).

**סיכונים:**
1. Microsoft עלולה להרחיב את Local AI Agent inventory. **מענה:** להתמקד בעומק MCP וסודות, ולתמוך גם בסביבות שאינן Intune.
2. מפת הנתיבים משתנה מהר. **מענה:** קטלוג פתוח שהקהילה מעדכנת ב-PRs.
3. בלי binary חתום, EDR עלול לחסום סקריפטים. **מענה:** חתימת PowerShell, ובהמשך SignPath.

---

## מקורות
1. TELUS, Cybernews, Josys ו-BlackFog, מתוך: https://www.cio.com/article/4124760/roughly-half-of-employees-are-using-unsanctioned-ai-tools-and-enterprise-leaders-are-major-culprits.html ; https://itbrief.com.au/story/one-in-three-australians-upload-sensitive-data-to-ai-tools-report-finds ; https://cxm.world/cxm-news/office-workers-are-leaking-sensitive-data-into-ai-and-they-dont-even-care/
2. https://www.techrepublic.com/article/news-ai-breach-risks-rise-as-governance-lags/ ; https://www.aryaka.com/blog/ibm-2025-cost-of-a-data-breach-how-ai-and-shadow-ai-shape-cybersecurity/
3. https://www.kiteworks.com/cybersecurity-risk-management/ai-visibility-governance-problem/ ; 3b: https://www.eset.com/us/business/smb-cyber-readiness-index/
4. https://thehackernews.com/2026/01/two-chrome-extensions-caught-stealing.html ; https://www.ox.security/blog/malicious-chrome-extensions-steal-chatgpt-deepseek-conversations
5. https://github.com/dave-jonas/ClaudeDesktop ; https://downloads.claude.ai/releases/enterprise/intune/Claude-Intune-README.md
6. https://snyk.io/blog/malicious-mcp-server-on-npm-postmark-mcp-harvests-emails/
7. https://www.wiz.io/blog/s1ngularitys-aftermath ; https://blog.gitguardian.com/the-nx-s1ngularity-attack-inside-the-credential-leak/
8. https://hackernoon.com/gitguardian-reports-an-81percent-surge-of-ai-service-leaks-as-29m-secrets-hit-public-github ; https://www.techradar.com/pro/security/over-29-million-secrets-were-leaked-on-github-in-2025-and-ai-really-isnt-helping
9. https://censys.com/blog/ollama-drama-investigating-the-prevalence-of-ollama-open-instances-with-censys ; https://blog.leakix.net/2026/02/ollama-exposed/
10. https://thehackernews.com/2025/06/zero-click-ai-vulnerability-exposes.html ; https://arxiv.org/html/2509.10540v1
11. https://petri.com/copilot-didnt-overshare-your-data-your-permissions-did/ ; https://learn.microsoft.com/sharepoint/get-ready-copilot-sharepoint-advanced-management
12. https://tminus365.com/detecting-shadow-ai-in-your-organization/ ; https://sharegate.com/blog/how-to-tackle-shadow-ai-with-microsoft-purview-and-defender-for-cloud-apps
13. https://learn.microsoft.com/intune/device-configuration/collect-device-properties ; https://learn.microsoft.com/intune/device-security/security-baselines/ref-openclaw-settings
14. https://inventivehq.com/knowledge-base/claude/where-configuration-files-are-stored ; https://buildtolaunch.substack.com/p/mcp-setup-claude-chatgpt-vscode-cursor (את הנתיבים של Windsurf ו-Gemini CLI צריך עוד לאמת)
15. https://gdprlocal.com/gdpr-employee-monitoring/ ; https://secureprivacy.ai/blog/employee-monitoring-gdpr-guide
16. https://signpath.org/ ; https://about.signpath.io/product/open-source ; https://zenn.dev/shm_7ec/articles/signpath-oss-code-signing
17. https://developers.cloudflare.com/d1/platform/limits ; https://developers.cloudflare.com/workers/platform/pricing/
18. https://supabase.com/pricing
19. https://invariantlabs.ai/blog/introducing-mcp-scan ; https://labs.snyk.io/resources/detect-tool-poisoning-mcp-server-security/
