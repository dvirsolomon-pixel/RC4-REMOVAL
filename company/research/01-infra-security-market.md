# דוח 01 — שוק אבטחת תשתיות AD / Kerberos / NTLM

**מאת:** אנליסט אבטחת תשתיות | **תאריך:** 2026-10-21 | **אל:** מנכ"ל

---

## תקציר מנהלים (טבלה)

| # | הזדמנות | כאב | קונה | דחיפות (10/2026) | מחיר משוער | תחרות | זמן ל-MVP |
|---|---|---|---|---|---|---|---|
| **1** | **Legacy Auth Readiness Kit ל-MSP** (RC4 + NTLM/NTLMv1 + LDAP signing, דוח ממותג רב-לקוחות) | MSP צריך להוכיח ללקוחות שהם מוכנים לשינויי ברירת המחדל של Microsoft — ולמכור פרויקט תיקון | MSPs קטנים-בינוניים, יועצי IT | **גבוהה** (NTLMv1 נאכף מ-10/2026, NTLM off בגרסה הבאה) | $49–$149 לחודש למ-MSP, או $99–$299 לדוח | בינונית | 4–6 שבועות |
| 2 | **NTLM Usage Mapper** (איסוף 4624/8001-8004, מיפוי אפליקציות/שרתים) | "מה יישבר כש-NTLM ייחסם?" — אין תשובה קלה | IT Admin במיד-מרקט | בינונית-גבוהה, עולה ב-2027 | $500–$2,000 לשנה לדומיין | בינונית (ManageEngine, Netwrix, Silverfort) | 6–10 שבועות |
| 3 | **RC4 Post-Enforcement Fixer** (פיענוח KDCSVC 201-209 / 4769 0x19, תיקון חשבונות שירות, NAS/SAP/MIT) | שירותים שנשברו אחרי יולי 2026, חשבונות עם RC4 מפורש | IT Admin, SMB | **יורדת** — חלון "לפני האכיפה" נסגר ביולי 2026 | חינם/Freemium, $29–$99 חד-פעמי | גבוהה (כלים חינמיים רבים) | 1–2 שבועות (כבר קיים) |
| 4 | **Compliance Evidence Pack** (מיפוי ממצאי AD ל-CIS / NIS2 / ISO 27001 / Cyber Insurance) | צריך הוכחות לביטוח סייבר ולמבקרים | SMB מוסדר, MSP | בינונית, תמידית | $300–$1,500 לשנה | בינונית-גבוהה | 6–8 שבועות |
| 5 | **SaaS/Agent ניטור רציף של AD Hygiene** | Drift — הגדרות חוזרות לאחור | מיד-מרקט | בינונית | $2–$5 למשתמש/שנה | **גבוהה מאוד** (Semperis, Tenable, Netwrix, Microsoft Defender for Identity) | 4–6 חודשים |

**המלצה #1:** הזדמנות 1 — **ערכת מוכנות ל-Legacy Auth עבור MSPs**, עם הכלי החינמי הקיים כמשפך שיווקי (פירוט בסוף).

---

## 1. ציר הזמן של Microsoft — מה כבר עבר ומה עוד לפנינו

**ממצא קריטי:** אכיפת RC4 **כבר הושלמה**. מועד הדחיפות הגדול של הכלי הקיים עבר.

| מועד | אירוע | סטטוס |
|---|---|---|
| נוב' 2022 | CVE-2022-37966: ברירת מחדל AES לחשבונות ללא הגדרה | הושלם |
| יוני 2024 | NTLM (כל הגרסאות) מוכרז deprecated; NTLMv1 הוסר ב-Win11 24H2 / Server 2025 | הושלם |
| 13/01/2026 | CVE-2026-20833 — שלב Audit, אירועי KDCSVC 201–209 | הושלם |
| אפריל 2026 | Enforcement כברירת מחדל (`DefaultDomainSupportedEncTypes=0x18`), עם rollback ידני | הושלם |
| **יולי 2026** | **Enforcement סופי — הוסר Audit mode ומפתח `RC4DefaultDisablementPhase`**; ב-Entra Domain Services RC4 כבוי לצמיתות מהשבוע של 13/07 | הושלם |
| **אוקטובר 2026** | **KB5066470: חסימת יצירת NTLMv1-derived credentials ל-SSO כברירת מחדל** (Win11 24H2–26H2, Server 2025, ללא Credential Guard) — שובר Wi-Fi/VPN מבוססי MS-CHAPv2 | **עכשיו** |
| H2 2026 | IAKerb + Local KDC (תחליפים למקרי fallback ל-NTLM) | בפריסה |
| גרסת Windows/Server הגדולה הבאה | **NTLM ברשת חסום כברירת מחדל** (ניתן להפעלה מחדש במדיניות) | 2027± (לא סופי) |
| Server 2025 (התקנות חדשות) | LDAP signing נדרש כברירת מחדל; channel binding "When supported" | קיים, הפצה הדרגתית בשדרוגים |

