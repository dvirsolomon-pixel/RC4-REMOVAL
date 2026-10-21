# AuthShift — ארכיטקטורה הנדסית (v0.1)

**מאת:** ארכיטקט התוכנה · **תאריך:** 2026-10-21 · **סטטוס:** טיוטה לאישור המנכ"ל
**מבוסס על:** `decisions/001-product-recommendation.md` (מאושר), `Manage-KerberosEncryption.ps1`, `README.md`

**מגבלות מחייבות:** תקציב 0, GitHub בלבד, אין סודות בריפו, למהנדסים (סוכני AI) **אין Active Directory חי**, ונדרשת תאימות ל-PowerShell 5.1, כי לקוחות מריצים את הכלי על DC.

---

## 1. הערכת הסקריפט הקיים

`Manage-KerberosEncryption.ps1` (כ-1,400 שורות) הוא כלי עובד ומוקפד, ובנוי כמונולית שמונע על ידי תפריט.

### מה שומרים (הלוגיקה עצמה טובה)
| רכיב | למה |
|---|---|
| `Get-EncryptionLabel`, `Test-HasRC4Risk` | פענוח bitmask נכון לפי MS-KILE. ערך 0 או null נחשב סיכון. אלה פונקציות טהורות שקל לבדוק. |
| `Test-ComputerAESCompatible` | שער OS שמחזיר "לא תואם" כברירת מחדל. זה בדיוק הלך הרוח הנכון למוצר. |
| `Get-ADEncValidation` | קריאה חוזרת מ-AD אחרי כל כתיבה (Get-ADUser/Get-ADComputer ולא Get-ADObject). זה ידע שנצבר מניסיון. |
| `Set-ADEncryptionTypeRaw` | ההבחנה בין `-Add` לבין `-Replace` כשהתכונה ריקה. |
| ערך יעד 24 (ולא 56) | החלטה שמרנית ומתועדת היטב. |
| אישור `[y/N]` לפני כתיבה, טבלת סיכום אחרי פעולה גורפת, הפניה ל-KB | חוויית בטיחות שמשתמשים כבר מכירים. |

### מה מבצעים refactor (חוב טכני ופערי בטיחות)
1. **אי אפשר לבדוק את הסקריפט.** `#Requires -Modules ActiveDirectory` והלולאה הראשית רצים כבר בטעינת הקובץ, ולכן אי אפשר לטעון אותו עם dot-source ב-Pester. בנוסף, כל פונקציה קוראת ל-`Get-AD*` ישירות, ואין שכבת גישה לנתונים שאפשר להחליף ב-mock.
2. **Rollback לא אמיתי.** `Restore-RC4` מוסיף את ביט ה-RC4 לערך הנוכחי (24 הופך ל-28) ולא משחזר את הערך המקורי (למשל null או 0). אין גם journal של המצב הקודם. זה הפער החמור ביותר מול ההבטחה השיווקית "תיקון + rollback".
3. **אובדן ביטים.** `-KerberosEncryptionType 'AES128,AES256'` דורס את כל הערך. ביטים קיימים כמו AES256-SK (0x20) ודגלי FAST/Claims (0x1000–0x8000) עלולים להימחק. היעד הנכון: `(current -band -bnot (RC4|DES)) -bor 24`. **לאמת במעבדה של בודק בטא**, כי לנו אין AD.
4. **בדיקה גורפת של משתמשים בלי שער.** אין בדיקה של `PasswordLastSet` מול מועד המעבר ל-DFL 2008 (חשבון בלי מפתחות AES), ואין טיפול מיוחד בחשבונות שירות עם SPN. במחשבים יש שער OS, במשתמשים אין שום שער.
5. **אין `-WhatIf` ואין `SupportsShouldProcess`.** הבטיחות נשענת על `Read-Host` בלבד, ולכן אי אפשר להריץ את הכלי באוטומציה.
6. **Read-back בלי `-Server`.** הכתיבה והקריאה יכולות להגיע ל-DC שונים, וזה יוצר MISMATCH מדומה בגלל השהיית רפליקציה. צריך לקבע DC אחד לכל ריצה.
7. **הלוג כבוי כברירת מחדל**, וכל הפלט נכתב ב-`Write-Host`, כלומר הפונקציות לא מחזירות אובייקטים ל-pipeline.
8. **כפילות קוד** בין מחשב למשתמש בכל זוג פונקציות (3/4, 5/6, 7/8, 10/11).
9. **הערה שסותרת את הקוד:** הכותרת של `Test-ComputerAESCompatible` אומרת שגרסה null נחשבת תואמת, והקוד מחזיר לא תואם. הקוד נכון, ויש לתקן את ההערה.

