# 02 — הזדמנויות SaaS ו-AI לחברת "מייסד אחד + סוכני AI"

**מאת:** SaaS & AI Opportunities Analyst · **תאריך:** 2026-10-21
**שאלת המחקר:** אילו שווקי תוכנה צומחים בסוף 2026 ואפשר לנצח בהם עם אדם אחד, סוכני AI ותקציב כמעט אפסי? והאם יש משהו טוב יותר מנישת ה-AD/Kerberos?

> **הסתייגות:** רוב הנתונים כאן מגיעים מבלוגים של ספקים ומסקרים שהם מממנים. המספרים מראים כיוון, לא נתונים מדויקים.

---

## 1. שווקים צומחים שאפשר לנצח בהם באופן ריאלי

| שוק | איתות צמיחה | אפשר לנצח בו לבד? |
|---|---|---|
| **כלים ל-MSP** | לפי סקר MSP 501 של Informa לשנת 2026, ההכנסה החוזרת צמחה ב-11.9% ו-67% מה-MSP מצפים לצמיחה דו-ספרתית. לפי Kaseya, 48% מה-MSP מדרגים AI ואוטומציה כצורך מס' 1 של הלקוחות, אבל רק 13% מרוויחים מזה בפועל. | **כן.** קהל טכני שקונה כלים קטנים בתשלום חודשי ומתכנס בקהילות כמו r/msp ו-MSPGeek. |
| **AI agents ל-IT Ops** | Gartner צופה שעד סוף 2026 ל-40% מאפליקציות האנטרפרייז יהיו AI agents ייעודיים, לעומת 5% ב-2025. ה-MCP Server של מיקרוסופט ל-Entra עדיין ב-Preview, ולא נמצא MCP server בשל ל-**AD on-prem**. | **חלקית.** הפער ב-on-prem אמיתי, אבל הסיכון הוא שמיקרוסופט תסגור אותו בעצמה. |
| **אוטומציית Compliance** (SOC2/NIS2/DORA) | NIS2 מרחיבה את התחולה מכ-10,000 לכ-160,000 גופים. Vanta ו-Drata עולים 10K–25K$ לשנה, ופלטפורמות NIS2 ל-SME עולות 5K–40K€ לשנה. | **לא כפלטפורמה GRC מלאה**, השוק רווי. **כן כ-wedge**: איסוף ראיות טכניות מ-Windows/AD שהפלטפורמות הגדולות לא מכסות לעומק. |
| **רגולציה ישראלית** | תיקון 13 לחוק הגנת הפרטיות בתוקף מאוגוסט 2025: קנסות מנהליים, ביקורות ודרישת DPO. צפויים מסעות אכיפה ב-2026. | **כן, נישה מקומית.** השוק קטן, אבל יש מעט מתחרים בעברית ולמייסד יש יתרון מקומי. |
| **הקשחת Windows/AD אחרי שינויים של מיקרוסופט** | אכיפת RC4 נכנסה עם עדכון יולי 2026 (MC1427604). אי אפשר לחזור ל-Audit mode, ושירותים legacy (SAP/Oracle/NAS) נשברים. | **כן.** כאב חד ומתוזמן, והמייסד כבר בנה כלי בדיוק לזה. |

## 2. דפוסים של micro-SaaS שהצליח ב-2025–2026

- **התפלגות ההכנסות:** החציון של micro-SaaS שמכניס כסף הוא כ-**145$ MRR** בלבד, והממוצע כ-4,298$. רק כ-18% מגיעים ל-1K–5K$ MRR. מוצר נכשל בדרך כלל בגלל הפצה, לא בגלל הקוד.
- **ערך ביציאה:** עסקים מתחת ל-1M$ ARR נמכרים ב-Acquire.com בערך ב-2.5–4x מההכנסה השנתית. גם 5K$ MRR הוא נכס שאפשר למכור.
- **מחירים:** כלים ל-B2B ול-MSP נמכרים בדרך כלל ב-**29–199$ לחודש**, או לפי מספר tenants/endpoints. כלים "לפרויקט", כמו סריקה ודוח חד-פעמי, נמכרים ב-**99–499$ לרישיון**. קונים שאינם טכנולוגיים נוטשים הרבה פחות מקונים שהם מייסדים בעצמם (טענה לא מאומתת: 1.6% לעומת 11% בחודש).
- **ערוצי הפצה:**
  1. **ערוץ נישה אחד** (subreddit, Slack או ניוזלטר) עדיף על פיזור בהרבה ערוצים.
  2. **SEO סביב כאב ספציפי**, למשל "Kerberos RC4 event 4769 fix". זו הפצה בחינם עם זמן הבשלה של 3–6 חודשים.
  3. **Free tool → paid**: סקריפט קוד פתוח ב-GitHub או ב-PowerShell Gallery כ-lead magnet, ודוח או multi-tenant בתשלום.
  4. **Microsoft Marketplace/AppSource**: עמלת העסקאות היא 3% בלבד, אבל הוא דורש מוצר SaaS מבוסס Entra וביצוע certification. כדאי לדחות אותו לשלב 2.
