# PRD — AuthShift (שם עבודה) · Community MVP v0.1

**מאת:** מנהל מוצר · **תאריך:** 2026-10-21 · **סטטוס:** טיוטה לאישור המנכ"ל
**מבוסס על:** `decisions/001` (מאושר), `research/01–03`, `Manage-KerberosEncryption.ps1`
**אילוצי דירקטוריון:** תקציב 0 · נוכחות ציבורית ב-GitHub בלבד · אסור להכניס לריפו סודות, סיסמאות, טוקנים, נתוני תשלום או נתוני לקוח אמיתיים.
**שוק ושפה:** שוק היעד גלובלי. כל תוכן ציבורי ותוכן מוצר באנגלית: טקסט הדוח, כותרות הבדיקות, פלט ה-CLI, README, issue templates ו-release notes. מסמכים פנימיים תחת `company/` נשארים בעברית.

---

## 1. הבעיה

Microsoft מכבה פרוטוקולי אימות ישנים ב-Active Directory בגלים: אכיפת RC4 הושלמה ביולי 2026 בלי rollback, חסימת NTLMv1-derived credentials נכנסה באוקטובר 2026 (KB5066470), ו-NTLM ברשת צפוי להיחסם כברירת מחדל בגרסת השרת הבאה. בפועל זה יוצר שלושה כאבים:

1. **"חוב RC4" נסתר:** חשבונות שהוגדרו ידנית עם RC4 כ-workaround, `DefaultDomainSupportedEncTypes` עם RC4 על ה-DCs, וחשבונות שירות בלי מפתחות AES.
2. **אי-ודאות לגבי NTLM ו-LDAP:** אין תשובה פשוטה לשאלה "מה יישבר?".
3. **כלים חינמיים רק מאתרים.** תיקון עם rollback קיים רק במוצרי enterprise יקרים, ול-MSP אין דוח שאפשר להגיש ללקוח.

היתרון שלנו: הכלי הקיים כבר מתקן RC4 בבטחה (OS gate, read-back validation, rollback, logging).

## 2. פרסונות

| פרסונה | תיאור | מה חשוב לה |
|---|---|---|
| **P1 — טכנאי MSP ("Alex")** | עובד ב-MSP קטן-בינוני (צפון אמריקה, אירופה, ANZ, ישראל), מנהל 10–50 דומיינים של לקוחות SMB, עובד מרחוק דרך RMM, צריך להצדיק פרויקטים מול הלקוח | הרצה מהירה ובטוחה (read-only), דוח ממותג וברור לאנשים לא טכניים, תוכנית עבודה עם הערכת מאמץ |
| **P2 — מנהל IT ב-SMB ("Dana")** | איש IT יחיד בארגון בכל מקום בעולם, 100–500 משתמשים, 1–3 DCs, בלי תקציב לכלי אבטחה, מחפש פתרונות באנגלית (GitHub, Microsoft Learn) | לדעת מה דחוף, לתקן בלי להשבית את העסק, להחזיר אחורה אם משהו נשבר |

## 3. Jobs-to-be-Done

- **JTBD-1:** כשמגיע עדכון Microsoft שמשנה אימות, אני רוצה לדעת תוך 15 דקות אם הדומיין שלי חשוף, כדי לא לגלות את זה מתקלה בייצור.
- **JTBD-2 (P1):** כשאני פוגש לקוח חדש או בפגישת QBR, אני רוצה דוח מקצועי עם ציון וממצאים מדורגים, כדי למכור פרויקט תיקון.
- **JTBD-3 (P2):** כשאני מתקן הגדרה, אני רוצה גיבוי של המצב הקודם ו-rollback בפקודה אחת, כדי שאוכל לתקן בלי פחד.
- **JTBD-4:** אחרי התיקון אני רוצה דוח "לפני/אחרי" כראיה להנהלה, למבטח הסייבר או למבקר.

## 4. היקף: שכבות המוצר

| יכולת | Community (חינם, MIT) | Pro (בהמשך) | MSP (בהמשך) |
|---|---|---|---|
| Collector read-only + JSON snapshot | ✅ | ✅ | ✅ |
| בדיקות ליבה (סעיף 5, עדיפות P0–P1) | ✅ | ✅ | ✅ |
| דוח HTML עם שדה "Prepared by" טקסטואלי | ✅ | ✅ | ✅ |
| תיקון RC4 + rollback (הכלי הקיים) | ✅ | ✅ | ✅ |
| בדיקות מתקדמות (P2), NTLM Usage Mapper | — | ✅ | ✅ |
| השוואת לפני/אחרי, ייצוא PDF | בסיסי (v0.2) | ✅ | ✅ |
| White-label מלא (לוגו, צבעים, טקסטים) | — | — | ✅ |
| Rollup רב-לקוחות, playbooks לפי התקן | — | — | ✅ |