### תאימות לאחור
- `Manage-KerberosEncryption.ps1` **נשאר בשורש הריפו עם אותו שם, אותו תפריט ואותם מספרי אפשרויות (1–11)**. משתמשים קיימים, קישורים ומדריכים לא נשברים.
- בגרסה v0.1 הוא הופך ל-**shim דק**: הוא טוען את `src/AuthShift/AuthShift.psd1` מהנתיב היחסי, והתפריט קורא לפונקציות הציבוריות של המודול. אם המודול לא נמצא, למשל כשמישהו הוריד רק את הקובץ הבודד, הסקריפט מציג הודעה ברורה. בנוסף נשמר עותק קפוא של הגרסה הנוכחית בנתיב `legacy/Manage-KerberosEncryption.v1.ps1`, כדי שתהיה דרך חזרה.
- מבחני regression ייעודיים (`tests/Compat.Tests.ps1`) מוודאים שלכל אפשרות בתפריט יש פונקציה מתאימה, ושפורמט שורת הלוג (`yyyy-MM-dd HH:mm:ss  [LEVEL]  ...`) ועמודות ה-CSV לא השתנו.
- שינויי התנהגות (rollback לערך המקורי, שמירה על ביטים) מתועדים ב-`CHANGELOG.md` כ-"behavior fix" ולא כשינוי שובר.

---

## 2. מבנה היעד — מודול PowerShell

```
src/AuthShift/
  AuthShift.psd1            # manifest: PowerShellVersion='5.1', CompatiblePSEditions=Desktop,Core
  AuthShift.psm1            # dot-source של Private/*, Public/*, Checks/*; Export-ModuleMember מה-psd1
  Public/                   # Invoke-AuthShiftScan, New-AuthShiftReport, Invoke-AuthShiftRemediation,
                            # Undo-AuthShiftRemediation, Get-AuthShiftCheck, Start-AuthShiftMenu
  Private/
    Collector/              # Get-ASDirectoryData, ADCollector.ps1, FixtureCollector.ps1
    Core/                   # New-ASFinding, EncTypes.ps1 (קבועים + Get-EncryptionLabel), Write-ASLog
    Remediation/            # Journal.ps1, Fixers/*.ps1
    Report/                 # ConvertTo-ASHtml, template.html, report.css (מוטמעים בזמן ריצה)
  Checks/                   # קובץ אחד לכל check (ראו 2.2)
  Config/default.config.psd1
tests/  (Unit/, Checks/, Fixtures/*.json, Compat.Tests.ps1)
build/  (Invoke-Build.ps1 — lint + tests + packaging zip ל-Release)
```

**שפה:** השוק גלובלי, ולכן כל מה שהמשתמש רואה כתוב באנגלית בלבד: פלט CLI, HTML של הדוח, `Title` ו-`Remediation` של checks, הערות בקוד, README ו-docs. רק מסמכי `company/` נכתבים בעברית. בדיקת CI מוודאת שאין תווים עבריים (`[\u0590-\u05FF]`) בקבצים תחת `src/`, `tests/` ו-`docs/`.

**כללי PS 5.1:** לא משתמשים ב-`??`, `?.`, ternary, `ForEach-Object -Parallel` או `ConvertFrom-Json -AsHashtable`. קבצים נשמרים כ-UTF-8 **עם BOM**, כי בלי BOM PS 5.1 שובר את תווי ה-box-drawing ותווים אחרים שאינם ASCII. `ActiveDirectory` **לא** מופיע ב-`RequiredModules`; הוא נטען רק בתוך `ADCollector`.

### 2.1 שכבת Collector (גישה לנתונים)
כל קריאה מ-AD עוברת דרך collector אחד. ה-checks אף פעם לא קוראים ל-`Get-AD*`.

