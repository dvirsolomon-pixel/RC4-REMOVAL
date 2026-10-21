# מיתוג: בחירת שם ל-AI Footprint Scanner

**מאת:** מנהל השיווק · **תאריך:** 2026-10-21 · **סטטוס:** המלצה, ממתינה לאישור המנכ"ל
**מבוסס על:** [החלטה 003](../../decisions/003-ai-security-product.md), `research/ai-security/01–03`

---

## שורה תחתונה

**ההמלצה: AI Stocktake.** שם הריפו: **`ai-stocktake`**. חלופה שנייה: AI Rollcall.

- **"Take stock"** הוא ביטוי שכל דובר אנגלית מכיר: לעצור ולספור מה יש לך. זה בדיוק מה שהמוצר עושה, עושה רק את זה, ואין בו הבטחה שהוא לא מקיים. הוא לא אומר "חוסם", "מגן" או "מנטר".
- **בדקנו 6 מועמדים ועוד 9 שמות שנפסלו מוקדם.** רק ל-AI Stocktake לא מצאנו אף ריפו בשם `ai-stocktake`/`aistocktake` ב-GitHub, ולא מוצר או סימן מסחר בשם הזה ברשת.
- **שם העבודה "AI Footprint" פסול:** ב-GitHub יש 436 ריפואים עם `ai-footprint` בשם. רובם מחשבים **פליטות פחמן** של AI, ואחד מהם מתעד מקור של קוד שנוצר ב-AI. מי שיחפש את השם ימצא בעיקר מחשבוני CO2.

---

## קריטריונים

| קריטריון | למה הוא חשוב לנו |
|---|---|
| **ייחודי ב-GitHub** | GitHub הוא הערוץ הפומבי היחיד. חיפוש בשם צריך להחזיר אותנו ראשונים. |
| **לא מתנגש עם מוצר אבטחה או סימן מסחר** | שוק אבטחת ה-AI עמוס ברכישות ובכסף (ראו `02-competitors.md`). אנחנו לא רוצים מכתב מעורך דין. |
| **לא מטעה** | המוצר **רק ממפה**, ולא חוסם, לא מנטר תוכן ולא עוקב אחרי עובדים. שם שנשמע כמו מעקב ("Watch", "Whereabouts", "Spy") יפגע באמון של ועדי עובדים וב-GDPR. גם שם שנשמע כמו הגנה ("Guard", "Shield") מבטיח יותר ממה שיש. |
| **ברור לאדמין בשנייה** | מנהל Intune או טכנאי MSP צריך להבין מהשם שמדובר במלאי. |
| **קצר וטבעי בשורת פקודה** | `Invoke-AIStocktake`, `ai-stocktake-report.html`. |
| **מחזיק לאורך זמן** | מתאים גם ל-macOS, ל-fleet dashboard ול-Pro. לא קשור לכלי אחד (MCP, Claude) שעשוי להתיישן. |

---

## הבדיקה: מה מצאנו (21/10/2026)

**השיטה:** WebSearch לכל שם, וחיפוש ריפואים ב-GitHub לפי שם (`<name> in:name`, ממוין לפי כוכבים). **זו בדיקה ראשונית בלבד**, לא חיפוש במאגרי סימני מסחר (USPTO/EUIPO/WIPO/UKIPO). לפני רישום או לוגו צריך לחפש את השם ישירות במאגרים אלה (חינם, אפשר לעשות ידנית).

