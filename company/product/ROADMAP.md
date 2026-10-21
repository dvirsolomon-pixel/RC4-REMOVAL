# ROADMAP — AuthShift (שם עבודה)

**מאת:** מנהל מוצר · **תאריך:** 2026-10-21 · **מבוסס על:** `product/PRD.md`, `decisions/001`
**צוות:** 3 סוכני הנדסה (Architect, Developer, QA/Security). אין AD חי לבדיקות, ולכן כל יכולת נבדקת על fixtures סינתטיים ועל Pester mocks.
**אילוצים:** תקציב 0 (GitHub, GitHub Actions ל-repo ציבורי, GitHub Pages, Discussions) · פרסום ב-GitHub בלבד · תוכן מוצר באנגלית ושוק גלובלי · אין סודות ואין נתוני לקוח בריפו.

## עקרונות
1. **קטן ושחרור מהיר:** v0.1 הוא סורק read-only ודוח. אין בו כתיבה חדשה ל-AD.
2. **Fixtures לפני קוד:** לכל בדיקה יש snapshot סינתטי חיובי ושלילי *לפני* המימוש. סכמת ה-snapshot היא החוזה בין שלושת הסוכנים.
3. **לא שוברים את הקיים:** `Manage-KerberosEncryption.ps1` נשאר עובד. מבצעים בו refactor רק ב-v0.2, ורק מאחורי בדיקות.
4. **ולידציה בשטח דרך הקהילה:** את מה שאי אפשר לבדוק על AD אמיתי מאמתים בדוחות redacted שמשתמשים מגישים (issue template "Field report").

---

## v0.1 — Community MVP · "Legacy Auth Readiness Scan" (שבועות 1–6, יעד: ~2026-12-02)

**היקף:**
- מבנה module: `AuthShift.psd1` עם `Invoke-AuthShift` ושלבי Collect / Analyze / Report.
- `snapshot.json` עם סכמה v1 ממוספרת ותיעוד שדות.
- 15 בדיקות P0 מה-PRD: AS-RC4-001…005, AS-NTLM-001/002, AS-LDAP-001…003, AS-KRB-001…004.
- דוח HTML עצמאי (באנגלית), `findings.csv`, ציון דטרמיניסטי ושדות Prepared by / Prepared for.
- `-Redact`. מצב `NotAssessed` לכל כשל קריאה.
- CI: Pester ו-PSScriptAnalyzer על `windows-latest` (Analyze/Report גם על `ubuntu-latest`), ו-secret scanning.
- Release: ZIP, `SHA256SUMS`, דוח לדוגמה מ-fixture, README Quick start ו-issue templates.

| שבוע | Architect | Developer | QA/Security |
|---|---|---|---|
| 1 | סכמת snapshot v1, מבנה module, ADR קצר | שלד `Invoke-AuthShift`, CI | מחולל fixtures סינתטי (`contoso.example`) |
| 2 | מודל ממצאים ונוסחת ציון | Collector ל-LDAP (בדיקות RC4/KRB) | fixtures חיוביים ושליליים לבדיקות LDAP |
| 3 | חוזה Collector ל-registry ו-events | Collector ל-registry ו-event logs (NTLM/LDAP/KDCSVC) | Mocks ל-`Get-WinEvent` ו-registry, בדיקת "אין cmdlet כתיבה" |
| 4 | תבנית HTML ומחרוזות באנגלית | Analyzer ל-15 הבדיקות | בדיקות `NotAssessed`, ביצועים (10K אובייקטים) |
| 5 | סקירת קוד וסכמה | Report, CSV, `-Redact` | בדיקת redaction, בדיקת "אין הפניות חיצוניות", בדיקת "אין עברית" |
| 6 | release notes, תיעוד | תיקוני באגים | בדיקת קבלה מלאה לפי PRD §10, release candidate |

**קריטריוני יציאה:**
- כל 10 קריטריוני הקבלה ב-PRD §10 עומדים, ו-CI ירוק על ה-tag.
- אין באגים פתוחים בחומרת High ומעלה.
- דוח לדוגמה ו-snapshot לדוגמה מצורפים ל-release, וכולם סינתטיים.
- המנכ"ל אישר את ה-release.

