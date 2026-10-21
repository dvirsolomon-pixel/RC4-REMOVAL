# תוכנית Go-To-Market ב-GitHub בלבד (תקציב 0)

**מאת:** מנהל השיווק · **תאריך:** 2026-10-21 · **סטטוס:** טיוטה לאישור המנכ"ל
**מגבלות הדירקטוריון:** תקציב 0 · GitHub הוא הערוץ הפומבי היחיד (לא Reddit, לא PowerShell Gallery, לא דומיין, לא פרסום ממומן) · אסור לפרסם סודות או פרטים אישיים של המייסד מעבר ל-handle `dvirsolomon-pixel` · אסור להמציא המלצות או נתונים.
**שם המוצר בתוכנית:** KerbShift (לפי ההמלצה ב-`NAMING.md`; אם יוחלט אחרת מחליפים את המחרוזת).

---

## 0. העיקרון

ל-GitHub יש שלושה תפקידים בשבילנו, וכולם בחינם:
1. **חלון ראווה:** ה-README ודף ה-Pages הם דף המוצר.
2. **מנוע חיפוש:** Google מאנדקס היטב את GitHub ואת GitHub Pages. מנהלים מחפשים מחרוזות שגיאה מדויקות (Event IDs, etypes, KB). אם נכתוב את התשובה הטובה ביותר למחרוזת הזו, נגיע אליהם.
3. **CRM ורשימת המתנה:** Star = עניין, Watch → Releases = רשימת המתנה, Discussions = שיחה עם לקוחות, Issues = כאבים אמיתיים.

**המסר המרכזי** (לפי `research/03`, white space 1–3):
> *Fix what broke after Microsoft's RC4 enforcement — safely, with rollback — and get ready for NTLM deprecation.*

בידול בשלוש מילים: **Audit → Safe fix → Rollback.** כל הכלים החינמיים רק מאתרים בעיות. אנחנו גם מתקנים, ויודעים להחזיר אחורה.

---

## 1. מיצוב הריפו

### תיאור הריפו (About → Description, עד 350 תווים)
```
KerbShift Community — free PowerShell kit to audit and safely fix RC4 Kerberos encryption in Active Directory after Microsoft's 2026 enforcement. OS-compatibility gate, AD read-back validation, one-click rollback, CSV evidence. NTLM & LDAP-signing readiness coming next.
```

### Website (About → Website)
`https://dvirsolomon-pixel.github.io/RC4-REMOVAL/` (אחרי הפעלת GitHub Pages מ-`main` / `docs/`).