```powershell
# Snapshot יחיד ומנורמל, שכל ה-checks צורכים
$data = Get-ASDirectoryData -Source AD -Server dc01      # ריצה אמיתית (read-only)
$data = Get-ASDirectoryData -Source Fixture -Path tests/Fixtures/small-msp.json
```
- ה-snapshot הוא `PSCustomObject` עם `Domain`, `DomainControllers`, `Users`, `Computers`, `Trusts`, `Krbtgt`, `Gpo` (ערכי registry רלוונטיים: `LmCompatibilityLevel`, `LDAPServerIntegrity`, `LdapEnforceChannelBinding`, `DefaultDomainSupportedEncTypes`) ו-`Events` (סיכומי 4768/4769/4776/2889/205 מ-DC, אופציונלי).
- `ADCollector` מתרגם אובייקטי `Microsoft.ActiveDirectory.Management.*` לשדות פשוטים (מחרוזות, מספרים, תאריכים ISO). ככה ה-snapshot ניתן לסריאליזציה ל-JSON, ואותו פורמט משמש גם את ה-fixtures.
- `Export-ASSnapshot -Anonymize` מאפשר ללקוח בטא לשלוח לנו snapshot אמיתי עם hash לשמות. זה הופך ל-fixture חדש, וזו הדרך היחידה שלנו לראות AD אמיתי.
- ה-collector גם רושם בדיקת יכולות: אילו נתונים לא נאספו בגלל הרשאות. במקרה כזה check מחזיר `Severity=Info` עם "Not assessed", ולא "תקין".

### 2.2 חוזה ה-Check
כל check הוא פונקציה בקובץ משלה ב-`Checks/`, עם metadata סטטי:

```powershell
function Test-ASRc4AccountsNotConfigured {
    [AuthShiftCheck(Id='AS-RC4-001', Category='Kerberos', Edition='Community')]  # מיושם כ-hashtable $Meta בגלל PS 5.1
    param([Parameter(Mandatory)][psobject]$Data, [hashtable]$Config)
    foreach ($u in $Data.Users | Where-Object { Test-HasRC4Risk $_.SupportedEncTypes }) {
        New-ASFinding -CheckId 'AS-RC4-001' -Title 'Account relies on RC4/unset enctypes' `
            -Severity High -Target $u.DistinguishedName `
            -Evidence @{ SupportedEncTypes = $u.SupportedEncTypes; PasswordLastSet = $u.PasswordLastSet } `
            -Remediation 'Set AES128+AES256 (24); reset password if no AES keys' `
            -CanAutoFix $true -FixId 'Fix-ASEncTypeAes'
    }
}
```
**אובייקט Finding (סכמה v1, `PSTypeName='AuthShift.Finding'`):** `Id` (מזהה יציב: CheckId + hash של Target), `CheckId`, `Title`, `Severity` (Critical/High/Medium/Low/Info), `Category`, `Target`, `Evidence` (hashtable), `Remediation` (טקסט + `References`), `CanAutoFix`, `FixId`, `Edition`.
- check הוא **פונקציה טהורה**: מקבל snapshot ומחזיר findings, בלי I/O ובלי כתיבה. זה מה שמאפשר לבדוק כל check מול JSON.
- גילוי checks: `Get-AuthShiftCheck` סורק את `Checks/` לפי `$Meta`. Pro ו-MSP יוסיפו checks מתיקייה נוספת עם אותו חוזה, בלי לשנות את הליבה.
- checks ל-v0.1 (Community): AS-RC4-001…005 (null/RC4 במשתמשים ובמחשבים, ערך 0x24 ידני, חשבונות בלי מפתחות AES לפי PasswordLastSet, Event 205, `DefaultDomainSupportedEncTypes`), AS-KRB-001 (גיל סיסמת krbtgt), AS-KRB-002 (משתמשים עם SPN = מועמדים ל-Kerberoasting), AS-NTLM-001 (`LmCompatibilityLevel` < 5), AS-LDAP-001/002 (LDAP signing ו-channel binding לא נאכפים).