**הערה:** אין גבייה ואין מנגנון רישוי עד אישור חדש של הדירקטוריון (תקציב 0, אין Stripe). Pro ו-MSP מוגדרים כאן רק כדי לא לחסום אותם ארכיטקטונית. בפועל, v0.1 הוא Community בלבד.

## 5. רשימת בדיקות (ממוינת לפי עדיפות)

התיאורים בטבלה הם תיאורים פנימיים. במוצר, כל בדיקה מקבלת כותרת והסבר באנגלית (למשל AS-KRB-002: "Accounts without Kerberos pre-authentication").

מקרא: **P0** = חובה ב-v0.1 · **P1** = v0.2 · **P2** = v1.0/Pro. **תיקון:** ✅ = תיקון אוטומטי עם גיבוי ו-rollback · 📘 = מדריך בלבד (תיקון ידני, הכלי לא כותב) · — = גילוי בלבד.

| ID | מה מזהה | מקור נתונים | חומרה | תיקון | עדיפות |
|---|---|---|---|---|---|
| AS-RC4-001 | חשבונות (user/computer/gMSA) עם ביט RC4 (0x4) מוגדר במפורש | LDAP `msDS-SupportedEncryptionTypes` | High (Critical אם יש SPN) | ✅ קיים (→0x18, OS gate, rollback) | P0 |
| AS-RC4-002 | DCs שמוגדר בהם `DefaultDomainSupportedEncTypes` שכולל RC4 (למשל 0x24 / 0x1C) | Registry `HKLM\SYSTEM\CurrentControlSet\Services\KDC\DefaultDomainSupportedEncTypes` | High | 📘 | P0 |
| AS-RC4-003 | חשבונות שכנראה חסרים מפתחות AES: `pwdLastSet` מוקדם מ-`whenCreated` של קבוצת Read-only Domain Controllers (RID 521). היוריסטיקה | LDAP `pwdLastSet`, `whenCreated` | High לחשבונות שירות, Medium לאחרים | 📘 (איפוס סיסמה, אין rollback) | P0 |
| AS-RC4-004 | DES פעיל: ביטים 0x1/0x2, או `USE_DES_KEY_ONLY` (0x200000) | LDAP `msDS-SupportedEncryptionTypes`, `userAccountControl` | High | ✅ (v0.2) | P0 (גילוי) |
| AS-RC4-005 | אירועי KDCSVC 201–209 (אזהרות שימוש ב-RC4 אחרי CVE-2026-20833; 205 = תצורת ברירת מחדל לא בטוחה) | Event Log `System`, ספק Kdcsvc, על כל DC | High | — | P0 |
| AS-RC4-006 | חשבונות עם ערך null/0 (נשענים על ברירת המחדל של הדומיין). החומרה תלויה ב-RC4-002: Info אם ברירת המחדל AES בלבד | LDAP + תוצאת RC4-002 | Info / Medium | ✅ קיים | P1 |
| AS-RC4-007 | כרטיסים שהונפקו עם RC4 בפועל (Ticket Encryption Type 0x17) | Security `4768` / `4769` | Medium | — | P1 |
| AS-RC4-008 | Trusts בלי AES | LDAP `trustedDomain` → `msDS-SupportedEncryptionTypes` | Medium | 📘 (`netdom /enableaes`) | P1 |
| AS-NTLM-001 | `LmCompatibilityLevel` מתחת ל-5 על DCs (מתחת ל-3 = Critical) | Registry `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\LmCompatibilityLevel` | High / Critical | 📘 (GPO) | P0 |
| AS-NTLM-002 | שימוש בפועל ב-NTLMv1 (חלון ברירת מחדל: 24 שעות, מוגבל ב-MaxEvents) | Security `4624` עם `LmPackageName = "NTLM V1"` (FilterXPath) | Critical | — | P0 |
| AS-NTLM-003 | Audit של NTLM לא מופעל, ולכן אין נראות למה יישבר | Registry `...\Lsa\MSV1_0\AuditReceivingNTLMTraffic`, `...\Services\Netlogon\Parameters\AuditNTLMInDomain` | Medium | ✅ (v0.2, כתיבת registry עם גיבוי) | P1 |
| AS-NTLM-004 | נפח NTLM ומקורות מובילים (Top N לפי מקור/יעד) | `Microsoft-Windows-NTLM/Operational` 8001–8004 | Medium | — | P1 (סיכום) / P2 (Mapper) |
| AS-NTLM-005 | שמירת LM hash מותרת | Registry `...\Lsa\NoLMHash` ≠ 1 | Medium | 📘 | P1 |
| AS-LDAP-001 | LDAP signing לא נדרש על DC | Registry `HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters\LDAPServerIntegrity` ≠ 2 | High | 📘 | P0 |
| AS-LDAP-002 | Channel binding לא נאכף | Registry `...\NTDS\Parameters\LdapEnforceChannelBinding` (0 = High, 1 = Low) | High / Low | 📘 | P0 |
| AS-LDAP-003 | Binds לא חתומים בפועל | Directory Service `2887` (סיכום יומי). `2889` לפי לקוח, אם diagnostic logging פעיל | Medium | — | P0 (2887) / P1 (2889) |
| AS-KRB-001 | חשבונות user פעילים עם SPN (Kerberoastable). החומרה עולה אם `adminCount=1` או RC4 | LDAP `servicePrincipalName`, `adminCount`, `userAccountControl` | High / Critical | 📘 (gMSA, סיסמה ארוכה) | P0 |
| AS-KRB-002 | AS-REP roastable: `DONT_REQ_PREAUTH` (0x400000) | LDAP `userAccountControl` | High | ✅ (v0.2) | P0 (גילוי) |
| AS-KRB-003 | Unconstrained delegation על חשבון שאינו DC: `TRUSTED_FOR_DELEGATION` (0x80000) | LDAP `userAccountControl`, `primaryGroupID` | Critical | 📘 | P0 |
| AS-KRB-004 | גיל סיסמת krbtgt מעל 180 יום (מעל 365 = High) | LDAP `krbtgt.pwdLastSet` | Medium / High | 📘 (סבב כפול, מדריך Microsoft) | P0 |
| AS-KRB-005 | Constrained delegation עם protocol transition, ו-RBCD | LDAP `msDS-AllowedToDelegateTo`, UAC 0x1000000, `msDS-AllowedToActOnBehalfOfOtherIdentity` | Medium | — | P1 |
| AS-KRB-006 | חשבונות מוגנים (`adminCount=1`) בלי `NOT_DELEGATED` (0x100000) ושלא חברים ב-Protected Users | LDAP `userAccountControl`, `memberOf` | Medium | ✅ (P2) | P2 |