- **זמן להכנסה ראשונה** (לפי טבלת ספק, לא מאומת): לכלים פנימיים שנמכרים כ-SaaS, 1–3 חודשים ל-1K$ MRR. ל-SaaS מבוסס תוכן, 3–6 חודשים.

## 3. רעיונות מוצר מועמדים (בכמה תחומים)

1. **AD Hygiene Scanner ל-MSP:** הרחבה של כלי ה-RC4 לסורק מלא: RC4/AES, שימוש ב-NTLM, Kerberoastable SPNs, unconstrained delegation, גיל ה-krbtgt, סיסמאות ישנות. התוצר הוא דוח HTML/PDF ממותג ל-MSP עם מיפוי לסעיפי NIS2 ותיקון 13. מודל: סקריפט חינמי ודוח, רישוי multi-client ו-remediation בתשלום.
2. **On-prem AD MCP Server:** ממשק AI agent בטוח ל-AD מקומי, ברירת מחדל read-only, עם approval gates לפעולות כתיבה ו-audit log. נותן לסוכני AI לבצע משימות helpdesk כמו unlock, reset ובדיקת קבוצות.
3. **Israeli Privacy Evidence Pack (תיקון 13):** מחולל מסמכים בעברית (מדיניות אבטחה, מיפוי מאגרים, נוהל אירועים) שמחובר לראיות טכניות שנאספו אוטומטית מ-AD/M365.
4. **M365/Entra CIS Posture ל-MSP:** בדיקת tenants מול CIS ו-drift detection. יש כאן מתחרים חזקים: Augmentt, Nerdio, Abnormal ו-CIPP החינמי בקוד פתוח.
5. **AI QBR Generator ל-MSP (לא אבטחה):** סוכן שמושך נתונים מ-RMM/PSA ומפיק דוח רבעוני ללקוח (QBR) עם המלצות upsell. חוסך ל-MSP שעות של עבודה ידנית.
6. **AI Security Questionnaire Responder (לא IT):** מילוי אוטומטי של שאלוני ספקים ל-SaaS קטנים. הביקוש גבוה, אבל Vanta ומתחרים כמו Wolfia כבר בשוק.

### טבלת ניקוד (1–5, גבוה = טוב; בתחרות, 5 = מעט תחרות)

| # | רעיון | ביקוש | דחיפות | תחרות (הפוך) | Founder fit | זמן ל-MVP | מונטיזציה | **סה"כ /30** |
|---|---|---|---|---|---|---|---|---|
| 1 | AD Hygiene Scanner ל-MSP | 4 | 5 | 3 | 5 | 5 | 4 | **26** |
| 2 | On-prem AD MCP Server | 3 | 3 | 4 | 5 | 4 | 2 | **21** |
| 3 | Israeli Privacy Evidence Pack | 3 | 4 | 4 | 4 | 3 | 3 | **21** |
| 4 | M365 CIS Posture ל-MSP | 4 | 3 | 1 | 4 | 3 | 3 | **18** |
| 5 | AI QBR Generator ל-MSP | 4 | 2 | 3 | 2 | 3 | 4 | **18** |
| 6 | AI Security Questionnaire | 4 | 3 | 1 | 2 | 4 | 4 | **18** |

**נימוקים קצרים:**
- **#1:** הדחיפות בציון 5 כי אכיפת RC4 כבר שוברת סביבות, וההוצאה משימוש של NTLM היא הגל הבא. ה-MVP כמעט קיים, וזה הכלי הנוכחי. התחרות בינונית: ManageEngine, Cayosoft ו-PingCastle קיימים, אבל הם יקרים, מיועדים לאנטרפרייז או לא ממוקדים ב-MSP.
- **#2:** הפער הטכנולוגי מעניין, אבל אין עדיין תקציב מוגדר אצל הקונים ומיקרוסופט עלולה להיכנס לתחום. כדאי לבנות אותו כפיצ'ר של #1, לא כמוצר עצמאי.
- **#3:** יתרון מקומי חזק, אבל השוק קטן ודורש ידע משפטי, כך שיש סיכון של אחריות מקצועית. מתאים כמודול עברי ל-#1.
- **#4–6:** שווקים טובים, אבל רוויים או רחוקים מהמומחיות של המייסד. משם מגיעה הראייה הצרה ("tunnel vision") ההפוכה: לרדוף אחרי שוק חם בלי יתרון.

## 4. ההמלצה: #1, AD Hygiene Scanner ל-MSP ולצוותי IT קטנים