**מה יוצר כאב דחוף ומתוקצב?**
- **NTLM** — הגל הבא והגדול. NTLM מוטמע עמוק יותר מ-RC4 (אפליקציות legacy, NAS, מדפסות, גישה לפי IP, workgroups). אין תאריך סופי, אבל Microsoft כבר מספקת מנגנוני Audit/Block (Policy CSP: `BlockAll`, `BlockDomainAccountSSO`) — זה בדיוק הדפוס שקדם לאכיפת RC4.
- **NTLMv1/MS-CHAPv2** — כאב **מיידי** (אוקטובר 2026) אצל ארגונים עם VPN/Wi-Fi ישנים.
- **RC4** — שלב "Break-fix": הארגונים שלא התכוננו נתקלים בכשלים (4769 עם 0x19, SAP SSO, NetApp ONTAP, MIT Kerberos, SQL linked servers). דחיפות נקודתית, לא שוק צומח.

## 2. גודל שוק ופלחים

ההערכות שונות זו מזו בפי כמה, כי כל חברת מחקר מגדירה את השוק אחרת. להתייחס אליהן כסדר גודל בלבד:

| פלח | הערכה | מקור |
|---|---|---|
| ITDR | $2.78B (2025) → $3.42B (2026) | Mordor Intelligence |
| ITDR (הגדרה רחבה) | $12.8B (2024) → $35.6B (2029), CAGR 22.6% | MarketsandMarkets |
| ISPM | $13.7B (2024) → $33.1B (2029) | MarketsandMarkets |
| Active Directory Security | ~$1.12B (2026) → $2.74B (2032) | Mordor Intelligence |
| AD Management | $3.85B (2025) | HTF MI |

**הקשר:** AD משמש יותר מ-90% מחברות Fortune 1000 (נתון מחקר EMA בחסות ספק). לפי CrowdStrike, ~50% מהארגונים חוו תקיפת AD בשנתיים האחרונות. **הנישה שרלוונטית לנו** ("AD hygiene/readiness" לשוק ה-SMB וה-MSP) היא פלח קטן, בהערכה גסה מאות מיליוני דולרים. זה מספיק בהחלט לעסק של מייסד יחיד שמכוון ל-$10K–$50K MRR.

## 3. מי קונה, איך ובכמה

| פלח | איך קונה | נקודת מחיר אופיינית | התאמה לנו |
|---|---|---|---|
| **SMB (≤500 משתמשים)** | בעיקר דרך MSP; משתמש בכלים חינמיים (PingCastle Basic, Purple Knight) | $0–$1,000/שנה | נמוכה ישירות, גבוהה דרך MSP |
| **מיד-מרקט (500–5,000)** | IT Admin מוריד כלי חינמי, מתקצב לפי DC או לפי משתמש, רכש של 2–8 שבועות | ADAudit Plus: $595–$945 ל-2 DCs, $4.4K–$6.6K ל-20 DCs; PingCastle Enterprise מ-$30 לזהות/שנה; PingCastle Pro (מחירון ישן) ~$8.3K לדומיין/שנה | בינונית (מחזור מכירה ארוך) |
| **אנטרפרייז** | RFP, Semperis / Tenable / CrowdStrike / Defender for Identity | $50K+ | לא רלוונטי |
| **MSP / יועצים** | כרטיס אשראי, החלטה מהירה, רוצים דוח ממותג שמייצר פרויקט | PingCastle for Service Providers: **מ-$1,000 להערכה/שנה**; MSPs גובים $200–$275 למשתמש/חודש על חבילות אבטחה | **גבוהה** |

**תובנה:** ה-MSP הוא הקונה האידיאלי. הוא קונה מהר, רגיש לערך ("הדוח מוכר לי פרויקט של $3K"), ואחד כזה מביא 10–100 דומיינים. הכלים החינמיים (Purple Knight, PingCastle Basic) מוגבלים לשימוש לא מסחרי או לשימוש ידני, וזה פער שמשאיר מקום לכלי זול ש-MSP רשאי להשתמש בו מסחרית.