**ב-v0.1 נכנסות 15 בדיקות P0.** בדיקות שמסומנות ✅ (v0.2) רק מאתרות ב-v0.1. התיקון האוטומטי היחיד ב-v0.1 הוא התיקון הקיים של RC4.

## 6. דרישות מוצר וארכיטקטורה

1. **שלושה שלבים מופרדים:** `Collect` (קריאה בלבד מ-AD, registry ו-event logs) → `snapshot.json` עם סכמה ממוספרת גרסה → `Analyze` (פונקציות טהורות, בלי תלות במודול ActiveDirectory) → `Report` (HTML). כך אפשר להריץ Analyze ו-Report על כל מכונה, כולל CI בלי AD.
2. **בדיקות בלי AD אמיתי:** fixtures סינתטיים של snapshot (`*.example`, שמות בדויים) לכל בדיקה, עם מקרה חיובי ומקרה שלילי. ב-Collector משתמשים ב-Pester `Mock` על `Get-ADUser`, `Get-WinEvent` ו-registry.
3. **בטיחות:** Collector לא כותב ל-AD אף פעם. כל כתיבה (בעתיד) מחייבת `-WhatIf`/`-Confirm`, גיבוי JSON של הערך הקודם, read-back ו-rollback מקובץ הגיבוי.
4. **פרטיות:** מתג `-Redact` מחליף שמות חשבונות, hostnames ושם הדומיין ב-hash יציב, כדי שאפשר יהיה לצרף דוח ל-GitHub issue. אין telemetry ואין שליחת נתונים לרשת.
5. **סביבה:** PowerShell 5.1 ו-7.x, RSAT. הרשאות: Domain User מספיק לרוב בדיקות LDAP. Registry ו-event logs של DC דורשים הרשאה מתאימה. בדיקה שלא הצליחה לקרוא נתונים מסומנת `NotAssessed`, לא "תקין".

## 7. דרישות הדוח