**למה הוא:**
1. **הכאב מתוזמן ומאומת:** עדכון יולי 2026 ביטל את ה-Audit mode של RC4. ארגונים שלא התכוננו נתקלים בכשלי Kerberos עכשיו, ו-NTLM הוא הגל הבא. זה הדפוס הקלאסי של "Microsoft change = market".
2. **Founder fit מקסימלי וזמן ל-MVP של שבועות:** יש כבר כלי PowerShell עובד עם audit, remediation, rollback ו-CSV. הסוכנים יכולים להוסיף בדיקות ומחולל דוחות HTML במהירות.
3. **ערוץ הפצה ברור וזול:** קוד פתוח ב-GitHub וב-PowerShell Gallery, פוסטים טכניים עם SEO ממוקד-שגיאה (Event IDs, KB 5073381), ונוכחות ב-r/msp ו-r/sysadmin. כל זה כמעט בלי עלות.
4. **מונטיזציה ריאלית:** מודל open-core. Community חינמי, **Pro ב-~49–99$ לחודש** ל-MSP עם multi-client, דוחות ממותגים, מיפוי NIS2/תיקון 13 והשוואה היסטורית, ו**דוח הערכה חד-פעמי ב-~199–499$** לארגון. יעד ריאלי: 1K–3K$ MRR תוך 4–6 חודשים.
5. **פלטפורמה להמשך:** #2 (MCP/AI agent ל-AD) ו-#3 (חבילת ראיות בעברית) יכולים להיבנות מעל אותו מנוע סריקה. כך ההימור נשאר ממוקד אבל עם אופציות להתרחב.

**סיכונים:** חלון הדחיפות של RC4 הולך ונסגר. צריך לבנות את המוצר סביב "AD hygiene" רחב ולא סביב RC4 בלבד. הכלים החינמיים (PingCastle Basic, Purple Knight) מגבילים את המחיר, ולכן הבידול הוא ב-**remediation בטוח עם rollback** וב-**דוחות ל-MSP**, לא בסריקה עצמה.

**צעד הבא מוצע:** לעשות ולידציה של 7 ימים. לפרסם את הסקריפט ופוסט "RC4 enforcement broke X — here's how to find it" ב-r/sysadmin, ולמדוד הורדות, כוכבים ופניות ל-Pro, לפני שכותבים שורת קוד בתשלום.

---

## מקורות
- Kaseya, State of the MSP 2026: https://www.kaseya.com/?p=27349
- Channel Insider, MSP AI revenue: https://www.channelinsider.com/ai/msp-ai-revenue-growth-2026/
- IT Brief UK (Informa MSP 501): https://itbrief.co.uk/story/msps-expect-ai-revenue-to-surge-as-services-mature
- Micro-SaaS revenue statistics: https://blog.mean.ceo/?p=11213
- Bootstrapped SaaS valuation multiples 2026: https://beancount.io/blog/2026/07/11/bootstrapped-saas-valuation-multiples-2026-acquire-com-indie-founders-guide
- Micro-SaaS distribution / timelines: https://www.questera.ai/blogs/micro-saas-ideas-indie-hackers-ai ; https://ideaproof.io/reports/micro-saas-goldmine-2026 ; https://www.shno.co/marketing-statistics/micro-saas-launch-statistics
- NIS2 tooling market: https://usecure.io/blog/top-10-nis2-compliance-tools-for-2026 ; https://www.legiscope.com/blog/nis2-compliance-software.html ; https://www.deeploi.io/magazine/nis2-compliance-smbs-what-to-do-now
- Vanta/Drata pricing: https://connect.wolfia.com/blog/vanta-reviews-pricing-alternatives ; https://www.knowlee.ai/blog/tools/drata-pricing-2026 ; https://www.costbench.com/compare/drata-vs-vanta/
- M365 CIS posture tools: https://abnormal.ai/blog/cis-6-microsoft-365-posture-rethink ; https://helpdesk.augmentt.com/compliance/cis-m365-foundation-benchmark ; https://getnerdio.com/download-how-to-implement-and-enforce-cis-grade-security-baselines
- Microsoft MCP Server for Enterprise (Entra): https://learn.microsoft.com/graph/mcp-server/overview ; https://www.scalekit.com/blog/mcp-gateway-microsoft-entra-integration-guide
- RC4 enforcement: https://mc.merill.net/message/MC1427604 ; https://support.microsoft.com/help/5073381 ; https://www.cayosoft.com/?p=66690 ; https://petri.com/microsoft-phases-out-rc4-kerberos-security/
- Israel Amendment 13: https://www.gornitzky.com/reducing-the-risk-of-privacy-enforcement-in-israel-client-update-for-international-privacy-day/ ; https://www.vixio.com/insights/pc-regulatory-influencer-israel-modernises-privacy-law-comprehensive
- Microsoft Marketplace 3% fee: https://itpro.com/cloud/platform-as-a-service-paas/360220/microsoft-lowers-marketplace-transaction-fee-to-3