## 4. הזדמנויות מוצר (פירוט)

### הזדמנות 1 — Legacy Auth Readiness Kit ל-MSP ⭐
- **מה:** סקריפט collector (PowerShell, read-only, רץ אצל הלקוח) שבודק RC4 (מבוסס על הכלי הקיים), שימוש ב-NTLM/NTLMv1 (אירועים 4624, 8001–8004), LDAP signing/channel binding, KDCSVC events ו-krbtgt age. ממנו נוצר **דוח HTML/PDF ממותג ב-white-label** עם ציון, רשימת "מה יישבר" ותוכנית תיקון מתומחרת. בהמשך תתווסף קונסולה רב-לקוחות פשוטה.
- **כאב:** ה-MSP צריך תשובה ללקוח ל-"האם נהיה בסדר כש-Microsoft תכבה NTLM?" וגם מנוע שמייצר פרויקטים.
- **דחיפות:** גבוהה. NTLMv1 נאכף החודש, ו-NTLM-off הוא ה-"RC4 הבא" עם שנה ומעלה של הכנה.
- **מחיר:** Free (דומיין אחד, בלי מיתוג), Pro ב-$49 לחודש (עד 10 לקוחות), MSP ב-$149 לחודש (ללא הגבלה).
- **תחרות:** בינונית. PingCastle for SP יקר ($1,000+ להערכה) וכללי. לפי מה שמצאנו, אף כלי לא ממוקד "מוכנות לשינויי Microsoft".
- **MVP:** 4–6 שבועות (הכלי וההיגיון כבר קיימים, צריך להוסיף NTLM ודוח).

### הזדמנות 2 — NTLM Usage Mapper
- **מה:** איסוף מרוכז של אירועי NTLM מה-DCs, קורלציה למקור/יעד/אפליקציה, והמלצות (SPN חסר, גישה לפי IP, הגדרת Kerberos).
- **קונה:** IT Admin במיד-מרקט. **מחיר:** $500–$2,000 לשנה לדומיין. **תחרות:** ManageEngine, Netwrix, Silverfort (ברמת אנטרפרייז). **MVP:** 6–10 שבועות. מתאים כ"מודול פרימיום" של הזדמנות 1.

### הזדמנות 3 — RC4 Post-Enforcement Fixer
- הכלי הקיים, בתוספת פענוח אירועי KDCSVC ו-4769/0x19, ומדריכים ל-NetApp/SAP/Linux keytabs.
- **דחיפות יורדת:** אחרי יולי 2026 רוב הארגונים כבר תיקנו או הוסיפו חריגים. קיימים כלים חינמיים טובים (RC4-ADAssessment ב-PowerShell Gallery, BetaHydri/RC4_AD_Check) ומדריך רשמי של Microsoft. **שימוש מומלץ:** תוכן ו-lead magnet בקוד פתוח, לא מוצר בתשלום.

### הזדמנות 4 — Compliance Evidence Pack
- מיפוי ממצאים ל-CIS Benchmarks, NIS2, ISO 27001 A.8 ולשאלוני ביטוח סייבר, עם ייצוא ראיות.
- **מחיר:** $300–$1,500 לשנה. **תחרות:** בינונית-גבוהה (Netwrix, ManageEngine, Vanta/Drata בצד הענן). מתאים כ-upsell להזדמנות 1 בשלב 2.

### הזדמנות 5 — SaaS/Agent ניטור רציף
- שוק צפוף עם שחקנים ממומנים (Semperis, Tenable Identity Exposure, Netwrix 1Secure, Microsoft Defender for Identity שמגיע ב-E5). דורש agent, אבטחת backend ואמון. **לא מתאים** לצוות זעיר בשלב זה.

## 5. ההמלצה: הזדמנות 1