### 2.3 מנוע הדוחות
- `New-AuthShiftReport -Findings $f -Snapshot $s -Config $c -Path out.html` מפיק **קובץ HTML יחיד ועצמאי**: ה-CSS, ה-JS המינימלי (סינון ומיון) והלוגו כ-base64 מוטמעים בקובץ. אין CDN ואין גישה לרשת, כי הדוח נפתח גם ברשתות מבודדות.
- תבנית עם placeholders (`{{Org.Name}}`, `{{Brand.PrimaryColor}}`), שמוחלפים ב-`[System.Net.WebUtility]::HtmlEncode` על **כל** ערך שמגיע מ-AD. שמות אובייקטים ב-AD הם קלט לא מהימן, ובלי קידוד יש סכנת XSS.
- white-label דרך `authshift.config.psd1`: `Brand.Name`, `Brand.LogoPath`, `Brand.PrimaryColor`, `Brand.Footer`, `Client.Name`. **כל המחרוזות בדוח באנגלית בלבד** (שוק גלובלי). אין i18n ב-v0.1, אבל המחרוזות מרוכזות ב-`Report/strings.en.psd1` כדי לאפשר תרגום בעתיד. ב-Community יופיע footer "Generated by AuthShift Community". הסרתו היא פיצ'ר MSP, ונאכפת רק ברמת רישוי בהמשך, לא ב-v0.1.
- תוכן הדוח: ציון כללי, ספירה לפי חומרה, טבלת findings, ותוכנית תיקון מדורגת (בדיקה בודדת ← המתנה של 24 שעות ← תיקון גורף, כמו ב-README). בנוסף מופקים `findings.json` (פלט שמכונה קוראת) ו-CSV תואם לעמודות הישנות.

### 2.4 מנוע התיקון
```powershell
Invoke-AuthShiftRemediation -Finding $f -WhatIf          # ברירת מחדל: תצוגה מקדימה בלבד
Invoke-AuthShiftRemediation -Finding $f -Confirm:$true -JournalPath .\journal
Undo-AuthShiftRemediation  -JournalFile .\journal\2026-11-02T1015-run.json [-EntryId ...]
```
- `[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]`: כל כתיבה עטופה ב-`$PSCmdlet.ShouldProcess`. **בלי `-Confirm:$true` או `-Force` מפורש, הפקודה מתנהגת כמו `-WhatIf`.** לכן תיקון גורף דורש פעולה מכוונת.
- **Pipeline קבוע לכל fixer:** (1) קריאה טרייה של האובייקט מ-DC קבוע (`-Server`) ← (2) הרצה חוזרת של שערי הבטיחות (OS, מפתחות AES, דגל "protected") ← (3) **כתיבה ל-journal לפני השינוי** (ערך מקורי מלא, כולל null) ← (4) כתיבה ← (5) read-back מאותו DC ← (6) סטטוס `VERIFIED/MISMATCH/READ-FAIL/WRITE-FAIL/SKIPPED`.
- **Journal:** קובץ JSON שנכתב append-only לכל ריצה: `RunId`, `Operator`, `Server`, ולכל רשומה `Target`, `Attribute`, `Before` (כולל `IsNull`), `After`, `Status` וזמן. `Undo` משחזר בדיוק את `Before`. אם הערך המקורי היה null, הוא מוחק את התכונה עם `-Clear`. לפני השחזור הוא בודק שהערך הנוכחי עדיין שווה ל-`After`, ואם מישהו שינה אותו בינתיים, ה-undo נעצר עם אזהרה.
- fixers ב-v0.1: רק `Fix-ASEncTypeAes` (כתיבה שומרת ביטים, ראו סעיף 1.3). NTLM ו-LDAP הם הגדרות GPO/registry ב-DC, ולכן ב-v0.1 הם **מדריך בלבד** (`CanAutoFix=$false`). תיקון אוטומטי שלהם יגיע אחרי בטא.
- כל הכתיבות עוברות דרך ממשק `IDirectoryWriter` (פונקציות `Set-ASAttribute`/`Get-ASAttribute`), עם מימוש `FakeWriter` בזיכרון לבדיקות.

---

## 3. אסטרטגיית בדיקות

