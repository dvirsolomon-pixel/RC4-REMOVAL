# מיתוג — בחירת שם למוצר

**מאת:** מנהל השיווק · **תאריך:** 2026-10-21 · **סטטוס:** המלצה, ממתינה לאישור המנכ"ל והדירקטוריון
**מבוסס על:** `decisions/001-product-recommendation.md`, `research/01–03`

---

## שורה תחתונה

**ההמלצה: KerbShift.** חלופה שנייה: AuthShift (שם העבודה הנוכחי).

- **KerbShift** הוא השם היחיד מבין החמישה שלא מצאנו לו אף התנגשות: לא ב-GitHub ולא בחיפוש רשת.
- הוא מספר את הסיפור של המוצר במילה אחת. בתוך Kerberos עוברים מ-RC4 ל-AES. מחוץ ל-Kerberos עוברים מ-NTLM ל-Kerberos. זה בדיוק הכיוון ש-Microsoft מכתיבה (IAKerb, Local KDC, NTLM כבוי כברירת מחדל).
- **AuthShift** הוא שם טוב, אבל כבר יש ב-GitHub ארבעה ריפואים בשם הזה, אחד מהם עם אתר GitHub Pages. בנוסף, יש מוצר אבטחת אימות מסחרי בשם דומה מאוד (AuthShield). מאחר ש-GitHub הוא ערוץ ההפצה **היחיד** שלנו, חיפוש ב-GitHub שמחזיר פרויקטים זרים הוא בעיה ממשית.

---

## קריטריונים

| קריטריון | למה הוא חשוב לנו |
|---|---|
| **ייחודיות ב-GitHub** | GitHub הוא הערוץ היחיד (החלטת הדירקטוריון). חיפוש בשם צריך להחזיר אותנו ראשונים. |
| **ייחודיות ברשת ובסימני מסחר** | לא להיתקל בתלונה, ולא להתבלבל עם ספק אבטחה קיים. |
| **מתאר את התחום** | מנהל IT או טכנאי MSP צריך להבין תוך שנייה שזה קשור ל-AD/Kerberos/אימות. |
| **מחזיק לאורך זמן** | RC4 הוא רק ההתחלה. השם צריך להתאים גם ל-NTLM, LDAP signing ו-Pro/MSP. |
| **קל לבטא ולהקליד** | שם שעובר בשיחה בין טכנאים ובשורת פקודה (`Invoke-KerbShift`, `kerbshift-report.html`). |
| **טון** | מקצועי ובטוח. לא מפחיד ולא "האקרי". |

---

## הבדיקה — מה מצאנו (21/10/2026)

שיטה: חיפוש רשת (WebSearch) לכל שם, וחיפוש ריפואים ב-GitHub לפי שם (`in:name`). **זו בדיקה ראשונית בלבד**, לא חיפוש במאגרי סימני מסחר (USPTO/EUIPO/WIPO). לפני השקעה בלוגו או ברישום צריך לחפש שם ישירות. התוכן של הריפואים הזרים לא נבדק לעומק: הגישה של הסשן מוגבלת לריפו שלנו.

| שם | GitHub (`in:name`) | חיפוש רשת | התנגשות |
|---|---|---|---|
| **AuthShift** (שם עבודה) | **4 ריפואים**: `prosubodh/authshift`, `muhsinagowth/authshift`, `muhsinagowth/authshift-sandbox`, `yessur3808/AuthShift` (עם GitHub Pages). כולם ב-TypeScript, כמעט בלי כוכבים, נוצרו ב-2026 | לא נמצא מוצר או סימן מסחר בשם הזה. התוצאה הקרובה היא **AuthShield** של Innefu Labs, מוצר MFA מסחרי | **בינונית.** אין סימן מסחר ידוע, אבל ה-namespace ב-GitHub תפוס חלקית, ויש דמיון לשם של מוצר אבטחת אימות |
| **KerbShift** | **0 ריפואים** | אין תוצאות. כלי ה-Kerberos המוכרים הם Rubeus, Kekeo, OSKT, ktpass | **לא נמצאה** |
| **AuthSweep** | **1 ריפו**: `Unchained-Labs/authsweep`, כלי SAST שמחפש route handlers בלי בדיקת הרשאה (תגיות: security, authorization) | אין מוצר בשם הזה. יש הרבה "Sweep" באבטחה (AppSweep של Guardsquare, GhostSweep, Sweep ל-Salesforce) | **בינונית-גבוהה.** כלי אבטחה באותו שם בדיוק ב-GitHub |
| **LegacyLift** | **35 ריפואים** | LegacyLift AI של Netcetera (מודרניזציה לבנקים), כמה פרויקטים אקדמיים ו-hackathon, ספק בשם LegacyLift (מוצר LegacyLeaps) | **גבוהה.** שם רווי, ומזוהה עם מודרניזציית קוד ולא עם אבטחה |
| **AuthDebt** | **0 ריפואים** | אין תוצאות | **לא נמצאה**, אבל ראו את החסרונות למטה |

> שם נוסף שנבדק ונפסל מוקדם: **ADReady**. יש 12 ריפואים בשם (רובם "AdReady" לפרסום) ומספר כלי "AD Readiness Assessment" קיימים (Simplicity ב-Microsoft Marketplace, Silverfort). גנרי מדי.

---

## ניתוח לכל שם

### 1. AuthShift (שם העבודה)
- **בעד:** קצר ומודרני. מכסה את כל סוגי האימות (RC4, NTLM, LDAP). כבר מופיע במסמכי החברה.
- **נגד:** ארבעה ריפואים זרים בשם זהה ב-GitHub. "Auth" מתקשר בעיקר לאימות באפליקציות web (OAuth, Auth0, Clerk), ופחות ל-Active Directory, ולכן כנראה רוב הריפואים הקיימים הם ספריות אימות ב-TypeScript. יש דמיון ל-AuthShield.
- **ציון:** 3.5/5

