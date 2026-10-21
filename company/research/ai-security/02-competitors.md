# 02 — מתחרים ופערים בשוק אבטחת ה-AI

**אנליסט:** AI Security Competitors · **תאריך:** 2026-10-21 · **בסיס:** [החלטה 002](../../decisions/002-pivot-ai-security.md)

> שיטה: חיפוש ברשת, אוקטובר 2026. נתוני הכוכבים ב-GitHub נמשכו ב-21/10/2026. חלק מהמקורות הם בלוגים של ספקים מתחרים, ולכן טענות שמקורן בספק מסומנות כך. מחירי עסקאות הם הערכות עיתונאיות.

## 1. תמונת מצב: גל רכישות

בשנים 2025–2026 נבלעו רוב הסטארטאפים של אבטחת AI בידי ספקי אבטחה גדולים:

| חברה | נרכשה ע"י | מועד | מחיר (מדווח) |
|---|---|---|---|
| Robust Intelligence | Cisco | 08/2024 | — |
| Protect AI | Palo Alto Networks | 04/2025 | ~$700M |
| Invariant Labs (mcp-scan) | Snyk | 06/2025 | — |
| Aim Security | Cato Networks | 2025 | ~$350M |
| Prompt Security | SentinelOne | 08/2025 | ~$250M |
| Lakera | Check Point | 09/2025 | ~$300M |
| Pangea | CrowdStrike | 09/2025 | ~$260M |
| CalypsoAI | F5 | 09/2025 | ~$180M |
| Koi (agentic endpoint) | Palo Alto Networks | 02/2026 (נסגר 04/2026) | ~$400M |
| Promptfoo | OpenAI | 03/2026 | — |
| LayerX | Akamai (היום Workforce Protector) | 05/2026 (נסגר 07/2026) | ~$205M |

**חברות שעדיין עצמאיות:** Harmonic, Nightfall, Lasso ($30M, 09/2026), Zenity ($125M Series C, 08/2026), Noma, HiddenLayer ($100M Series B, 09/2026), Pillar, Cyberhaven ו-Island.

**המשמעות בשבילנו:** הקטגוריה הוכחה ככזו שיש בה כסף, אבל היא נכנסה לתוך פלטפורמות enterprise יקרות שנמכרות רק דרך צוותי מכירות. הלקוחות הקטנים נשארו בחוץ.

## 2. פילוח מתחרים

### א. AI Usage Control / AI DLP (שליטה בשימוש העובדים ב-AI)
- **Harmonic Security:** browser extension יחד עם endpoint agent ל-Windows ול-macOS. הוא מזהה Claude Code, Codex ו-Ollama, וכולל inline coaching ו-MCP permissions. אין מחיר פומבי: שלוש רמות (Explore/Guide/Command) והכול דרך demo. היעד הוא mid-market ו-enterprise.
- **Nightfall:** DLP לדפדפן, ל-endpoint ול-SaaS, כולל masking של prompts. ב-01/2026 השיק AI Browser Security. המחיר לפי הצעה.
- **Prompt Security (SentinelOne) ו-Aim (Cato):** extension ו-gateway שהפכו לחלק מפלטפורמות XDR/SASE. כדי לקבל אותם צריך לקנות את הפלטפורמה כולה.
- **LayerX (Akamai) ו-Island:** LayerX הוא extension ואילו Island הוא enterprise browser שמחליף את הדפדפן הקיים. Island מעולה בשליטה, אבל ההטמעה כבדה.
- **Microsoft Purview DSPM for AI:** כלול ב-E5 או ב-Purview Suite (‎$12 למשתמש לחודש), ועל ה-browser extension ועל ה-connectors יש מונים בתשלום לפי שימוש. **החולשה:** הוא מורכב, דורש E5 וסובסקריפשן Azure, ו-SMB על Business Premium בדרך כלל לא מגיעים אליו.
- **Netskope, Zscaler ו-Palo Alto AI Access / Prisma AIRS:** אכיפה ב-cloud proxy במסגרת SASE. חולשות: עלות גבוהה, הטמעה מורכבת, עיוורון לכלים מקומיים כמו CLI agents ו-MCP stdio.
- **כלים זולים ל-SMB:** Nudge Security ‏($5 למשתמש לחודש, או $750 לחודש לפחות מ-150 משתמשים), Shadow AI Detector ‏($500 לחודש עד 50 עובדים), OrgLogic (חינם עד 25 משתמשים, ואחר כך $8 למושב). כולם רואים SaaS ודפדפן, **ואף אחד מהם לא רואה endpoint או סוכנים מקומיים**.