**Legacy Auth Readiness Kit ל-MSPs**, בדגם open-core:
1. **יתרון לא הוגן קיים:** קוד עובד, מומחיות מוכחת ב-RC4/Kerberos, והתוספת ל-NTLM היא הרחבה טבעית של אותה מומחיות.
2. **תזמון:** RC4 הוכיח את הדפוס (Audit → Enforcement → בלי rollback). NTLM נמצא עכשיו בתחילת אותו מסלול, ו-NTLMv1 נאכף החודש. נכנסים לשוק לפני הגל, לא אחריו.
3. **ערוץ שמתאים לתקציב אפס:** MSPs נמצאים בקהילות (r/msp, r/sysadmin, MSPGeek, Discord), קונים בכרטיס אשראי ומכפילים את ההפצה. בלי מכירה לאנטרפרייז.
4. **סיכון טכני ומשפטי נמוך:** collector שרק קורא נתונים, בלי לאחסן נתוני לקוח בענן ב-MVP. אין צורך ב-SOC 2 בשלב ראשון.
5. **משפך:** הכלי הנוכחי כקוד פתוח ב-GitHub ובפוסטים ("RC4 broke after July? here's why") מוביל לגרסת Free של ה-Kit, ומשם לשדרוג ל-Pro/MSP.

**סיכונים:** Microsoft עשויה לדחות את NTLM-off (כבר נדחה בעבר). Purple Knight או PingCastle עשויים להוסיף בדיקות NTLM-readiness בחינם. ייתכן ש-MSPs יעדיפו כלים מוכרים. **מיתון:** להתמקד בדוח שמוכר פרויקט (ערך עסקי), לא רק בבדיקות. לאמת עם 10 MSPs לפני כתיבת קוד.

---

## מקורות
- Microsoft — Windows message center (RC4 July 2026, NTLMv1 Oct 2026): https://learn.microsoft.com/windows/release-health/windows-message-center
- Microsoft KB5073381 / CVE-2026-20833: https://support.microsoft.com/topic/1ebcda33-720a-4da8-93c1-b0496e1910dc
- Detect and remediate RC4 usage in Kerberos: https://learn.microsoft.com/windows-server/security/kerberos/detect-remediate-rc4-kerberos
- Entra Domain Services RC4 timeline: https://learn.microsoft.com/entra/identity/domain-services/secure-your-domain ; https://learn.microsoft.com/entra/identity/domain-services/rc4-deprecation-advance-dependency-test
- KB5066470 (NTLMv1): https://support.microsoft.com/help/5066470
- Advancing Windows security: Disabling NTLM by default: https://techcommunity.microsoft.com/blog/windows-itpro-blog/advancing-windows-security-disabling-ntlm-by-default/4489526
- Deprecated features (NTLM): https://learn.microsoft.com/windows/whats-new/deprecated-features
- Policy CSP – NTLM: https://learn.microsoft.com/windows/client-management/mdm/policy-csp-ntlm
- SecurityWeek – Microsoft moves closer to disabling NTLM: https://www.securityweek.com/microsoft-moves-closer-to-disabling-ntlm/
- LDAP signing: https://learn.microsoft.com/windows-server/identity/ad-ds/ldap-signing ; https://trustedsec.com/blog/ldap-channel-binding-and-ldap-signing
- RC4 enforcement impact: https://falconinternet.net/blog/july-2026-patch-tuesday-kerberos-rc4-breaking-change ; https://onapsis.com/blog/kerberos-rc4-deprecation-sap-sso/ ; https://kb.netapp.com/on-prem/ontap/da/NAS/NAS-KBs/ONTAP_Guidance_for_Microsoft_Security_Update_KB5073381_(CVE%E2%80%912026%E2%80%9120833)
- ITDR market: https://www.mordorintelligence.com/industry-reports/identity-threat-detection-and-response-itdr-market ; https://www.marketsandmarkets.com/PressReleases/identity-threat-detection-and-response-itdr.asp
- ISPM market: https://marketsandmarkets.com/PressReleases/identity-security-posture-management.asp
- AD security market: https://www.mordorintelligence.com/industry-reports/active-directory-security-market ; https://www.htfmarketintelligence.com/report/global-active-directory-management-market
- AD usage / attacks: https://www.sentinelone.com/blog/ema-research-active-directory-under-attack/ ; https://www.crowdstrike.com/blog/attackers-set-sights-on-active-directory-understanding-your-identity-exposure/
- PingCastle pricing: https://pingcastle.com/purchase/ ; https://backend.pingcastle.com/
- Purple Knight (free): https://semperis.com/purple-knight/faq/
- ADAudit Plus pricing: https://www.manageengine.com/products/active-directory-audit/pricing-details.html
- N-able MSP pricing guide: https://www.n-able.com/blog/msp-pricing-guide
- Competing free RC4 tools: https://github.com/BetaHydri/RC4_AD_Check ; https://www.powershellgallery.com/packages/RC4-ADAssessment/4.17.0