| שכבה | כלי | מה נבדק |
|---|---|---|
| Unit | Pester 5.x | `EncTypes`, `Test-ComputerAESCompatible` (טבלת OS מה-README כ-`-TestCases`), `New-ASFinding`, schema validation |
| Checks | Pester + fixtures | לכל check: fixture "תקין" שמחזיר 0 findings, fixture "פגיע" שמחזיר N findings מדויקים, ו-fixture "חסר הרשאה" שמחזיר Info |
| Remediation | Pester + `FakeWriter` | `-WhatIf` לא כותב כלום, ה-journal נכתב לפני הכתיבה, undo מחזיר null בדיוק, MISMATCH מזוהה, legacy OS מדולג, ביטים נשמרים |
| Collector | Pester `Mock Get-ADUser/Get-ADComputer` | מיפוי אובייקט AD ל-snapshot. פונקציות stub מוגדרות כשמודול ActiveDirectory לא מותקן ב-runner |
| Report | Pester | ה-HTML לא מכיל `<script src=` או `http` חיצוני, ערכים מקודדים (fixture עם שם `<img onerror>`), ה-branding מוחל |
| Lint | PSScriptAnalyzer | `PSScriptAnalyzerSettings.psd1` עם כלל `PSUseCompatibleSyntax` (5.1), `PSAvoidUsingPlainTextForPassword`, `PSUseShouldProcessForStateChangingFunctions` |

- **Fixtures:** `tests/Fixtures/*.json` בפורמט ה-snapshot. ערכות: `clean-domain`, `small-msp` (כ-50 אובייקטים מעורבים), `legacy-mess` (Server 2003, null OS, 0x24, krbtgt בן 8 שנים) ו-`large-synthetic` (נוצר בסקריפט, 5,000 אובייקטים, לבדיקת ביצועים). **רק נתונים מומצאים** (`contoso.local`). snapshots של בטא נכנסים רק אחרי anonymization וסקירה.
- **CI (`.github/workflows/ci.yml`):** matrix של `windows-latest` עם `shell: powershell` (5.1) ו-`shell: pwsh` (7.x), ו-job אחד על `ubuntu-latest` עם pwsh ללוגיקה טהורה. השלבים: התקנת Pester ו-PSScriptAnalyzer מ-PSGallery (ההתקנה עצמה מותרת, רק פרסום לגלריה אסור), lint, בדיקות עם סף כיסוי של 80% ל-`Private/Core` ו-`Checks`, והעלאת דוח HTML לדוגמה מ-fixture כ-artifact. ב-tag `v*`, workflow נפרד אורז zip ל-GitHub Release.
- **אם הריפו פרטי:** runner של Windows נספר פי 2 מתוך מכסת 2,000 הדקות החינמיות בחודש (בתוכנית Free), כלומר כ-1,000 דקות Windows אמיתיות. אז נריץ את רוב הבדיקות על ubuntu עם pwsh, ואת ה-matrix של Windows 5.1 רק ב-PR ל-`main` ובלילה. Community ציבורי, אז אין בעיה. קוד Pro עתידי יישב בריפו פרטי נפרד, ויצטרך לעבוד לפי המגבלה הזו.

---

## 4. עקרונות אבטחה