### Topics (עד 20; אותיות קטנות ומקפים)
```
active-directory, kerberos, rc4, aes, ntlm, ldap-signing, powershell,
windows-server, sysadmin, msp, security-hardening, kerberoasting,
cve-2026-20833, cve-2022-37966, identity-security, ad-security,
remediation, rollback, blue-team, infosec
```
הסיבה: ל-Topics יש דפי גילוי משלהם ב-GitHub (`github.com/topics/kerberos` וכו'). מנהלי AD מגיעים דרכם.

### Social preview (Settings → Social preview, ‏1280×640)
תמונה פשוטה (SVG→PNG שנכין בעצמנו, בלי כלים בתשלום): שם המוצר, השורה "Audit → Safe fix → Rollback" ו-"RC4 · NTLM · LDAP signing". מופיעה כשמישהו משתף את הקישור.

### Pinned
להצמיד את הריפו בפרופיל `dvirsolomon-pixel`. **README לפרופיל** (`dvirsolomon-pixel/dvirsolomon-pixel`): שורה אחת על המומחיות (AD/Kerberos hardening) וקישור לריפו, בלי שם אמיתי, בלי אימייל ובלי מיקום.

---

## 2. מבנה ה-README

הטיוטה המלאה: `company/marketing/README-DRAFT.md`. המבנה:

| # | סעיף | מטרה |
|---|---|---|
| 1 | שם + שורת משנה + badges סטטיים (License, PowerShell 5.1+, Latest release) | הבנה תוך 3 שניות. **בלי badges של מונים מזויפים או שירותים חיצוניים עם tracking** |
| 2 | "Broke after the July 2026 RC4 enforcement?" + 3 תסמינים עם מחרוזות שגיאה אמיתיות | SEO + זיהוי עצמי של הכאב |
| 3 | Audit → Safe fix → Rollback → Report (4 שורות) | הבידול |
| 4 | Quick start (3 פקודות) | זמן לערך ראשון < 5 דקות |
| 5 | Roadmap: NTLM/NTLMv1, LDAP signing, Auth Debt checks, Pro/MSP (planned) | ליצור סיבה ל-Watch |
| 6 | "Get notified" (Star / Watch → Releases / Discussions) | רשימת ההמתנה |
| 7 | כל התוכן הטכני הקיים (Features, Rollout, Bitmask, OS, Troubleshooting, References, Limitations) | אמינות + SEO ארוך-זנב |
| 8 | License, Contributing, Security, Disclaimer | אמון |

---

## 3. GitHub Releases

- **SemVer.** הגרסה הראשונה: `v1.0.0`, "KerbShift Community 1.0: RC4 audit & safe remediation" (הקוד הקיים).
- **ב-Release מצרפים:** `Manage-KerberosEncryption.ps1` + `SHA256SUMS.txt` (לשימוש עם `Get-FileHash`). מנהלי IT רוצים לאמת את מה שהם מריצים על DC. חתימת Authenticode עולה כסף, ולכן לא בשלב הזה. כותבים את זה בגלוי.
- **מבנה release notes:** What's new / Safety notes (מה הסקריפט כותב ל-AD) / Upgrade notes / Known issues / "What's next" עם קישור ל-Discussion.
- **קצב:** release קטן כל 2–3 שבועות. כל release שולח התראה לכל מי שעשה Watch → Releases, וזה ערוץ ההתראה היחיד שלנו (אין רשימת אימייל).
- **Roadmap ראשוני ל-releases:**
  - `v1.1` — "Auth Debt" checks: חשבונות עם RC4 מפורש (0x4 / 0x1C) שנשארו כ-workaround, חשבונות בלי מפתחות AES (גיל סיסמה), בדיקת `DefaultDomainSupportedEncTypes`, סיכום אירועי KDCSVC.
  - `v1.2` — דוח HTML (חינמי, דומיין אחד, בלי מיתוג).
  - `v1.3` — NTLM/NTLMv1 readiness (read-only): סיכום אירועי NTLM Operational ‏8001–8004 ואירוע 4624 עם NTLM V1.
  - `v1.4` — LDAP signing / channel binding readiness: אירועים 2886/2887/2889.
- **חשוב:** לא מפרסמים מועדים מחייבים. ב-README כותבים "planned".

---

## 4. Discussions: רשימת המתנה ומשוב

הפעלה: Settings → Features → Discussions. קטגוריות:

| קטגוריה | פורמט | שימוש |
|---|---|---|
| 📣 Announcements | Announcement (רק maintainers כותבים) | כל release ועדכון roadmap |
| 🙋 Q&A | Question/Answer | "Event 14 after the change, what now?". כל תשובה טובה הופכת לתוכן ב-Pages |
| 💡 Ideas | Open | בקשות לבדיקות ולתמיכה בהתקנים |
| 🧾 **Pro / MSP waitlist** | Open, נעול לתגובות, מוצמד | דיון אחד מוצמד: "Interested in Pro/MSP? React with 👍 and tell us your use case (no personal data)". **זו רשימת ההמתנה.** |
| 📊 Polls | Poll | "What broke for you after RC4 enforcement?" (NAS / Linux keytab / SQL / ADFS / SAP / Other), "How many AD domains do you manage?" (1 / 2–10 / 11–50 / 50+) |
| 🧰 Device playbooks | Open | שיתוף פתרונות ל-Synology/QNAP/NetApp/Linux. מהם נבנים מדריכי ה-SEO |

**כללים לדיונים:**
- להזהיר בכל תבנית: *"Do not post domain names, hostnames, usernames, IPs or log excerpts without redacting them."*
- אנחנו לא אוספים אימיילים. "רשימת המתנה" = 👍 בדיון + Watch → Custom → Releases.
- זמן תגובה יעד: עד 48 שעות.

---

## 5. תבניות Issues ו-PR (`.github/`)

| קובץ | תוכן |
|---|---|
| `ISSUE_TEMPLATE/bug_report.yml` | גרסת הסקריפט, גרסת PowerShell, OS של ה-DC, אופציה בתפריט, ערך `msDS-SupportedEncryptionTypes` לפני ואחרי, שורת לוג **מושחרת**, checkbox: "I removed hostnames/usernames/IPs" |
| `ISSUE_TEMPLATE/compat_report.yml` | **"Something broke after RC4/NTLM changes"**: סוג ההתקן (NAS/Linux/Java/SQL/ADFS/SAP/Printer/Other), יצרן ודגם (אופציונלי), Event ID, etypes מבוקשים וזמינים, מה פתר. זה גם מחקר לקוחות וגם חומר גלם ל-Device playbooks |
| `ISSUE_TEMPLATE/feature_request.yml` | בעיה, פתרון מוצע, "Would this be useful across multiple client domains (MSP)?" |
| `ISSUE_TEMPLATE/config.yml` | `blank_issues_enabled: false` + קישורים: Q&A → Discussions, Pro/MSP waitlist → הדיון המוצמד, Security → `SECURITY.md` |
| `PULL_REQUEST_TEMPLATE.md` | "Does this change the AD write path? (y/n)", בדיקות שבוצעו, אישור "issue opened first" (לפי ה-README) |
| `SECURITY.md` | דיווח על פגיעויות דרך **GitHub Private Vulnerability Reporting** (Settings → Security). **בלי אימייל של המייסד** |
| `CONTRIBUTING.md` | הרחבה של סעיף Contributing הקיים |
| `LICENSE` | **חסר כרגע!** ה-README מפנה ל-"MIT — see LICENSE file", אבל הקובץ לא קיים בריפו. לתקן לפני ההשקה (חובה, גם בגלל אמון) |

**Labels:** `rc4`, `ntlm`, `ldap-signing`, `device:nas`, `device:linux`, `msp`, `good first issue`, `write-path` (דורש review מוגבר), `waitlist-signal`.

---

## 6. SEO דרך README ו-GitHub Pages

### למה זה עובד
מנהל שנתקל בתקלה מעתיק לגוגל את טקסט השגיאה כמו שהוא. דפי GitHub Pages ו-README מאונדקסים היטב. דף אחד לכל מחרוזת, עם תשובה מלאה ובלי "תשאירו פרטים", בונה אמון ומפנה לכלי.

### מבנה Pages (בתיקייה `docs/`)
- `docs/index.html`: דף הנחיתה (נבנה עכשיו).
- **שלב ב'** (לא בתוצר הזה): מדריך HTML סטטי אחד לכל מחרוזת שגיאה, בפורמט קבוע: Symptom → Why (since which update) → How to confirm (PowerShell) → Safe fix → Rollback → "Automate this with KerbShift".

### מחרוזות יעד (אמיתיות, ממקורות Microsoft ומהמחקר)

| # | מחרוזת / שאילתה שמנהלים מחפשים | דף יעד מוצע |
|---|---|---|
| 1 | `The requested etypes were 18 17. The accounts available etypes were 23` | `docs/kdc-event-14-etypes-23.html` |
| 2 | `Kerberos-Key-Distribution-Center Event ID 14` / `Event ID 16` / `Event ID 27` | `docs/kdc-events-14-16-27.html` |
| 3 | `KDCSVC event 201` … `209` / `CVE-2026-20833` / `KB5073381` | `docs/kdcsvc-201-209.html` |
| 4 | `event 205 RC4 DefaultDomainSupportedEncTypes` | `docs/event-205-hidden-rc4.html` |
| 5 | `4769 Ticket Encryption Type 0x17` | `docs/4769-0x17-rc4.html` |
| 6 | `KDC_ERR_ETYPE_NOTSUPP` (0xE) | `docs/kdc-err-etype-notsupp.html` |
| 7 | `msDS-SupportedEncryptionTypes 24 vs 28 vs 56` | `docs/supported-encryption-types-values.html` |
| 8 | `Synology / NetApp / QNAP Kerberos RC4 July 2026` | `docs/nas-rc4.html` |
| 9 | `keytab KVNO mismatch AES` (Linux/Java) | `docs/linux-keytab-aes.html` |
| 10 | `KB5066470 NTLMv1` / `MS-CHAPv2 Wi-Fi VPN broke October 2026` | `docs/ntlmv1-kb5066470.html` |
| 11 | `NTLM operational event 8001 8002 8003 8004` | `docs/ntlm-audit-events.html` |
| 12 | `LDAP signing event 2889` / `2887` | `docs/ldap-signing-2889.html` |

**כללי תוכן:**
- כל טענה עם תאריך או KB מקבלת קישור למקור רשמי של Microsoft (רשימת המקורות קיימת ב-`research/01`, `research/03`).
- `<title>` ו-`<meta name="description">` מכילים את המחרוזת המדויקת. H1 = התסמין.
- בלי מספרים מומצאים ("thousands of admins trust..."). אם אין נתון, לא כותבים.
- כל עמוד מקושר מה-README בסעיף "Troubleshooting guides". קישורים פנימיים בין העמודים.
- `docs/sitemap.xml` ו-`docs/robots.txt` פשוטים. Google Search Console אפשרי בחינם, אבל דורש אימות בעלות. אם דורשים זאת, להשתמש רק בחשבון של handle המייסד.

### SEO בתוך GitHub עצמו
- Topics (סעיף 1).
- כותרות Issues ו-Discussions ברורות עם מחרוזת השגיאה. GitHub Discussions מאונדקסים בגוגל.
- **Gists** (אופציונלי): סניפט PowerShell קצר לכל בדיקה (למשל "find accounts with explicit RC4"), עם קישור לריפו. עדיין GitHub בלבד.

---

## 7. הפצה בתוך GitHub (בלי ספאם)

ערוצים שנשארים בתוך GitHub ולכן מותרים, **בכפוף לאישור המנכ"ל לכל פעולה מחוץ לריפו שלנו**:
1. **PRs לרשימות "awesome"** רלוונטיות (רשימות sysadmin / PowerShell / Active Directory security). PR אחד לכל רשימה, שורה אחת עובדתית, לפי כללי הרשימה.
2. **עזרה אמיתית** ב-issues של פרויקטים שכנים (למשל ריפואים של NAS/Samba/Kerberos) כשמישהו שואל על תקלת RC4. עונים קודם לגופו של עניין, ומוסיפים קישור רק אם הוא עוזר. **אף פעם לא** לפתוח issues שיווקיים בריפואים של אחרים.
3. **GitHub Sponsors:** לא עכשיו (דורש פרטי תשלום וזהות).

---

## 8. רשימת בדיקות להשקה (Launch checklist)

### לפני ההשקה (שבוע 1)
- [ ] אישור שם (`NAMING.md`) ע"י הדירקטוריון
- [ ] להוסיף `LICENSE` (MIT). כרגע חסר
- [ ] להחליף `README.md` לפי `README-DRAFT.md`, אחרי review של המנכ"ל
- [ ] לעדכן About: description, website, topics
- [ ] להעלות Social preview image
- [ ] להפעיל GitHub Pages: Settings → Pages → Deploy from branch → `main` / `/docs`
- [ ] לבדוק את `docs/index.html` במובייל, במצב כהה ובהיר, ב-Lighthouse (accessibility ≥ 95)
- [ ] להפעיל Discussions וליצור קטגוריות + דיון waitlist מוצמד + 2 Polls
- [ ] להוסיף `.github/ISSUE_TEMPLATE/*`, `PULL_REQUEST_TEMPLATE.md`, `SECURITY.md`, `CONTRIBUTING.md`
- [ ] להפעיל Private vulnerability reporting
- [ ] **סריקת סודות ופרטיות:** `git log -p | grep -iE "password|token|@gmail|@"` + GitHub secret scanning. לוודא שאין אימייל או שם אמיתי של המייסד ב-commits ובקבצים (בדיקת `git log --format='%an %ae'`: אם מופיע אימייל אישי, להגדיר את ה-noreply של GitHub לפני ה-commits הבאים)
- [ ] להצמיד את הריפו בפרופיל

### יום ההשקה
- [ ] ליצור Release `v1.0.0` עם `.ps1` + `SHA256SUMS.txt` + release notes
- [ ] Announcement ב-Discussions: "KerbShift Community 1.0 + what's next (NTLM)"
- [ ] לרשום baseline של המדדים (סעיף 9)

### שבועיים אחרי
- [ ] לפרסם 3 מדריכי Pages ראשונים (מחרוזות 1, 3, 4: הכי חמות אחרי יולי 2026)
- [ ] להגיב לכל issue ו-discussion תוך 48 שעות
- [ ] Release `v1.1` (Auth Debt checks)
- [ ] דוח מדדים למנכ"ל + החלטת המשך או שינוי כיוון (סעיף 9)

---

## 9. מדדים

**מקור הנתונים:** Insights → Traffic (views, unique visitors, clones, referrers, popular content), Stars, Watchers, Discussions, Releases (download count לכל asset).
⚠️ GitHub שומר נתוני traffic רק 14 יום, ולכן **כל שבוע מעתיקים ידנית** לקובץ `company/marketing/metrics.md` (בלי כלים חיצוניים).

| מדד | הגדרה | יעד שבועיים | יעד 90 יום |
|---|---|---|---|
| **Waitlist signals** | 👍 ייחודיים בדיון Pro/MSP waitlist + תגובות עם use case | **≥ 30** (קריטריון העצירה מהחלטה 001, מותאם ל-GitHub) | ≥ 150 |
| Stars | סך הכל | ≥ 50 | ≥ 300 |
| Watchers (Releases) | Watch | ≥ 15 | ≥ 80 |
| Unique visitors | Insights, 14 יום | ≥ 500 | ≥ 3,000 ל-14 יום |
| Unique cloners + הורדות asset | Insights + Releases | ≥ 40 | ≥ 400 |
| Compat reports / issues אמיתיים | מספר | ≥ 5 | ≥ 30 |
| "MSP signal" | תגובות/פולים עם "11+ domains" | ≥ 3 | ≥ 20 |
| Referrers מ-Google | Insights → Referring sites | נבדק | גדל כל שבוע |

**קריטריון החלטה** (ממיר את קריטריון העצירה של החלטה 001 למדדי GitHub):
- **ממשיכים:** ≥ 30 waitlist signals **וגם** ≥ 3 MSP signals בשבועיים.
- **מתקנים מסר:** 10–29 signals. משנים את הכותרת, ממקדים ב-NTLM, ובודקים שוב בעוד שבועיים.
- **עוצרים או משנים כיוון:** פחות מ-10 signals ופחות מ-100 unique visitors. מדווחים לדירקטוריון.

**מה לא עושים עם מדדים:** לא קונים stars, לא מבקשים stars בתמורה למשהו, לא מציגים מספרים שלא נמדדו, לא מציגים ציטוטים ממשתמשים בלי אישור מפורש בכתב בדיון ציבורי.

---

## 10. סיכונים

| סיכון | מענה |
|---|---|
| GitHub לבד מביא traffic איטי (SEO לוקח 3–6 חודשים, `research/02`) | להתחיל מיד עם מדריכי Pages למחרוזות החמות. לבקש מהדירקטוריון לבחון מחדש ערוצים נוספים אחרי שבועיים, עם נתונים |
| כלי חינמי מתחרה (RC4-ADAssessment) מופיע ראשון בחיפוש | להתמקד ב-"safe fix + rollback" וב-post-enforcement, שם אין לו מיצוב |
| משתמש מדביק לוגים עם מידע רגיש ב-issue | אזהרות בתבניות + עריכה או מחיקה מיידית של תוכן רגיש |
| הבטחות על Pro/MSP שלא יקוימו | תמיד לכתוב "planned", בלי מועדים ובלי גביית תשלום |
