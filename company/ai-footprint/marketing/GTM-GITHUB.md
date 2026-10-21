# תוכנית Go-To-Market ב-GitHub בלבד (תקציב 0): AI Stocktake

**מאת:** מנהל השיווק · **תאריך:** 2026-10-21 · **סטטוס:** טיוטה לאישור המנכ"ל
**מבוסס על:** [החלטה 003](../../decisions/003-ai-security-product.md), `research/ai-security/01–03`, [`NAMING.md`](NAMING.md)
**שם המוצר בתוכנית:** AI Stocktake (לפי ההמלצה ב-`NAMING.md`). אם יוחלט אחרת, מחליפים את המחרוזת.

**מגבלות הדירקטוריון שהתוכנית בנויה סביבן:**
- תקציב 0.
- GitHub הוא הערוץ הפומבי **היחיד**: בלי רשתות חברתיות, בלי Reddit, בלי דומיין בתשלום ובלי פרסום.
- שום פרט על המייסד מעבר ל-handle `dvirsolomon-pixel`.
- בלי המלצות, לוגואים או נתונים מומצאים. כל תקרית שאנחנו מזכירים חייבת להיות אמיתית ועם קישור.

> **הערה על פיילוט:** `03-pain-feasibility.md` הציע פיילוט עם אדמינים מ-r/sysadmin ו-r/Intune. זה **לא אפשרי** תחת המגבלות. הפיילוט ייעשה רק עם מי שמגיע אלינו דרך GitHub (Discussions ו-Issues).

---

## 0. העיקרון

ל-GitHub יש ארבעה תפקידים בשבילנו, וכולם בחינם:
1. **חלון ראווה:** ה-README ודף ה-Pages (`*.github.io`, בחינם) הם דף המוצר.
2. **מנוע חיפוש:** Google מאנדקס היטב את GitHub ואת GitHub Pages. אדמינים מחפשים שאלות מדויקות ("where does Claude Code store MCP config", "detect Cursor installed Intune"). אם נכתוב את התשובה הכי טובה לשאלה הזו, הם יגיעו אלינו.
3. **CRM:** כוכב = עניין. Watch → Releases = רשימת המתנה. Discussions = שיחה עם לקוחות. Issues = כאבים אמיתיים.
4. **מנוע צמיחה:** **הקטלוג הפתוח** של כלי AI (ראו §6). כל PR שמוסיף כלי משפר את המוצר, מביא תורם חדש, ומייצר דף חדש שגוגל מאנדקס.

**המסר המרכזי:**
> *See what AI is running on your company's Windows machines (apps, browser extensions, coding agents, MCP servers, risky permissions, reachable secrets) in one offline HTML report. Free, open source, never reads prompts.*