- קובץ HTML **יחיד ועצמאי**: CSS inline, בלי CDN ובלי JavaScript חיצוני. נפתח offline, ומודפס יפה ל-PDF מהדפדפן.
- **עמוד מנהלים:** ציון 0–100, ספירה לפי חומרה, 3 הפעולות הדחופות ביותר, ותאריך ומזהה הסריקה.
- **לכל ממצא:** ID, כותרת, חומרה, מה נמצא (מספר אובייקטים ועד 25 דוגמאות, ורשימה מלאה ב-CSV נלווה), למה זה חשוב, מה עלול להישבר בתיקון, צעדי תיקון ו-rollback, הפניה למקור של Microsoft, וסטטוס (`Fail` / `Pass` / `NotAssessed`).
- **"Prepared by / Prepared for"** כשדות טקסט מקובץ config (Community). לוגו וצבעים יתווספו בשכבת MSP.
- **שפת הדוח ופלט ה-CLI: אנגלית בלבד** (שוק גלובלי). כל המחרוזות מרוכזות בקובץ אחד, כדי לשמור על עקביות ולאפשר תרגום בעתיד אם יהיה ביקוש. אין תרגום בתוכנית הנוכחית.
- תאריכים בפורמט ISO 8601 (UTC), בלי תלות ב-locale של המכונה המריצה.
- הציון דטרמיניסטי ומתועד: אותו snapshot תמיד מפיק אותו ציון.

## 8. Non-goals

- אין ניטור רציף, agent או SaaS (החלטה 001).
- אין backend, אין אחסון נתוני לקוח בענן, אין telemetry.
- Entra ID / M365 / Okta לא בהיקף.
- אין תיקון אוטומטי ל-GPO, krbtgt, delegation או איפוס סיסמאות. אלה מדריכים בלבד.
- אין attack-path analysis (BloodHound).
- אין רישוי, תשלום, PowerShell Gallery או ערוצים מחוץ ל-GitHub עד אישור הדירקטוריון.

## 9. מדדי הצלחה (נמדדים ב-GitHub בלבד)

| מדד | מקור | יעד 14 יום מ-v0.1 | יעד 90 יום |
|---|---|---|---|
| Stars | Repo API | ≥ 30 (קריטריון העצירה בהחלטה 001) | ≥ 250 |
| Watchers | Repo API | ≥ 10 | ≥ 40 |
| הורדות release assets | Releases API `download_count` | ≥ 100 | ≥ 1,000 |
| Unique cloners | Traffic API (14 יום) | ≥ 50 | — |
| Issues/Discussions ממשתמשים חיצוניים | Issues API | ≥ 5 | ≥ 30 |
| Issues עם תווית `msp-interest` (בקשות ל-white-label או multi-tenant) | Labels | ≥ 3 | ≥ 15 |
| דוחות שהוגשו מסביבה אמיתית (redacted, תבנית "Field report") | Issue template | ≥ 2 | ≥ 10 |
| False positives מדווחים | תווית `false-positive` | — | פחות מ-1 לכל בדיקה |

## 10. קריטריוני קבלה ל-MVP v0.1

1. `Invoke-AuthShift -OutputPath <dir>` מפיק `snapshot.json`, `report.html` ו-`findings.csv` בהרצה אחת. יש גם אפשרות להריץ `-Collect`, `-Analyze` ו-`-Report` בנפרד.
2. כל 15 בדיקות P0 ממומשות, ולכל אחת יש לפחות fixture חיובי אחד ושלילי אחד ב-Pester. כל הבדיקות עוברות ב-GitHub Actions על `windows-latest` ו-`ubuntu-latest` (Analyze ו-Report).
3. בדיקת Pester מוכיחה שה-Collector לא קורא לאף cmdlet כתיבה (`Set-*`, `New-*`, `Remove-*`, `Restore-*`). המימוש: mock שנכשל אם נקרא.
4. נתון חסר או גישה שנדחתה מסומנים `NotAssessed` עם סיבה. הסריקה לא קורסת.
5. ה-HTML עובר בדיקה שאין בו הפניות חיצוניות (`http(s)://` מחוץ לקישורי reference). הוא נפתח בלי רשת, ומופק תוך פחות מ-5 שניות מ-fixture של 10,000 אובייקטים.
6. `-Redact` מסיר כל שם מ-fixture הבדיקה. מאמתים את זה בבדיקת grep אוטומטית.
7. PSScriptAnalyzer בלי שגיאות. secret scanning של GitHub פעיל. כל ה-fixtures סינתטיים.
8. `Manage-KerberosEncryption.ps1` ממשיך לעבוד כמו היום, והדוח מפנה אליו לתיקון של AS-RC4-001.
9. כל הטקסט שמוצג למשתמש (CLI, דוח, README, templates) באנגלית. בדיקה אוטומטית מוודאת שאין תווים בעברית בקבצי המוצר.
10. Release ב-GitHub עם ZIP, `SHA256SUMS`, CHANGELOG, README עם Quick start, דוח לדוגמה (מ-fixture) ו-issue templates (Bug, False positive, Field report, Feature/MSP).