1. **Read-only כברירת מחדל.** `Invoke-AuthShiftScan` מבצע רק `Get-*` ולא דורש Domain Admin; כל משתמש מאומת מספיק לרוב הבדיקות. כתיבה קיימת רק ב-`Invoke-AuthShiftRemediation`, ושם `ConfirmImpact=High` ו-WhatIf כברירת מחדל.
2. **לא שומרים credentials.** משתמשים בהקשר של המשתמש שמחובר, או ב-`-Credential [PSCredential]` שמועבר בזמן ריצה ולא נשמר בדיסק, בלוג, ב-journal או בדוח. אין קבצי config עם סיסמאות.
3. **אפס טלמטריה.** אין קריאות רשת יוצאות בכלל (מלבד AD). זה נאכף בבדיקה שסורקת את הקוד ומחפשת `Invoke-WebRequest`, `Invoke-RestMethod` ו-`Net.WebClient`. ההפניות ל-KB הן קישורים בלבד.
4. **דוחות, logs, journals ו-snapshots הם נתונים רגישים.** הם מכילים שמות חשבונות, מבנה OU וחשבונות שירות, כלומר מפת תקיפה. לכן:
   - הכלי מציג אזהרה באנגלית לפני השמירה, ומוסיף לדוח באנר "Confidential".
   - ברירת המחדל לשמירה היא `$env:USERPROFILE\AuthShift\` ולא תיקיית הריפו.
   - אפשרות `-Anonymize` לשיתוף.
   - יש להוסיף ל-`.gitignore`: `*.authshift.html`, `*.authshift.json`, `reports/`, `journal/`, `snapshots/`, ולהחריג במפורש את `!tests/Fixtures/*.json`. (`*.csv` ו-`*.log` כבר חסומים.)
5. **שרשרת אספקה.** בלי תלויות runtime מלבד ActiveDirectory. גרסאות Pester ו-PSScriptAnalyzer מקובעות ב-CI. Actions מקובעות ל-SHA. Dependabot ו-secret scanning פעילים, וקובץ `SECURITY.md` מגדיר תהליך דיווח. חתימת Authenticode תידחה עד שיהיה תקציב, וב-README יוסבר `Unblock-File`.
6. **Least privilege בתיקון.** ה-README ממליץ על delegation של כתיבה ל-`msDS-SupportedEncryptionTypes` בלבד, על OU ספציפי, במקום Domain Admin.

---

## 5. תוכנית הנדסית ל-v0.1 (שבועות 3–6 בתוכנית 90 הימים)

**הגדרת "סיום" ל-v0.1:** `Import-Module AuthShift`, ואז `Invoke-AuthShiftScan | New-AuthShiftReport` מפיק דוח HTML ממותג מ-fixture. התפריט הישן עובד דרך ה-shim. תיקון RC4 עם WhatIf ו-journal ו-undo עובר את כל הבדיקות. ה-CI ירוק על 5.1 ו-7.

| שלב | Eng-1: Core/Collector | Eng-2: Checks | Eng-3: Report + CI/QA |
|---|---|---|---|
| **P0 (שבוע 3, ימים 1–2)** חוזים | שלד המודול, psd1 ו-psm1, `New-ASFinding` וסכמת Finding v1, סכמת snapshot (JSON Schema) | ייבוא `EncTypes` ושער ה-OS מהסקריפט לתוך `Private/Core`, ושיחזור הבדיקות שלהם | `ci.yml`, הגדרות PSScriptAnalyzer, תבנית PR, `.gitignore`, ו-fixtures ראשונים `clean-domain` ו-`legacy-mess` |
| **P1 (שבוע 3–4)** סריקה | `FixtureCollector`, `ADCollector` (עם mocks), בדיקת יכולות והרשאות, `Write-ASLog` (תואם לפורמט הישן) | AS-RC4-001…005, AS-KRB-001/002, ולכל check שלוש בדיקות fixture | מנוע התבניות, HTML עצמאי, white-label config, בדיקת XSS וחוסר משאבים חיצוניים |
| **P2 (שבוע 5)** תיקון | `Journal`, `IDirectoryWriter` ו-`FakeWriter`, `Invoke-AuthShiftRemediation` ו-`Undo-` עם ShouldProcess ו-DC קבוע | `Fix-ASEncTypeAes` עם כתיבה ששומרת ביטים ושער `PasswordLastSet` למשתמשים; AS-NTLM-001 ו-AS-LDAP-001/002 (זיהוי ומדריך בלבד) | `findings.json` ו-CSV תואם, תוכנית תיקון מדורגת בדוח, סקירת ניסוח של המחרוזות באנגלית, fixture `large-synthetic` ומדידת ביצועים |
| **P3 (שבוע 6)** תאימות ושחרור | shim ל-`Manage-KerberosEncryption.ps1`, העברת התפריט ל-`Start-AuthShiftMenu`, עותק `legacy/` | `Export-ASSnapshot -Anonymize`, ותיעוד לכל check (`docs/checks/AS-*.md`) | `Compat.Tests.ps1`, workflow ל-Release (zip), עדכון README ו-CHANGELOG, ובדיקת QA מלאה של ה-DoD |

**תלויות:** P0 חוסם את כל השאר, כי סכמות Finding ו-snapshot צריכות להיקבע קודם. Eng-2 עובד מול fixtures ולא מחכה ל-`ADCollector`. כל PR דורש CI ירוק וסקירה של מהנדס נוסף. כל שינוי בנתיב הכתיבה דורש גם אישור של הארכיטקט.

**סיכונים פתוחים:**
- אי אפשר לאמת כתיבות אמיתיות בלי AD. **מענה:** בטא עם MSPs שמריצים קודם `-WhatIf`, ואחר כך תיקון של חשבון בודד במעבדה שלהם. snapshots אנונימיים חוזרים אלינו כ-fixtures.
- ההתנהגות של `-KerberosEncryptionType` מול ביטים קיימים (סעיף 1.3) מבוססת על ידע ולא על בדיקה. היא מסומנת כ"לאמת" עד בטא.