### 2. KerbShift ⭐ מומלץ
- **בעד:** אין שום התנגשות שמצאנו. "Kerb" הוא קיצור שמנהלי AD משתמשים בו כל יום (klist, krbtgt, "kerb tickets"), כך שהקהל מזהה מיד את התחום. השם מתאר את המהלך כולו: RC4 → AES, NTLM → Kerberos. פקודות טבעיות: `Invoke-KerbShiftAudit`, `kerbshift-report.html`.
- **נגד:** LDAP signing לא נמצא בתוך המילה. **מענה:** שורת המשנה תכסה את זה: *"Legacy-auth readiness & safe remediation for Active Directory"*. מי שמחפש פתרון ל-NTLM מבין ש-Microsoft דוחפת אותו ל-Kerberos.
- **ציון:** 4.5/5

### 3. AuthSweep
- **בעד:** "Sweep" משדר ניקוי, וזה מתאים ל"ניקוי אחרי אכיפת RC4".
- **נגד:** כלי אבטחה פעיל ב-GitHub באותו שם בדיוק. "Sweep" משדר גם סריקה בלבד, בעוד שהבידול שלנו הוא תיקון בטוח עם rollback.
- **ציון:** 2.5/5

### 4. LegacyLift
- **בעד:** "Legacy" מדויק לבעיה.
- **נגד:** שם רווי (35 ריפואים, מוצר מסחרי של Netcetera, ספק תוכנה בשם זה). מזוהה עם מודרניזציית קוד ו-AI, לא עם AD.
- **ציון:** 1.5/5

### 5. AuthDebt
- **בעד:** ייחודי לגמרי. מתחבר ישירות לרעיון "חוב RC4 נסתר" מהמחקר (`research/03`).
- **נגד:** "Debt" שלילי ומפחיד. קשה לבנות סביבו מותג חיובי (אף אחד לא רוצה "להתקין חוב"). מתאים יותר **כשם לבדיקה או לפרק בדוח** ("Auth Debt Score") מאשר כשם למוצר.
- **ציון:** 2.5/5 כשם מוצר. **מומלץ לאמץ את המונח "Auth Debt" כמונח שיווקי בתוך המוצר.**

---

## טבלת ניקוד מסכמת (1–5)

| שם | ייחודיות GitHub | ייחודיות רשת/TM | מתאר תחום | מחזיק לאורך זמן | הגייה/הקלדה | טון | **סה"כ /30** |
|---|---|---|---|---|---|---|---|
| **KerbShift** | 5 | 5 | 5 | 4 | 5 | 5 | **29** |
| AuthShift | 2 | 4 | 3 | 5 | 5 | 5 | **24** |
| AuthDebt | 5 | 5 | 3 | 4 | 4 | 2 | **23** |
| AuthSweep | 2 | 3 | 3 | 3 | 5 | 4 | **20** |
| LegacyLift | 1 | 1 | 2 | 4 | 5 | 4 | **17** |

---

## ההמלצה ויישום

1. **שם המוצר: KerbShift.** שורת משנה: *Legacy-auth readiness & safe remediation for Active Directory.*
2. **מהדורות:** KerbShift Community (חינם, MIT), KerbShift Pro (מתוכנן), KerbShift MSP (מתוכנן).
3. **ריפו:** בשלב הזה **לא משנים את שם הריפו** `RC4-REMOVAL`. יש לו כבר URL קיים, והוא מכיל מילת חיפוש חשובה (RC4). אחרי שהשם יאושר אפשר לשנות ל-`KerbShift`: GitHub מפנה אוטומטית קישורים ו-clones מהשם הישן. ההחלטה תתקבל לפי נתוני traffic.
4. **מונח שיווקי:** "Auth Debt" ישמש בתוכן ובדוח ("Your Auth Debt score").
5. **לפני השקעה במיתוג** (לוגו וכו', גם אם בחינם): חיפוש ידני ב-USPTO TESS / EUIPO eSearch / WIPO Global Brand Database עבור "KERBSHIFT" ו-"AUTHSHIFT". זה לא נעשה בבדיקה הזו.
6. **אם הדירקטוריון מעדיף להישאר עם AuthShift:** אפשרי. במקרה כזה להשתמש תמיד בצירוף "AuthShift for Active Directory" כדי להבדיל מהריפואים הקיימים.

> הערה: דף הנחיתה (`docs/index.html`) וטיוטת ה-README (`company/marketing/README-DRAFT.md`) כתובים עם השם **KerbShift**. אם יוחלט אחרת, מספיק להחליף את המחרוזת בשני הקבצים.

---

## מקורות
- GitHub repository search (`in:name`) for authshift / kerbshift / authsweep / legacylift / authdebt / adready, 21/10/2026
- [AuthShield (Innefu) — App Store](https://apps.apple.com/us/app/id1366545398)
- [Unchained-Labs/authsweep](https://github.com/Unchained-Labs/authsweep)
- [LegacyLift AI — Netcetera](https://www.netcetera.com/artificial-intelligence/legacylift-ai.html)
- [LegacyLeaps — Capterra](https://www.capterra.co.nz/software/1096805/LegacyLeaps)
- [Simplicity AD Readiness Assessment — Microsoft Marketplace](https://marketplace.microsoft.com/en-us/product/simplicityitinc1734733403274.ad-readiness-assessment)
- [Rubeus — SpecterOps](https://specterops.io/open-source-tools/rubeus) · [OSKT](https://oskt.secure-endpoints.com)
