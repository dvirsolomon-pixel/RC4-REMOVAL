# 01 — מפת שוק אבטחת ה-AI (אוקטובר 2026)

**אנליסט:** AI Security Market Analyst · **תאריך:** 2026-10-21 · **בסיס:** [החלטה 002](../../decisions/002-pivot-ai-security.md)

> **הערה מתודולוגית:** תחזיות השוק סותרות זו את זו מאוד, כי כל גוף מגדיר "AI security" אחרת. רוב המספרים כאן לקוחים מדוחות של vendors או מסיכומים משניים, ולכן הם מכוונים כיוון ולא יותר. נתון שלא אומת מול המקור הראשוני מסומן ב-(משני).

## תמונת מצב: 5 שורות
1. Gartner (2Q26, משני) מסווג את "securing AI" תחת Other Security Software, ומעריך צמיחה מ-$15.6B ב-2025 ל-$37.6B ב-2030, כ-18.5% בשנה. [softwarestrategiesblog](https://softwarestrategiesblog.com/tag/gartner-forecast/)
2. גל רכישות בשנים 2024–2026: כמעט כל vendor אבטחה גדול קנה סטארט-אפ AI security. השוק עובר הסתגלות לפלטפורמות (platformization).
3. הכאב הכי גדול ב-2026 הוא **agents** (MCP ו-coding agents), אבל המימון ב-pure-play MCP security עדיין קטן, כ-$40M בכל התחום. [softwarestrategiesblog](https://softwarestrategiesblog.com/2026/03/28/agentic-ai-security-startups-funding-mna-rsac-2026/)
4. ה-EU AI Act נדחה חלקית, אבל OWASP, NIST ושאלוני ביטוח כבר מייצרים דרישה בפועל.
5. Gartner (מאי 2026) צופה ש-90% מספקי ה-endpoint protection יציעו AI discovery עד 2028. כלומר יש חלון זמן מוגבל לפני שהפיצ'ר הופך ל-commodity. [Gartner](https://www.gartner.com/en/documents/8286821)

## 1. פילוח הסגמנטים

| סגמנט | גודל וצמיחה (אינדיקטיבי) | M&A ומימון בולטים | קונה | גורמי דחיפות |
|---|---|---|---|---|
| **Shadow AI discovery & governance** | Gartner מתאר "multibillion-dollar opportunity" ופרסם Market Overview for AI Usage Control באוגוסט 2026 | CrowdStrike קנתה את Pangea (~$260M, ספטמבר 2025). Cato קנתה את Aim Security | CISO, GRC | לפי Gartner, 69% מהארגונים חושדים או יודעים על שימוש ב-AI אסור. לפי DBIR 2026, שימוש ב-shadow AI עלה מ-15% ל-45% (משני) |
| **AI DLP** (הדבקת מידע ל-ChatGPT/Copilot/Gemini) | חופף לסגמנט הקודם ול-SSE | SentinelOne קנתה את Prompt Security (~$250M, משני). Veeam קנתה את Securiti ב-$1.725B | CISO, DLP team | Netskope: בממוצע ~223 הפרות מדיניות genAI בחודש לארגון. **source code** הוא סוג המידע המוביל (משני) |
| **AI agent / MCP security** | Agentic AI security: $1.65B ב-2026 ל-$13.5B ב-2032, CAGR 42% (דוח בודד) | Snyk קנתה את Invariant Labs (mcp-scan, יוני 2025). Runlayer גייסה $11M seed. Noma גייסה $100M | AppSec, Platform/DevEx, CISO | axios npm hijack (מרץ 2026) הזריק MCP servers זדוניים לקונפיגים של Claude Code, Cursor ו-Windsurf. GitGuardian: 24,008 secrets בקבצי MCP config ב-GitHub הציבורי |
| **Prompt injection / LLM firewall** | חלק מ-"AI runtime security" | Check Point קנתה את Lakera (~$202M לפי 20-F). F5 קנתה את CalypsoAI. Zscaler קנתה את SPLX | AppSec, צוותי מוצר AI | OWASP LLM01. אפליקציות RAG ו-chatbots בפרודקשן |
| **AI-SPM** | $7.17B ב-2026, CAGR 24% (דוח בודד, ספק סביר) | Wiz, Microsoft Defender ו-Palo Alto Prisma AIRS כבר בפנים | Cloud security | מלאי מודלים ו-endpoints בענן. נשלט על ידי CNAPP |
| **Model supply chain** | AI model security: $1.65B ב-2026, CAGR 24.5% | Palo Alto קנתה את Protect AI (יולי 2025) | ML platform, AppSec | מודלים זדוניים ב-Hugging Face, pickle. AI-BOM |
| **AI red-teaming** | לא נמצא מספר אמין | Cisco קנתה את Robust Intelligence (2024). OpenAI קנתה את Promptfoo (מרץ 2026, משני) | AppSec, AI teams | EU AI Act, דרישות לקוחות. קיימים כלים חינמיים חזקים (Garak, PyRIT) |

**מסקנות מהטבלה:**
- הסגמנטים של LLM firewall, AI-SPM, supply chain ו-red-teaming **נתפסו** על ידי הפלטפורמות הגדולות (PANW, Cisco, Check Point, Zscaler, Wiz).
- Shadow AI ו-AI DLP צפופים, ונשלטים על ידי SSE ו-browser security.
- MCP ו-coding agents על ה-endpoint הם הסגמנט הצעיר ביותר, והוא עדיין בשלב seed.

## 2. רגולציה ומסגרות שמייצרות תקציב

- **EU AI Act:** האיסורים ו-AI literacy בתוקף מפברואר 2025. חובות GPAI בתוקף מאוגוסט 2025. ה-**AI Omnibus** פורסם ב-Official Journal ב-24.7.2026, ודחה את חובות ה-high-risk ל-**2.12.2027** (stand-alone, Annex III) ול-**2.8.2028** (Annex I). שקיפות לפי Art. 50 נשארה ב-2.8.2026. בפועל ארגונים צריכים כבר עכשיו **מלאי של מערכות AI** כדי לסווג אותן. [iubenda](https://www.iubenda.com/en/blog/ai-omnibus-adopted-august-2-obligations-july-2026/) · [Gibson Dunn](https://www.gibsondunn.com/eu-ai-act-omnibus-agreement-postponed-high-risk-deadlines-and-other-key-changes/) · [FPF](https://fpf.org/blog/the-ai-act-implementation-timeline-what-changes-under-the-ai-omnibus)
- **ISO/IEC 42001:** מערכת ניהול AI. ISO 42006 (יולי 2025) מסדיר את גופי ההסמכה, ו-BSI הפך לגוף המוסמך הראשון של UKAS בסוף 2025. האימוץ עדיין מוגבל בגלל מחסור במבקרים, אבל הוא מספק דרישת **evidence**, כלומר מלאי, מדיניות ולוגים. [Bright Defense](https://brightdefense.com/news/iso-42006-raises-the-bar-for-iso-42001-certifiers)
- **NIST:** את ה-AI RMF משלים **Cyber AI Profile (IR 8596)**, טיוטה מדצמבר 2025 שמבוססת על CSF 2.0 (Secure/Defend/Thwart). בנוסף, CAISI השיק בפברואר 2026 את ה-AI Agent Standards Initiative. [NIST CSRC](https://csrc.nist.gov/pubs/ir/8596/iprd) · [CSA](https://labs.cloudsecurityalliance.org/research/csa-research-note-nist-ai-agent-standards-regulatory-framewo/)
- **OWASP:** Top 10 for **Agentic Applications 2026** (ASI01–ASI10) פורסם ב-9.12.2025. Top 10 for LLM Applications 2026 פורסם באוגוסט 2026. שתי הרשימות משמשות שפה משותפת ל-checklists של AppSec. [OWASP](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026) · [CSA](https://labs.cloudsecurityalliance.org/research/csa-research-note-owasp-genai-top10-2026-agent-control-stand/)
- **ביטוח ו-SOC2:** מבטחים מתרחקים מכיסוי "silent AI". יש AI exclusions ב-CGL מ-1.1.2026, תתי-גבולות (sublimits) ל-AI ב-cyber, ושאלות על שימוש ב-genAI ובכלי AI coding בשאלוני החיתום. שאלוני ספקים (vendor questionnaires) ו-SOC2 שואלים "איזה AI אתם משתמשים ואיך אתם שולטים בו". [Fenwick](https://fenwick.com/insights/publications/end-silent-ai-emerging-ai-exclusions-coverage-fragmentation-and-practical-implications) · [Hunton](https://hunton.com/insights/publications/best-practices-for-ai-disclosures-in-insurance-applications) · [Kovrr](https://www.kovrr.com/blog-post/does-cyber-insurance-cover-ai-incidents)

**המשותף לכל המסגרות:** כולן מתחילות ב-**inventory**. לפני שאפשר לנהל סיכון, צריך לדעת אילו כלי AI, agents ו-MCP servers רצים בארגון. זה בדיוק מה ש-agent מקומי יודע לספק.

## 3. מה ניתן לנצח עם צוות זעיר

**ההנחות:**
- **יתרונות:** המייסד חזק ב-Windows, AD ו-PowerShell, וכבר עובד עם AI agents.
- **מגבלות:** אין תקציב, ולכן אין תשתית inline proxy יקרה.
- **אסטרטגיית הפצה:** open-source CLI או agent ב-GitHub, כ-funnel ל-SaaS.

**מה לא כדאי:**
- LLM firewall ו-AI-SPM: נשלטים על ידי ענקיות ודורשים runtime בענן.
- Model scanning: כבר קיים מוצר חינמי של Protect AI/PANW.
- Red-teaming: Promptfoo, Garak ו-PyRIT חינמיים ונתמכים.

**סולם הניקוד:** 1–5, כש-5 הוא הטוב ביותר. בעמודת Competition, 5 פירושו מעט תחרות.

| # | רעיון מוצר | Demand | Urgency | Competition | Founder fit | Time-to-MVP | Monetization | **סה"כ** |
|---|---|---|---|---|---|---|---|---|
| A | **AgentGuard for Endpoints:** agent ל-Windows/macOS שמגלה coding agents ו-MCP servers מקומיים (Claude Code, Cursor, Copilot, Windsurf, Continue), מזהה secrets בקבצי config, MCP servers לא מאושרים, הרשאות shell ו-tool poisoning, ומרכז הכול ב-SaaS dashboard עם policy | 4 | 5 | 4 | 5 | 4 | 4 | **26** |
| B | **Shadow AI Inventory למנהלי IT:** סקריפט או agent שממפה אפליקציות AI, browser extensions ו-AI desktop apps על תחנות, עם ייצוא ל-EU AI Act ו-ISO 42001 | 5 | 4 | 2 | 5 | 5 | 3 | **24** |
| C | **Browser extension ל-AI DLP:** חסימת הדבקה של PII, secrets ו-source code לאתרי genAI | 5 | 4 | 1 | 2 | 3 | 3 | **18** |
| D | **MCP Gateway/Proxy מקומי:** אכיפה בזמן ריצה (allowlist של tools ושל קריאות shell) | 4 | 4 | 3 | 3 | 2 | 4 | **20** |
| E | **AI Governance Evidence Pack:** דוחות ו-policy templates ל-ISO 42001, EU AI Act ושאלוני ביטוח, שמוזנים מנתוני ה-agent | 3 | 3 | 3 | 3 | 4 | 3 | **19** |
| F | **Copilot/M365 AI exposure audit:** סריקת oversharing ב-SharePoint והרשאות Entra לפני פריסת Copilot | 4 | 3 | 2 | 5 | 4 | 3 | **21** |

**הנימוקים לציונים:**
- **A, ציון 26:** הדחיפות היא הגבוהה ביותר. יש תקריות אמיתיות ב-2026 (axios/WAVESHAPER שמוסיף MCP servers, postmark-mcp, ו-24K secrets ב-MCP configs), ו-OWASP ASI נותן לזה שפה. המתחרים קיימים (Snyk Agent Scan, Runlayer, Operant) אבל רובם CLI למפתח או gateway בענן, ולא **fleet-wide endpoint inventory עם ניהול מרכזי**. לגבי founder fit: פריסה דרך GPO או Intune, PowerShell, ו-Windows services הם בדיוק החוזקות של המייסד. ה-MVP הוא סורק קבצי config ידועים (`~/.claude`, `.cursor/mcp.json`, VS Code settings ו-env), כך שאפשר להגיע ל-OSS תוך 3–5 שבועות.
- **B, ציון 24:** הביקוש גבוה, אבל Gartner צופה שספקי EDR יכסו את זה עד 2028, ויש הרבה SSE ו-SaaS-management vendors. עדיף לשלב אותו כ-**feature** של A ולא כמוצר נפרד.
- **C, ציון 18:** השוק הכי צפוף (LayerX, Island, Netskope, Zscaler, Prompt/S1), וזה רחוק מהחוזקות של המייסד.
- **F, ציון 21:** התאמה מצוינת למייסד, אבל Microsoft Purview ו-SAM מכסים חלק גדול מהשטח. מתאים כמוצר משני או כ-lead magnet.

## 4. ההמלצה: רעיון A, אבטחת AI coding agents ו-MCP על ה-endpoint

**שלבים:**
1. **שלב 1, OSS:** CLI ב-PowerShell או Go בשם `agent-inventory` שמוציא JSON עם agents, MCP servers, הפקודות שהם מריצים, secrets (עם redaction), שינויי tool description (hash) ומיפוי ל-OWASP ASI.
2. **שלב 2, SaaS בחינם:** העלאת התוצאות ל-dashboard מרכזי, על free tier של אחת הפלטפורמות.
3. **שלב 3, מוצר בתשלום:** fleet policy (allowlist של MCP servers), התראות על drift, ודוחות evidence ל-ISO 42001, EU AI Act וחיתום ביטוחי. התמחור לפי endpoint.

**למה עכשיו:**
- coding agents הם ה-endpoint החדש עם הרשאות shell ו-secrets.
- הפלטפורמות הגדולות עדיין לא סגרו את הפער ב-endpoint.
- **הסיכון:** שספקי EDR יוסיפו את היכולת. **התגובה:** להוביל ב-OSS וב-community, ולהעמיק את השליטה ב-MCP מעבר ל-discovery גרידא.

## מקורות נוספים
- רכישות: [CyberScoop](https://cyberscoop.com/?p=85993) · [tech-insider (Lakera/PANW)](https://tech-insider.org/lakera-vs-prisma-airs-vs-cisco-ai-defense-2026/) · [BankInfoSecurity (Pangea)](https://www.bankinfosecurity.net/crowdstrike-buys-pangea-for-260m-to-guard-enterprise-ai-use-a-29480) · [SecurityWeek (SPLX)](https://www.securityweek.com/zscaler-acquires-ai-security-company-splx/) · [GovInfoSecurity (Invariant)](https://www.govinfosecurity.com/agentic-ai-security-gets-fuel-snyks-invariant-labs-buy-a-28789) · [CB Insights](https://www.cbinsights.com/compare/lakera-ai-vs-promptfoo)
- MCP: [TechCrunch (Runlayer)](https://techcrunch.com/2025/11/17/mcp-ai-agent-security-startup-runlayer-launches-with-8-unicorns-11m-from-khoslas-keith-rabois-and-felicis) · [Security Boulevard](https://securityboulevard.com/2026/06/973-mcp-packages-71-single-maintainer-a-practitioners-guide-to-ai-developer-security/) · [appsecsanta (mcp-scan)](https://appsecsanta.com/mcp-scan) · [CSA RiskRubric](https://labs.cloudsecurityalliance.org/agentic/csa-research-note-riskrubric-mcp-scanner-spec-20260327/)
- Shadow AI: [dope.security stats](https://dope.security/post/shadow-ai-statistics) · [Kiteworks](https://www.kiteworks.com/cybersecurity-risk-management/shadow-ai-data-leakage-governance/) · [Gartner AI Usage Control](https://www.gartner.com/en/documents/8232161)
- גודל שוק: [Meticulous](https://www.meticulousresearch.com/product/ai-model-security-market-6878) · [SNS Insider AI-SPM](https://www.snsinsider.com/reports/ai-security-posture-management-market-10651)