### ב. LLM / Agent Security (אבטחת אפליקציות וסוכנים שהארגון בונה)
- **Lakera (Check Point), Protect AI (PANW), CalypsoAI (F5) ו-Pangea (CrowdStrike):** guardrails דרך API ו-firewall ל-prompts. כבר נבלעו בפלטפורמות.
- **HiddenLayer:** אבטחת מודלים ו-runtime לסוכנים. enterprise, ממשל וביטחון.
- **Noma:** AI-SPM לאפליקציות, ל-RAG ול-MCP שהארגון מפתח בעצמו. יש אפשרות self-hosted, והלקוחות בעיקר regulated enterprise.
- **Zenity:** governance לסוכנים (Copilot Studio, Power Platform וסוכני SaaS), עם קבוצת לקוחות מרוכזת במיוחד ב-Microsoft. נמכר דרך מכירות ו-AWS Marketplace.
- **Pillar:** פלטפורמה ל-lifecycle מלא של סוכנים, כולל coding agents. מתמקד ב-enterprise.

### ג. MCP / Coding-Agent Security
- **Snyk Agent Scan (לשעבר Invariant mcp-scan):** CLI בקוד פתוח שסורק MCP servers, skills ו-tool poisoning, וכולל proxy. מיועד למפתחים ולא נותן תמונה ארגונית.
- **Microsoft Defender for Endpoint:** מאז 2026 מציג local AI agents (Cursor, Claude Code ועוד) כנכסים, ומסמן auto-approve ו-MCP. **זה האיום הישיר על כל רעיון שמבוסס Windows endpoint.** החולשה שלו: דורש רישוי Defender, עומק התצורה מוגבל, ואין remediation מודרך ל-SMB.
- **Koi → Cortex XDR, Cyberhaven ו-Backslash:** agentic endpoint ברמת enterprise.
- **GitGuardian:** מתמקד בסודות שנחשפים ל-coding agents.

## 3. טבלת השוואה

| ספק | קטגוריה | פריסה | מחיר פומבי | יעד | חולשה עיקרית |
|---|---|---|---|---|---|
| Harmonic | AI DLP | Extension + Endpoint | לא | Mid/Ent | Sales-led, אין self-serve |
| Nightfall | AI DLP | Extension/Endpoint/API | לא | Mid/Ent | יקר, ממוקד DLP |
| Prompt (S1) | AI DLP + LLM | Extension/Gateway | לא | Ent | נעול ל-Singularity |
| Aim (Cato) | AI DLP | SASE | לא | Ent | נעול ל-SASE של Cato |
| LayerX (Akamai) | Browser | Extension | לא | Ent | רק דפדפן |
| Island | Browser | Enterprise browser | לא | Ent | החלפת דפדפן, יקר |
| MS Purview DSPM | AI DLP | Endpoint DLP + Ext | E5 ומונים לפי שימוש | Ent | מורכב, דורש E5 |
| MS Defender (local agents) | Agent inventory | Endpoint (MDE) | ברישוי MDE | All-MS | שטחי, בלי הדרכה לתיקון |
| Netskope/Zscaler/PANW | SSE | Cloud proxy | לא | Ent | לא רואה CLI ו-MCP מקומי |
| Lakera/Protect AI/Pangea | LLM guardrails | API | לא | Ent | נבלעו בפלטפורמות |
| Zenity | Agent governance | SaaS connectors + endpoint | לא | Ent | Sales-led |
| Noma / Pillar / HiddenLayer | AI-SPM/runtime | SaaS/self-hosted | לא | Ent | בניית אפליקציות, לא עובדים |
| Snyk Agent Scan | MCP scan | CLI OSS | חינם | Dev | אין fleet ואין dashboard |
| Nudge / Shadow AI Detector | Shadow AI | SaaS/Extension | כן ($5/user; $500/mo) | SMB | לא רואים endpoint ו-agents |