**מדידה אחרי השחרור (14 יום):** ≥30 stars ו-≥100 הורדות (קריטריון העצירה של החלטה 001). אם המספרים לא מושגים, עוצרים ומחזירים את ההחלטה לדירקטוריון לפני v0.2.

---

## v0.2 — "Safe Fix" (שבועות 7–12)

**היקף:**
- **Remediation framework** אחיד: `-WhatIf` / `-Confirm`, גיבוי JSON לפני כל כתיבה, read-back ו-`Undo-AuthShiftChange -BackupFile`. מסבים אליו את תיקון ה-RC4 הקיים, עם כיסוי בדיקות לפני ה-refactor.
- תיקונים חדשים עם rollback: AS-RC4-004 (DES), AS-KRB-002 (pre-auth), AS-NTLM-003 (הפעלת NTLM audit ב-registry).
- בדיקות P1: AS-RC4-006/007/008, AS-NTLM-003/004 (סיכום Top N)/005, AS-LDAP-003 (2889), AS-KRB-005.
- **השוואת לפני/אחרי:** `Compare-AuthShiftSnapshot` ודוח delta.
- עדכונים לפי משוב ה-issues והדוחות מהשטח מ-v0.1.

**קריטריוני יציאה:**
- כל פעולת תיקון מכוסה ב-Pester: גיבוי, כתיבה מדומה, read-back, rollback, ו-rollback אחרי כשל חלקי.
- `-WhatIf` הוא ברירת מחדל בתיעוד, ואף תיקון לא רץ בלי אישור מפורש.
- לפחות 2 Field reports מסביבות אמיתיות אישרו שאין false positives בבדיקות P0, או ששיעור ה-false positives פחות מ-1 לבדיקה ותוקן.
- התאימות לאחור של סכמת snapshot v1 נשמרה (קורא v1 ו-v2).

---

## v1.0 — "MSP-ready" (שבועות 13–20, יעד: רבעון 1 2027)

**היקף:**
- סכמת snapshot ו-API ציבורי יציבים (SemVer, מדיניות deprecation).
- **MSP foundations:** תיקיית ריבוי לקוחות (snapshot לכל לקוח), rollup HTML עם טבלת ציונים, ו-theme config (לוגו מקומי וצבעים). השאלה אם היכולות האלה חינמיות או בתשלום תוכרע בהחלטה נפרדת של הדירקטוריון.
- בדיקות P2: AS-KRB-006 (כולל תיקון NOT_DELEGATED עם rollback), ו-NTLM Usage Mapper בגרסה ראשונית (קורלציית 8004 לפי מקור/יעד).
- Playbooks באנגלית לפי התקן (Synology, QNAP, NetApp, Linux keytab, SQL, ADFS) ב-GitHub Pages.
- תיעוד מלא ב-GitHub Pages: מדריך לכל check ID, FAQ ומדיניות אבטחה (`SECURITY.md`).

**קריטריוני יציאה:**
- ≥10 Field reports מסביבות אמיתיות. אין באג High פתוח.
- כל check ID מתועד ב-Pages, עם מקור Microsoft ודרך תיקון.
- Rollup נבדק על fixture של 25 לקוחות סינתטיים.
- יעדי 90 יום מה-PRD §9 הושגו (≥250 stars, ≥1,000 הורדות, ≥15 issues עם `msp-interest`), או שהוחלט במפורש על שינוי כיוון.
- הוגשה לדירקטוריון החלטה 002: תמחור ושכבות Pro/MSP, וערוצי הפצה נוספים (PowerShell Gallery, קהילות).

---

## סיכונים ומענה
| סיכון | מענה |
|---|---|
| אין AD חי, ולכן יהיו false positives בשטח | fixtures מבוססי תיעוד Microsoft, `NotAssessed` במקום ניחוש, תווית `false-positive` ותיקון מהיר |
| קריאת Security log גדול איטית | FilterXPath, חלון זמן ו-MaxEvents. האיסוף אופציונלי (`-SkipEvents`) |
| היוריסטיקת מפתחות AES (AS-RC4-003) לא מדויקת | מסומנת בדוח כ-"likely", עם הסבר ודרך אימות (`List-AccountKeys.ps1` של Microsoft) |
| כלים חינמיים יוסיפו בדיקות NTLM | הבידול שלנו: תיקון ו-rollback, דוח לפני/אחרי, ופוקוס MSP |