**הבידול בשלוש נקודות** (לפי `02-competitors.md`):
- **Endpoint, לא רק דפדפן.** כלי ה-SMB הזולים (Nudge, Shadow AI Detector) רואים SaaS ודפדפן בלבד. אנחנו רואים CLI agents, שרתי MCP מקומיים ו-Ollama.
- **Fleet, לא מפתח בודד.** Snyk Agent Scan ו-SkillSpector סורקים מחשב אחד. אנחנו בנויים לפריסה דרך Intune ו-GPO.
- **בלי E5 ובלי אנשי מכירות.** Defender for Endpoint דורש רישוי MDE. המובילים (Harmonic וכו') מוכרים רק דרך דמו. אצלנו מורידים ומריצים.

**מה לא אומרים** (כדי לא להטעות): לא "מגן", לא "חוסם", לא "מונע דליפות" ולא "תואם EU AI Act". אומרים "inventory", "visibility", "evidence for your AI inventory". כתוב מפורש שזה לא DLP ולא EDR.

---

## 1. מיצוב הריפו

### שם הריפו
`ai-stocktake` (ראו `NAMING.md`). עד שהמנכ"ל יחליט על שינוי שם, דף הנחיתה מפנה ל-`dvirsolomon-pixel/RC4-REMOVAL`. GitHub מפנה אוטומטית אחרי שינוי שם.

### תיאור הריפו (About → Description, עד 350 תווים)
```
AI Stocktake: free, open-source PowerShell agent that inventories the AI on your Windows endpoints: AI apps, browser extensions, coding agents (Claude Code, Cursor, Copilot, Gemini CLI), MCP servers, risky agent permissions, reachable secrets (hashed, never collected) and exposed local LLMs. Offline HTML report. Intune/GPO ready.
```

### Website (About → Website)
`https://dvirsolomon-pixel.github.io/<repo>/`. דף הנחיתה נמצא ב-`company/ai-footprint/marketing/landing/index.html`.
**שימו לב:** התיקייה `docs/` מכילה היום את דף הנחיתה של AuthShift (מוקפא), ואסור לנו לגעת בה. האפשרויות: (א) לפרסם Pages מענף `gh-pages` שמכיל רק את דף הנחיתה החדש, או (ב) לפרסם מריפו `ai-stocktake` חדש. ההחלטה אצל המנכ"ל.

### Topics (עד 20, אותיות קטנות ומקפים)
```
shadow-ai, ai-inventory, ai-governance, mcp, mcp-security, model-context-protocol,
claude-code, cursor, github-copilot, ai-agents, agent-security, secrets-detection,
intune, powershell, windows, endpoint-security, sysadmin, msp, ollama, blue-team
```
**למה:** לכל Topic יש דף גילוי ב-GitHub (`github.com/topics/mcp-security` וכו'). כש-`mcp-security` ו-`shadow-ai` צעירים יחסית, קל יותר להופיע בעמוד הראשון שלהם.

### Social preview (Settings → Social preview)
תמונה 1280×640: שם המוצר, הסלוגן *"Take stock of the AI on every Windows machine"*, וצילום מסך של דוח HTML **לדוגמה** (מנתוני מעבדה, מסומן "sample report"). כך נראה הקישור כשמשתפים אותו בכל מקום, כולל Slack ו-Teams פנימיים של לקוחות.

---

## 2. מבנה ה-README

ה-README הוא דף המכירה. **כלל:** תוך 10 שניות הקורא מבין מה זה, תוך דקה הוא מריץ.

1. **כותרת + שורה אחת:** *"AI Stocktake: see what AI is running on your Windows fleet."* Badges אמיתיים בלבד: license, latest release, CI build. בלי badges של "downloads" עד שיש מספרים.
2. **GIF או צילום מסך של הדוח** (נתוני מעבדה, מסומן sample).
3. **Quick start בשלוש שורות:**
   ```powershell
   # Download the signed module from the latest Release, then:
   Import-Module .\AIStocktake.psd1
   Invoke-AIStocktake -OutputPath .\ai-stocktake-report.html
   ```
4. **What it finds:** טבלה עם 7 קטגוריות (אפליקציות, תוספים, coding agents, MCP servers, הרשאות מסוכנות, סודות בהישג יד, LLMs מקומיים חשופים) ודוגמה לכל ממצא.
5. **Privacy: what it never collects.** רשימה מפורשת: prompts, תוכן קבצים, היסטוריית דפדפן, ערכי סודות (רק סוג הסוד + fingerprint חד-כיווני), הקלדות, clipboard. **מצב privacy** שמסתיר שמות משתמשים. קישור ל-`PRIVACY.md` ולתבנית DPIA.
6. **Why this matters:** 3 תקריות אמיתיות עם קישורים (postmark-mcp, Nx s1ngularity, GitGuardian 24,008 סודות בקבצי MCP). בלי סטטיסטיקות מסקרי ספקים.
7. **Deploy at scale:** Intune Remediation, Intune Platform Script, GPO Startup Script, scheduled task. קישורים למדריכים ב-`docs/deploy/`.
8. **Supported tools:** קישור ל-`catalog/` ולמונה אוטומטי ("N tools in catalog"). **"Missing a tool? Add it in 5 minutes →"** (תבנית issue או PR).
9. **Roadmap:** Community (עכשיו) · Cloud fleet dashboard (בקרוב) · Pro (מתוכנן). קישור ל-Discussion "Fleet dashboard waitlist".
10. **How it compares:** טבלה הוגנת מול Snyk Agent Scan, Defender for Endpoint ו-Intune Local AI Agent inventory: מה הם עושים טוב ומה אנחנו מוסיפים. בלי השמצות.
11. **Contributing · Security policy · License.**

**קבצים נלווים:** `PRIVACY.md`, `SECURITY.md` (דיווח חולשות דרך GitHub Private Vulnerability Reporting), `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `LICENSE` (רישיון OSI, נדרש עבור SignPath Foundation), ‏`docs/dpia-template.md`.

---

## 3. Releases

- **גרסאות SemVer.** הגרסה הראשונה היא `v0.1.0`, וכתוב בה במפורש "preview".
- **בכל Release:**
  - קובץ ZIP של המודול החתום (`AIStocktake-<ver>.zip`) + קובץ `SHA256SUMS`.
  - דוח **לדוגמה** (`sample-report.html`) שמראה ממצאים מנתוני מעבדה, בלי צורך להריץ כלום.
  - Release notes בשלושה חלקים: *New detections* (כלים חדשים בקטלוג, עם קרדיט לתורמים לפי handle), *Fixes*, *Breaking changes*.
- **קצב:** Release קטן כל שבוע בשבועיים הראשונים, ואחר כך כל שבועיים. כל Release שולח התראה לכל מי שעשה Watch → Releases, ולכן זה ה"ניוזלטר" שלנו.
- **חשוב למדידה:** ה-ZIP ב-Releases הוא **מונה ההורדות** של קריטריון העצירה (`download_count` ב-API). לכן ה-Quick start מפנה ל-Release, לא ל-`git clone`.
- **חתימה:** SignPath Foundation (חינם ל-OSS, דורש build ב-CI ציבורי). עד שהחתימה מאושרת, כותבים זאת בגלוי ב-Release notes ומסבירים איך לאמת SHA256.

---

## 4. Discussions

קטגוריות:
| קטגוריה | מטרה |
|---|---|
| 📣 **Announcements** (רק maintainers) | הודעות Release ו-roadmap |
| 🙏 **Q&A** | שאלות התקנה ופריסה. תשובה מסומנת "answered" |
| 💡 **Ideas** | בקשות פיצ'רים, עם הצבעות |
| 🧭 **Fleet dashboard waitlist** | Discussion נעוץ אחד: "Tell us your fleet size and what you'd need from a dashboard." זו רשימת ההמתנה ל-SaaS, בלי טופס ובלי איסוף מיילים |
| 🛠️ **Show your deployment** | אדמינים משתפים סקריפט Intune או GPO שלהם (בלי נתונים מזהים) |
| 🔎 **Detection research** | איפה כלי X שומר הגדרות, שינויים בנתיבים |

**כלל:** כל שאלה מקבלת תשובה תוך 24 שעות בשבועיים הראשונים. תשובה טובה שחוזרת על עצמה הופכת לדף ב-`docs/` (זה גם SEO).

---

## 5. תבניות Issues (`.github/ISSUE_TEMPLATE/`, בפורמט YAML forms)

| תבנית | שדות עיקריים |
|---|---|
| **➕ Add a tool to the catalog** | שם הכלי · סוג (app / extension / coding agent / MCP client / local LLM) · אתר רשמי · איך מזהים התקנה (נתיב, registry key, Appx name, extension ID) · איפה קובץ ההגדרות / MCP · האם אפשר להגדיר auto-approve / shell · מקור לתיעוד · "I can open a PR myself" ☐ |
| **🎯 False positive / missed detection** | מה הדוח הראה · מה ציפית · גרסת הכלי · Windows build · קטע מה-JSON **אחרי** redaction (תיבת סימון חובה: "I removed usernames, hostnames and secrets") |
| **🐞 Bug** | גרסה · PowerShell version · הקשר הריצה (user / SYSTEM / Intune) · הודעת שגיאה |
| **💡 Feature request** | הבעיה (לא הפתרון) · גודל הצי · Intune / GPO / RMM אחר |
| **🛡️ Security issue** | לא תבנית. `config.yml` מפנה ל-Private Vulnerability Reporting (`SECURITY.md`) |

ב-`config.yml`: `blank_issues_enabled: false`, וקישורים ל-Discussions Q&A ולרשימת ההמתנה.
**Labels:** `catalog`, `good first issue`, `help wanted`, `detection`, `false-positive`, `deploy:intune`, `deploy:gpo`, `privacy`.

---

## 6. הקטלוג הקהילתי כמנוע צמיחה

**הבעיה שהוא פותר:** נתיבי ההגדרות של כלי AI משתנים כל חודש (סיכון שמופיע בהחלטה 003). צוות של אדם אחד לא יכול לעקוב.
**הפתרון:** תיקייה `catalog/` עם קובץ YAML לכל כלי, ש-agent קורא בזמן ריצה.

```yaml
# catalog/coding-agents/claude-code.yaml
id: claude-code
name: Claude Code
category: coding-agent
vendor_url: https://docs.anthropic.com/claude-code
detect:
  files: ["%USERPROFILE%\\.claude.json", "%USERPROFILE%\\.claude\\settings.json"]
mcp_config:
  - path: "%USERPROFILE%\\.claude.json"
    key: mcpServers
risky_settings:
  - key: permissions.defaultMode
    value: bypassPermissions
    severity: high
    owasp_asi: ASI03
sources: [ "<link to official docs>" ]
maintainers: [ "@github-handle" ]
```

**הלולאה:**
1. אדמין מריץ, ורואה בדוח "Unknown AI-related process: X" או מגלה שכלי חסר.
2. הדוח עצמו מציג קישור: *"Missing something? Add it to the catalog"* → תבנית issue "Add a tool".
3. תורם פותח PR עם קובץ YAML. **CI אוטומטי** בודק schema, שאין בקובץ סודות, ושיש מקור.
4. merge → הכלי נכנס ל-Release הבא, עם קרדיט ב-Release notes ובקובץ `CONTRIBUTORS`.
5. **דף שנוצר אוטומטית** `catalog/<tool>.md` ("Where does <Tool> store its config on Windows?") מאונדקס בגוגל ומביא את האדמין הבא.

**כדי שהלולאה תעבוד:**
- **להשיק עם כ-40 כלים** (לפי תוכנית שבוע 1 ב-`03`) ועם 10 issues מסומנים `good first issue` לכלים שעוד חסרים.
- תורם ראשון: `CONTRIBUTING.md` עם מדריך של 5 דקות "add a tool" ודוגמה מלאה.
- **בלי לבקש ערכי סודות או נתונים מזהים**, אף פעם, גם לא בתבניות.
- הקטלוג ברישיון פתוח (למשל CC0 או אותו רישיון של הקוד), כדי שגם כלים אחרים יוכלו להשתמש בו. זה בונה אמון ושם.

---

## 7. מילות מפתח ל-SEO (מה אדמינים מחפשים)

**איפה משתמשים בהן:** תיאור הריפו, כותרות ב-README, שמות קבצים ב-`docs/`, כותרות Discussions, ‏`<title>` ו-`<meta description>` בדף הנחיתה.

| אשכול | מילות מפתח | דף יעד |
|---|---|---|
| **Shadow AI inventory** | shadow AI inventory Intune · detect AI tools installed on Windows endpoints · shadow AI discovery open source · AI asset inventory for EU AI Act | README, דף הנחיתה |
| **MCP + סודות** | MCP config secrets · mcp.json API key exposed · find MCP servers on endpoints · claude_desktop_config.json location · MCP server inventory | `docs/mcp-config-locations.md`, ‏`docs/secrets-in-mcp-configs.md` |
| **Coding agents** | detect Claude Code / Cursor / Copilot installed Intune · Claude Code bypassPermissions · Cursor auto-run risk · Gemini CLI settings.json location | דפי `catalog/*.md` |
| **Intune / GPO** | Intune remediation script AI apps · Intune detect per-user AppData apps · GPO inventory AI software · Intune local AI agent inventory | `docs/deploy/intune.md`, ‏`docs/deploy/gpo.md` |
| **מודלים מקומיים** | Ollama exposed 0.0.0.0 port 11434 · find Ollama LM Studio on network · local LLM security | `docs/local-llm-exposure.md` |
| **תוספי דפדפן** | AI browser extensions inventory Chrome Edge · malicious AI Chrome extensions prompt poaching | `docs/browser-extensions.md` |
| **תאימות** | AI inventory ISO 42001 evidence · OWASP Agentic Top 10 checklist · cyber insurance AI questionnaire | `docs/compliance-mapping.md` |
| **MSP** | MSP shadow AI report for clients · multi-tenant AI inventory | README (Roadmap), Discussion |

**כלל כתיבה:** כל דף ב-`docs/` עונה על שאלה **אחת** במשפט הראשון, ואז מראה איך AI Stocktake עושה את זה אוטומטית. בלי מילות מפתח ממולאות.

---

## 8. ערוצי גילוי בתוך GitHub (בלי לצאת ממנו)

- **רשימות awesome:** PR אחד מכובד לכל רשימה רלוונטית (MCP security, sysadmin, Intune, PowerShell, AI security), **רק** לפי כללי ההשתתפות שלהן ורק אחרי שיש Release חתום. בלי spam.
- **Topics** (ראו §1).
- **תשובות מועילות ב-issues של פרויקטים אחרים**, כשמישהו שואל בדיוק את מה שאנחנו פותרים (למשל "איפה Cursor שומר mcp.json ב-Windows"). עונים קודם כל לשאלה עצמה, ומוסיפים קישור רק אם הוא באמת עוזר. כלל: לכל היותר תגובה אחת כזו ביום.
- **Gist** עם סקריפט PowerShell קטן ושימושי ("List MCP servers configured on this machine") שמפנה לכלי המלא.
- **GitHub Pages** לדף הנחיתה ולמדריכים.
- **אסור:** חשבונות פיקטיביים, החלפת כוכבים, בוטים, ופניות לא מבוקשות למשתמשים.

---

## 9. צ'קליסט השקה

### T-7 עד T-1 (לפני ההשקה)
- [ ] אישור שם (`NAMING.md`) והחלטה על הריפו (שינוי שם או ריפו חדש) ועל מקור ה-Pages.
- [ ] README לפי §2, ‏`PRIVACY.md`, ‏`SECURITY.md`, ‏`CONTRIBUTING.md`, ‏`LICENSE`, ותבנית DPIA.
- [ ] תיאור, Topics, Social preview, Website.
- [ ] Discussions מופעל עם 6 קטגוריות, ו-Discussion רשימת המתנה נעוץ.
- [ ] תבניות Issues ו-labels. ‏10 issues מסוג `good first issue` לכלים חסרים בקטלוג.
- [ ] CI ציבורי (GitHub Actions): Pester tests, PSScriptAnalyzer, בדיקת schema לקטלוג, ובדיקה שאין סודות בריפו.
- [ ] Private Vulnerability Reporting מופעל.
- [ ] `v0.1.0` עם ZIP, ‏`SHA256SUMS` ו-`sample-report.html`.
- [ ] דף הנחיתה ב-Pages: לבדוק במובייל, במצב כהה ועם קורא מסך.
- [ ] **ביקורת אמת:** כל טענה ב-README ובדף הנחיתה מופיעה בקוד, וכל תקרית עם קישור עובד. בלי מספרים מומצאים.
- [ ] בדיקה שאין פרטים אישיים של המייסד ושאין סודות בהיסטוריית ה-git.
- [ ] 4 מדריכים ב-`docs/`: Intune, GPO, מיקומי MCP config, סודות בקבצי MCP.

### יום ההשקה (T0)
- [ ] הריפו ציבורי, Release מסומן Latest, הודעה ב-Announcements.
- [ ] PRs לרשימות awesome מתאימות (§8).
- [ ] לרשום את נקודת הבסיס: כוכבים, הורדות, צפיות ו-clones.

### T+1 עד T+14
- [ ] כל יום: לענות ל-issues ול-Discussions תוך 24 שעות, ולרשום מדדים בטבלה (§10).
- [ ] T+3: ‏Release ‏`v0.1.1` עם תיקונים מהפידבק הראשון.
- [ ] T+7: ‏Release עם הכלים הראשונים שנוספו מהקהילה, וקרדיט לתורמים. דוח ביניים למנכ"ל.
- [ ] T+10: מדריך `docs/` חדש לפי השאלה הכי נפוצה.
- [ ] T+14: דוח מסכם לדירקטוריון מול קריטריון העצירה.

---

## 10. מדדים מול קריטריון העצירה (14 יום)

**הקריטריון (החלטה 003):** פחות מ-**30 כוכבים** ו-**100 הורדות** תוך 14 יום מההשקה → חוזרים לדירקטוריון.
**פרשנות שצריך לאשר:** הנוסח "פחות מ-30 כוכבים **ו**-100 הורדות" דו-משמעי. **אנחנו מציעים** להתייחס לזה כשני יעדים שצריך לעמוד בשניהם (30 כוכבים **וגם** 100 הורדות). זו הקריאה המחמירה יותר. המנכ"ל יאשר.

### איך מודדים (הכול מ-GitHub API, בחינם)
| מדד | מקור | הערה |
|---|---|---|
| ⭐ כוכבים | `gh api repos/{owner}/{repo} --jq .stargazers_count` | מדד הקריטריון |
| ⬇️ הורדות | `gh api repos/{owner}/{repo}/releases --jq '[.[].assets[].download_count] \| add'` | מדד הקריטריון. סופרים רק את ה-ZIP של המודול, לא את `sample-report.html` |
| 👀 צפיות ומבקרים ייחודיים | `gh api repos/{owner}/{repo}/traffic/views` | GitHub שומר רק **14 יום**, ולכן שומרים צילום יומי |
| 📥 Clones | `gh api repos/{owner}/{repo}/traffic/clones` | מדד משני (חלק מה-clones הם בוטים ו-CI) |
| 🔗 מקורות הפניה | `traffic/popular/referrers`, `traffic/popular/paths` | מראה אם ה-SEO וה-awesome lists עובדים |
| 🔔 Watchers | `subscribers_count` | רשימת ההמתנה ל-Releases |
| 💬 מעורבות | מספר Issues, Discussions, תגובות ברשימת ההמתנה | איכותי: מי השואלים (אדמין? MSP? מפתח?) |
| 🧩 תרומות לקטלוג | PRs ממוזגים עם label `catalog` | מדד ללולאת הצמיחה |

### יעדי ביניים (כדי לדעת מוקדם אם אנחנו בדרך)
| יום | ⭐ כוכבים | ⬇️ הורדות | סימן |
|---|---|---|---|
| T+1 | 5 | 15 | ה-README מסביר את עצמו |
| T+3 | 10 | 35 | |
| T+7 | 18 | 60 | אם מתחת ל-50% מהיעד: לשנות כותרת README, להוסיף מדריך SEO, ולבדוק את ה-referrers |
| T+14 | **30** | **100** | **הקריטריון** |

**המדדים האלה הם יעדים פנימיים שלנו, לא תחזית ולא נתון.**

### מה מדווחים לדירקטוריון ב-T+14
1. כוכבים והורדות מול הקריטריון: עמדנו או לא.
2. מגמה יומית (טבלה).
3. מי הגיע: התפלגות של מי שפתח issues או כתב ב-Discussions (אדמין, MSP, מפתח), לפי מה שהם כתבו בעצמם.
4. כמה כתבו ברשימת ההמתנה ל-dashboard, ובאיזה גודל צי. **זה האות החשוב ביותר להמשך** (שלב ה-SaaS).
5. תרומות לקטלוג.
6. המלצה: להמשיך, לשנות כיוון, או לעצור.

---

## 11. סיכונים שיווקיים

| סיכון | מענה |
|---|---|
| ה-README הנוכחי (AuthShift) מבלבל מבקרים | שינוי שם לריפו או ריפו חדש לפני ההשקה (החלטה של המנכ"ל) |
| EDR או AV מסמנים סקריפט שסורק קבצי הגדרות | חתימת קוד, קוד פתוח וקריא, שאלות נפוצות ב-README ("Why does my EDR flag this?") |
| חשש פרטיות של עובדים או ועדים | `PRIVACY.md`, מצב privacy, תבנית DPIA, ורשימה מפורשת של מה **לא** נאסף, כבר בראש הדף |
| Microsoft מרחיבה את Local AI Agent inventory ב-Intune | המסר מתמקד במה ש-Intune לא עושה היום (עומק MCP, הרשאות, סודות, ותמיכה בלי Intune או E5). לא תוקפים את Microsoft |
| טענה לא מדויקת פוגעת באמון | ביקורת אמת לפני כל Release (§9) |