| # | שם | GitHub (`in:name`) | חיפוש רשת | רמת התנגשות |
|---|---|---|---|---|
| 1 | **AI Footprint** (שם העבודה) | **436 ריפואים**. לדוגמה `EugenioPetulla/ai-footprint` (הערכת אנרגיה ו-CO2 של קריאות AI), `securestor/ai-footprint` (provenance לקוד AI), ‏`anoble2020/aifootprint` (פחמן של Cursor). בנוסף יש ארגון בשם **FootprintAI** (‏`FootprintAI/Containarium`, ‏310★, agent runtime עם MCP) | אין מוצר אבטחה בשם הזה. המונח "AI footprint" משמש בעיקר לפליטות. יש כלי `hb-scan` שמדבר על "AI tool footprints" | **גבוהה.** שם רווי, משמעות סביבתית, ושכן בשם כמעט זהה בתחום ה-agents |
| 2 | **AgentCensus** | **3 ריפואים**. החשוב: `BrianMcD47/AgentCensus` (‏2★, נוצר 08/2026). זה **סורק read-only שממפה AI agents וסודות**, עם התגיות `shadow-ai`, `agent-security`, `mcp` (כרגע ל-ServiceNow) | "AI Agent Census" ב-Product Hunt (רישום של agents), skill בשם agent-census, ומאמר של MIT Media Lab על "agentic census" | **גבוהה.** אותו רעיון בדיוק ואותו קהל |
| 3 | **AgentAtlas** | **18 ריפואים**. לדוגמה `vlr-code/AgentAtlas` (אפליקציית macOS ש**מוצאת את כל קבצי ההגדרות של coding agents**), `1lihaocun/agentAtlas` (מיפוי קבצי agents) | אין מוצר בשם הזה, אבל **MITRE ATLAS** הוא מסגרת האיומים המרכזית ל-AI, ו-**ChatGPT Atlas** הוא הדפדפן של OpenAI | **גבוהה.** בלבול עם MITRE ATLAS בדיוק בתחום שלנו, וכלי זהה ב-GitHub |
| 4 | **AgentTally** | **3 ריפואים**. `stephanos/agenttally-macos` (‏3★, מעקב עלויות של Claude Code), `suiyun08/agenttally`, `kasuken/AgentTally` (תצוגה חיה של coding agents) | אין מוצר AI בשם הזה. Tally הוא רובוט מלאי של Simbe Robotics (קמעונאות) | **בינונית.** שלושה כלים קטנים לאותו קהל של מפתחים עם agents |
| 5 | **AI Rollcall** | **0 ריפואים** בשם `airollcall`. אבל יש 2 ריפואים בשם `rollcall` בתחום: `jimmyjames177414/rollcall` ("Roll call for the AI coding agents already running on your machine", ‏0★) ו-`mickamy/rollcall` (proxy ל-DB שמתעד איזה agent נגע במידע, ‏0★) | אין מוצר "AI Rollcall". יש iRollCall (נוכחות), RollKall (שיבוץ שוטרים) ו-CQ Roll Call (אתר חדשות פוליטי בארה"ב) | **בינונית-נמוכה.** השם המלא פנוי, אבל המילה rollcall כבר משמשת לרעיון דומה |
| 6 | **AI Stocktake** ⭐ | **0 ריפואים** בשם `aistocktake`, ו-0 ריפואים רלוונטיים ל-"stocktake ai". המילה `stocktake` לבדה מופיעה ב-376 ריפואים, כולם אפליקציות ספירת מלאי למחסנים, פורטפוליו מניות, ו-skill אחד של Claude Code בשם `skill-stocktake` (‏3★) שמבקר skills מותקנים | אין מוצר בשם "AI Stocktake". יש אפליקציות ספירת מלאי (Peckish, Daftra, i-StockTake, מדריך Ai-Menu POS), כולן בקמעונאות ובהסעדה. לא נמצא סימן מסחר STOCKTAKE בתחום התוכנה או האבטחה | **נמוכה.** אין חפיפה בתחום. המילה כללית, ולכן חיפוש צריך להיות על הצירוף "AI Stocktake" |

### שמות שנפסלו מוקדם (נבדקו ב-GitHub ו/או ברשת)
| שם | למה נפסל |
|---|---|
| AgentLedger | 106 ריפואים, אחד מהם עם 81★. ‏"Ledger" מתקשר ל-audit trail, לתשלומים ולארנק הקריפטו Ledger (שהשיק Agent Stack) |
| AgentPrint | 6 ריפואים, כולל `FalkorDB/AgentPrint`. ברשת זה מזוהה עם Agent Printers של Black Ice (מדפסות וירטואליות) |
| Agentory | 18 ריפואים, כולל ארגון `agentoryhq` |
| AI Roster | נשמע כמו **AIR Security** (סטארט-אפ שגייס 50 מיליון דולר וממפה agents בארגונים) וכמו **Prisma AIRS**. יש גם מוצר "Roster" שמחבר agents לספריית הארגון |
| AgentSweep | 8 ריפואים, אחד מהם (`byte5digital/agentsweep`) סורק ומבודד MCP configs זדוניים, בדיוק התחום שלנו |
| Muster / AIMuster | הארגון `musterhq` בונה agent harness עם ai-governance |
| ShadowTrace | 182 ריפואים, בעיקר כלי OSINT ומעקב, וזה בדיוק הטון שאנחנו רוצים להימנע ממנו |
| Aimprint | 7 ריפואים, אחד מהם מודד צריכת טוקנים של Claude Code |
| AI Whereabouts | פנוי, אבל **מטעה**: נשמע כמו מעקב מיקום אחרי עובדים |

---

## ניתוח לכל מועמד

### 1. AI Footprint (שם העבודה). ציון 2/5
- **בעד:** מתאר נכון את הרעיון, וכבר מופיע במסמכי החברה.
- **נגד:** 436 ריפואים. "Footprint" באנגלית של 2026 קשור קודם כל לפחמן. חברת FootprintAI פעילה בתחום ה-agents. אי אפשר להיות ראשונים בחיפוש.

### 2. AgentCensus. ציון 2/5
- **בעד:** "Census" הוא בדיוק מפקד, והשם מצלצל טוב.
- **נגד:** יש פרויקט פתוח עם אותו שם ואותה הבטחה (read-only, shadow AI, MCP). גם אם הוא קטן, זו התנגשות ישירה. בנוסף, "Agent" לא מכסה אפליקציות AI ותוספי דפדפן.

### 3. AgentAtlas. ציון 2/5
- **בעד:** "Atlas" משדר מפה ותמונה כוללת.
- **נגד:** MITRE ATLAS הוא שם מרכזי בשוק אבטחת ה-AI, ועלול לגרום לבלבול או להיראות כמו ניסיון להיתלות בו. יש כלי macOS עם אותו שם ואותה פונקציה.

### 4. AgentTally. ציון 3/5
- **בעד:** קצר, ברור ("ספירה").
- **נגד:** שלושה כלים קטנים לאותו קהל מפתחים, ושניים מהם מסוג menu bar indicator. "Tally" משדר ספירה פשוטה ולא ניתוח סיכון.

### 5. AI Rollcall. ציון 3.5/5 (חלופה שנייה)
- **בעד:** השם המלא פנוי. "Roll call" הוא ביטוי מוכר (מסדר נוכחות), ומתאים ל"מי נמצא על המחשבים שלך".
- **נגד:** בכתיב צמוד `AIRollcall` הוא נקרא בטעות "Air-oll-call". יש ריפו קטן בשם rollcall עם אותה הבטחה בדיוק. "Roll call" מתקשר לנוכחות **אנשים**, וזה עלול להישמע כמו מעקב אחרי עובדים.

### 6. AI Stocktake ⭐ מומלץ. ציון 4.5/5
- **בעד:**
  - **אין התנגשות** בתחום התוכנה, באבטחה או ב-GitHub.
  - **לא מטעה:** "stocktake" זו ספירת מלאי, לא מעקב ולא חסימה. זה תואם בדיוק את עקרון הפרטיות (מלאי והגדרות בלבד, אף פעם לא prompts).
  - **מתחבר לרגולציה:** כל מסגרת (EU AI Act, ISO 42001, OWASP Agentic Top 10, שאלוני ביטוח) מתחילה במלאי (ראו `01-market.md` §2). "תעשו stocktake של ה-AI שלכם" זו שפה שמנהל GRC מבין.
  - **מכסה את כל המוצר:** אפליקציות, תוספים, agents, MCP, הרשאות, סודות ומודלים מקומיים. לא נעול על "Agent" או על "MCP".
  - **טבעי בשורת פקודה:** `Invoke-AIStocktake`, `Import-Module AIStocktake`, `ai-stocktake-report.html`.
  - **סלוגן מובנה:** *"Take stock of the AI on every Windows machine."*
- **נגד:**
  - "Stocktake" נפוץ יותר באנגלית בריטית ואוסטרלית. **מענה:** הביטוי "take stock" מוכר בכל האנגלית, וה-README יפתח בשורה שמסבירה את השם.
  - המילה כללית, ולכן חלשה כסימן מסחר וחיפוש על "stocktake" לבד יחזיר אפליקציות מחסן. **מענה:** תמיד לכתוב את הצירוף המלא "AI Stocktake", ולשים בריפו topics כמו `shadow-ai` ו-`mcp-security`.
  - "Stock" עלול להתפרש כמניות. **מענה:** השורה התיאורית בריפו מבהירה מיד ("open-source AI inventory for Windows endpoints").

---

## ההמלצה הסופית

| פריט | ערך |
|---|---|
| **שם המוצר** | **AI Stocktake** |
| **שורת משנה** | *Open-source AI inventory for Windows endpoints: apps, extensions, coding agents, MCP servers, risky permissions, reachable secrets.* |
| **סלוגן** | *Take stock of the AI on every Windows machine.* |
| **שם הריפו** | **`ai-stocktake`** (אותיות קטנות עם מקף, כמו רוב הכלים ב-GitHub) |
| **מודול PowerShell** | `AIStocktake` (פקודה ראשית: `Invoke-AIStocktake`) |
| **קובץ דוח** | `ai-stocktake-report.html` |
| **שמות עתידיים** | AI Stocktake Community (חינם, OSS) · AI Stocktake Cloud (dashboard, בקרוב) · AI Stocktake Pro (מתוכנן) |

### לגבי הריפו הנוכחי
הריפו הציבורי היום הוא `dvirsolomon-pixel/RC4-REMOVAL`, ודף הנחיתה מפנה אליו כפי שהתבקש. **מומלץ** (החלטה של המנכ"ל, לא של השיווק) לשנות את שמו ל-`ai-stocktake` לפני ההשקה, או לפתוח ריפו חדש לקוד ה-agent. GitHub מפנה אוטומטית קישורים מהשם הישן אחרי שינוי שם, כך שהקישורים בדף הנחיתה ימשיכו לעבוד. את התוכן של AuthShift (המוצר המוקפא) כדאי להעביר לתיקייה נפרדת או לריפו אחר, כדי שמבקר שמגיע ל-README לא יתבלבל.

### צעדים לפני שהשם סופי
1. חיפוש ידני של "AI STOCKTAKE" ו-"STOCKTAKE" במחלקות 9 ו-42 ב-USPTO, ‏EUIPO ו-UKIPO (חינם).
2. לוודא שה-handle `ai-stocktake` פנוי כארגון ב-GitHub (לשימוש עתידי בלבד, לא חובה).
3. אישור של המנכ"ל, ואז החלפת "AI Footprint Scanner" בכל מסמכי `company/ai-footprint/`.

---

## ממצא אגבי לצוות המוצר
בחיפושים עלו מתחרים שלא מופיעים ב-`02-competitors.md`. כדאי שהאנליסט יבדוק אותם:
- **GitGuardian Endpoint Protection: "Agent and MCP inventory"**. לפי התיעוד שלהם, מציג על תחנות המפתחים אילו AI agents מותקנים (Claude Code, Cursor, Codex), לאילו שרתי MCP הם מחוברים ולאילו נתונים וכלים יש להם גישה. ([docs.gitguardian.com](https://docs.gitguardian.com/endpoint-protection/agent-and-mcp-inventory))
- **AIR Security**: גילוי agents בארגון ובדיקה של skills, plugins ושרתי MCP. גייסה 50 מיליון דולר (לפי דיווח).
- **Straiker Discover AI** ו-**BeyondTrust Insights (Agent inventory)**.
- רשומת סימן מסחר (ID 50048386 ב-trademarkregistration.app) לתוכנה ל"discovery, visibility, inventory... across AI agents and coding agents". שם הסימן לא הופיע בתוצאות ולא אומת.

---

## מקורות
- GitHub repository search (`in:name`), 21/10/2026: ‏ai-footprint, aifootprint, footprintai, agentcensus, agentatlas, agentledger, agenttally, airollcall, rollcall, aistocktake, stocktake, agentprint, agentory, airoster, agentroster, agentsweep, aimuster, shadowtrace, aimprint, aiwhereabouts.
- [hb-scan (PyPI)](https://pypi.org/project/hb-scan/)
- [AI Agent Census (hunted.space)](https://hunted.space/product/ai-agent-census) · [MIT Media Lab: agentic census](https://www.media.mit.edu/articles/the-invisible-economy-why-we-need-an-agentic-census/)
- [CSA: MITRE ATLAS agentic gap analysis](https://labs.cloudsecurityalliance.org/agentic/csa-research-note-atlas-agentic-gap-analysis-20260327/) · [OpenAI: hardening Atlas](https://openai.com/index/hardening-atlas-against-prompt-injection)
- [AgentLedger (0G forum)](https://hall.0g.ai/t/agentledger-making-ai-agents-insurable/253) · [Ledger Agent Stack (The Block)](https://theblock.co/post/408549/ledger-unveils-hardware-backed-agent-stack)
- [Simbe Tally (Supermarket News)](https://www.supermarketnews.com/grocery-technology/bj-s-wholesale-club-to-roll-out-ai-inventory-bots)
- [iRollCall (GetApp)](https://www.getapp.com/all-software/a/irollcall/) · [RollKall](https://parse.gl/brands/rollkall-com)
- [Black Ice Agent Printers](https://blackice.com/Black-Ice-Agent-Printers)
- [AIR Security (TechCrunch)](https://techcrunch.com/?p=3159543) · [Prisma AIRS](https://docs.paloaltonetworks.com/ai-runtime-security) · [Roster (Capterra)](https://www.capterra.ca/software/1106526/Roster)
- [Peckish](https://appshunter.io/ios/app/peckishai/id6753873032) · [Daftra stocktaking](https://www.daftra.com/en/stocktaking/) · [i-StockTake](https://ensun.io/company/i-stocktake-64a122f0c7884de109140f4e)
- [GitGuardian Agent and MCP inventory](https://docs.gitguardian.com/endpoint-protection/agent-and-mcp-inventory) · [Straiker Discover AI](https://www.straiker.ai/products/discover-ai) · [BeyondTrust agent inventory](https://docs.beyondtrust.com/insights/docs/agent-inventory-insights)
- [trademarkregistration.app 50048386](https://trademarkregistration.app/Trademark/Details/50048386)