## 4. קוד פתוח ב-GitHub (כוכבים, 21/10/2026)

| Repo | ⭐ | מה עושה | פער |
|---|---|---|---|
| [promptfoo/promptfoo](https://github.com/promptfoo/promptfoo) | 26.2K | Red-teaming ו-evals (היום של OpenAI) | צד מפתח, לא endpoint |
| [NVIDIA/SkillSpector](https://github.com/NVIDIA/SkillSpector) | 20.8K | סורק Skills ו-MCP לפני התקנה (נוצר 03/2026) | סריקה נקודתית, אין fleet |
| [NVIDIA/garak](https://github.com/NVIDIA/garak) | 9.6K | LLM vulnerability scanner | בודק מודלים |
| [superagent-ai/superagent](https://github.com/superagent-ai/superagent) | 6.8K | Guardrails לאפליקציות | צד אפליקציה |
| [protectai/llm-guard](https://github.com/protectai/llm-guard) | 3.2K | Guardrails | **Archived** אחרי הרכישה |
| [snyk/agent-scan](https://github.com/snyk/agent-scan) | 3.2K | MCP/agent scanner | CLI למפתח בודד |
| [affaan-m/agentshield](https://github.com/affaan-m/agentshield) | 1.3K | סורק תצורות agent | צד CI/repo |
| [cisco-ai-defense/mcp-scanner](https://github.com/cisco-ai-defense/mcp-scanner) | 1.1K | YARA ל-MCP | סורק שרתים |
| [lasso-security/mcp-gateway](https://github.com/lasso-security/mcp-gateway) | 0.4K | MCP gateway | דורש ניתוב ידני |
| [adithyan-ak/AgentHound](https://github.com/adithyan-ak/AgentHound) | 0.45K | "BloodHound לסוכנים" (offensive) | התקפי ולא הגנתי |

**הפער בקוד הפתוח:** הרבה סורקים נקודתיים למפתח בודד, ואף אחד מהם הוא **agent קל ל-fleet של תחנות Windows** שמדווח ל-dashboard מרכזי. פרויקטים שנרכשים הופכים לפעמים ל-archived (llm-guard), וזה משאיר קהילה בלי בית.

## 5. White Space לצוות זעיר

1. **SMB/mid-market (50–1,000 עובדים):** כל המובילים מוכרים רק דרך demo. ב-SMB יש רק כלי SaaS/דפדפן זולים, ואף אחד מהם לא רואה את ה-endpoint. **פער ברור: self-serve, תמחור שקוף (למשל $3–5 ל-endpoint לחודש), free tier.**
2. **Windows/AD-centric visibility:** רוב ה-SMB הם Windows עם AD או Entra. agent שממפה על כל תחנה את כלי ה-AI המקומיים (Claude Code, Cursor, Copilot, Ollama), את תצורות ה-MCP (`mcp.json`, `claude_desktop_config.json`), את ההרשאות (`bypassPermissions`, wildcard Bash), את הסודות בקבצי env או config שנגישים לסוכן ואת חשבונות ה-AD/Entra שהסוכן רץ תחתם. **הקישור לזהות ב-AD/Entra** (לדוגמה סוכן שרץ כ-local admin, או tokens של חשבונות מועדפים) הוא נקודה ש-Snyk ו-Nudge לא מכסים, ושבה למייסד יש יתרון מומחיות.
3. **Open-source agent + SaaS dashboard:** agent בקוד פתוח בונה אמון (agent שרץ על endpoint חייב שקיפות) ומביא הפצה דרך GitHub בעלות 0. ה-dashboard ל-fleet, ההיסטוריה, הדוחות והתראות ה-drift יהיו בתשלום. המודל הזה דומה ל-Snyk/Invariant לפני הרכישה, אבל ממוקד בצי מחשבים.
4. **"Defender-lite" למי שאין לו E5:** Microsoft מסמנת שזה תחום חשוב, אבל רק בתוך MDE או E5. לקוחות Business Premium ו-MSPs לא מקבלים את זה. **ערוץ MSP** (מולטי-tenant) הוא פער נוסף.

**סיכונים:** Microsoft Defender יכול לרדת לרמות רישוי נמוכות יותר. Harmonic עלול לרדת ל-SMB. גל הרכישות מראה ש-exit אפשרי, אבל גם שהשוק צפוף ב-enterprise.

## מקורות
- https://www.calcalistech.com/ctechnews/article/rj5bc1vige
- https://www.calcalistech.com/ctechnews/article/im5ma59bu
- https://www.calcalistech.com/ctechnews/article/bjt0500luxl
- https://pulse.latio.tech/p/unpacking-the-2025-ai-security-acquisitions
- https://www.securityweek.com/crowdstrike-to-acquire-pangea-to-launch-ai-detection-and-response-aidr/
- https://siliconangle.com/2025/09/16/crowdstrike-check-point-extend-ai-security-capabilities-new-acquisitions/
- https://paloaltonetworks.com/company/press/2026/palo-alto-networks-announces-intent-to-acquire-koi-to-secure-the-agentic-endpoint
- https://www.kuppingercole.com/blog/care/palo-alto-networks-acquires-koi-securing-the-agentic-endpoint
- https://securityboulevard.com/2026/03/openai-acquires-security-startup-promptfoo-to-fortify-ai-agents
- https://www.nightfall.ai/blog/layerx-security-reviews (מקור מתחרה)
- https://appsecsanta.com/mcp-scan
- https://techcrunch.com/2026/09/02/hiddenlayer-nabs-100m-as-enterprises-rush-to-secure-their-ai-deployments/
- https://pinpointsearchgroup.com/september-26-cyber-security-vendor-funding-mampa/
- https://kosmoy.com/resources/blog/zenity-vs-noma-security/ (מקור מתחרה)
- https://toolradar.com/tools/harmonic-security
- https://www.harmonic.security/solutions/endpoint-ai-security
- https://www.prnewswire.com/news-releases/nightfall-unveils-ai-browser-security-solution-to-stop-data-exfiltration-in-real-time-302666771.html
- https://o365hq.com/blog/microsoft-purview-dspm-for-ai-what-it-shows-licensing-and-setup
- https://www.schneider.im/microsoft-purview-pay-as-you-go-meters-protecting-ai-apps-and-agents
- https://techcommunity.microsoft.com/blog/microsoftthreatprotectionblog/the-next-frontier-in-endpoint-security-securing-local-ai-agents-with-microsoft-d/4524651
- https://zerototrust.tech/discover-local-ai-agents-microsoft-defender-endpoint/
- https://www.pillar.security/blog/best-ai-coding-agent-security-tools-for-the-enterprise-2026 (מקור מתחרה)
- https://www.nudgesecurity.com/post/best-shadow-ai-detection-tools
- https://shadowaidetector.com/
- https://www.orglogic.ai/post/shadow-ai-detection-tools
- https://blog.gitguardian.com/ai-coding-agents-credential-security/
- https://dope.security/post/palo-alto-prisma-access-competitors (מקור מתחרה)
