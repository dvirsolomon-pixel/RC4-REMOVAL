# 03 — מתחרים וכאבי לקוח: AD Hardening / RC4 / NTLM

**תאריך:** 2026-10-21 · **מחבר:** Competitors & Customer Pain Analyst
**הערת שיטה:** Reddit חסום לכלי המחקר שלנו (גם בחיפוש וגם ב-fetch), ולכן הכאבים מבוססים על Microsoft Q&A, פורום Synology, מאמרי KB של ספקים (Specops, SAP, NetApp) ובלוגים של יועצים שמתעדים תקלות שטח. מחירים: רובם מצד שלישי או לא מתוארכים. **לפני שמחליטים על תמחור צריך לאמת אותם מול הספקים.**

---

## 1. ההקשר: לוח הזמנים כבר עבר
- **ינואר 2026** (KB5073381, CVE-2026-20833): שלב Audit. נוספו אירועי KDCSVC 201–209 ומפתח הרישום `RC4DefaultDisablementPhase`.
- **אפריל 2026:** ברירת המחדל לחשבונות שאין להם הגדרה מפורשת הפכה ל-AES-SHA1 בלבד. עדיין אפשר היה לחזור ל-Audit.
- **יולי 2026:** מפתח ה-rollback הוסר ונשאר מצב Enforcement בלבד. ([Microsoft KB](https://support.microsoft.com/en-us/topic/how-to-manage-kerberos-kdc-usage-of-rc4-for-service-account-ticket-issuance-changes-related-to-cve-2026-20833-1ebcda33-720a-4da8-93c1-b0496e1910dc), [MC1279830](https://mc.merill.net/message/MC1279830), [Nerdio](https://nmmhelp.getnerdio.com/hc/en-us/articles/44796137710605))
- **NTLM:** הפיצ'ר הוכרז deprecated ב-2024. Audit משופר כבר קיים ב-Server 2025 / Win11 24H2. במחצית השנייה של 2026 מגיעים IAKerb ו-Local KDC. ב-Windows Server הגדול הבא (לפי הערכה: 2027–2028) NTLM ברשת יהיה כבוי כברירת מחדל. ([Microsoft Tech Community](https://techcommunity.microsoft.com/blog/windows-itpro-blog/advancing-windows-security-disabling-ntlm-by-default/4489526), [Directions on Microsoft](https://www.directionsonmicrosoft.com/reports/ntlm-to-be-disabled-in-future-releases/))

**משמעות:** את חלון ה-"prepare before the deadline" של RC4 כבר פספסנו. מה שנשאר בשוק הוא שוק של **ניקוי שאחרי Enforcement**: חשבונות שהוגדרו ידנית כ-RC4 כ-workaround (Microsoft ממשיכה לכבד אותם), התקני NAS ולינוקס שנשברו, וחשבונות שירות בלי מפתחות AES. ה-deadline הבא, שעדיין יש לפניו זמן, הוא **NTLM**.

---

## 2. טבלת השוואת מתחרים

| מוצר | מה עושה | מחיר (ידוע) | לקוח יעד | חולשות / פערים |
|---|---|---|---|---|
| **PingCastle** (Netwrix) | סריקת health/risk של AD וציון | Community חינם (רק לארגון שלך). Service Providers מ-\$1,000 לבדיקה לשנה. Enterprise מ-\$30 ל-identity לשנה ([pricing](https://pingcastle.com/purchase/)) | צוותי IT/Sec, יועצים | מתמקד בגילוי ולא מתקן כלום. רישוי MSP יקר ומסורבל (רישיון ל-48 שעות דרך Partner Portal, [Netwrix](https://community.netwrix.com/t/netwrix-pingcastle-48-hour-assessment-license/2063)). מאז הרכישה ע"י Netwrix הכלי עבר מסחור |
| **Purple Knight** (Semperis) | סריקה נקודתית של 150–200+ IOE/IOC ל-AD, Entra ו-Okta | חינם. המוצר בתשלום הוא DSP (enterprise) | ארגונים, משמש כמשפך מכירה ל-DSP | Point-in-time בלבד. remediation אוטומטי ו-monitoring קיימים רק ב-DSP היקר ([FAQ](https://semperis.com/purple-knight/faq/)) |
| **Tenable Identity Exposure** | ניטור רציף של IOE/IOA ב-AD וב-Entra | לא מפורסם. לפי enabled user, דרך sales ([docs](https://docs.tenable.com/quick-reference/licensing-guide/Content/tenable-identity-exposure-licensing.htm)) | Enterprise, SOC | יקר, מכירה דרך sales, פריסה כבדה. מזהה ולא מבצע שינויים בבטחה |
| **Microsoft Defender for Identity** | חיישנים על DC, ITDR, והמלצת "weak cipher" ב-Secure Score | נדרש E5 / EMS E5 / רישיון standalone ([prereqs](https://learn.microsoft.com/defender-for-identity/prerequisites)) | ארגונים עם E5 | ההמלצה מציגה 30 יום של ישויות וזהו. אין תיקון בפועל ואין rollback. SMB בלי E5 לא מקבלים את זה ([assessment](https://learn.microsoft.com/en-us/defender-for-identity/security-assessment-weak-cipher)) |
| **Netwrix Auditor** | audit שינויים ודוחות | בערך \$20 ל-user לשנה (GetApp, צד שלישי) | Mid-market, compliance | כלי change-audit ולא כלי hardening. אין workflow ל-RC4/NTLM |
| **Quest Change Auditor / GPOADmin / Recovery** | audit, GPO, recovery | לא מפורסם | Enterprise | יקר וכבד. לא ממוקד deprecation |
| **ManageEngine ADAudit Plus** | audit, כולל דוח שימוש ב-RC4 | מ-\$595 לשנה ל-2 DC ([G2](https://www.g2.com/compare/manageengine-adaudit-plus-vs-netwrix-auditor), [blog RC4](https://www.manageengine.com/products/active-directory-audit/blog/rc4-encryption-being-phased-out-adaudit-plus-helps-audit-usage.html)) | SMB/Mid | מראה את השימוש ב-RC4 אבל לא מתקן. ממשק כבד |
| **Cayosoft Guardian** | ניטור ושחזור AD | לא מפורסם | Mid/Enterprise | מתריע על enc types לא מאובטחים ולא מעבר לזה ([blog](https://www.cayosoft.com/blog/kerberos-rc4-hardening-what-microsoft-s-cve-2026-20833-update-really-means-for-active-directory-admins/)) |
| **Forestall** | ISPM ומדריכי RC4 | לא מפורסם | Enterprise | תוכן חזק, אבל המוצר enterprise ([guide](https://forestall.io/resources/blog/disabling-rc4-enforcing-aes-step-by-step-guide)) |
| **BloodHound CE/Enterprise** | ניתוח attack paths | CE חינם. Enterprise ב-SaaS דרך sales ([compare](https://specterops.io/bloodhound-feature-comparison/)) | Red team / Sec team | לא עוסק ב-hygiene של הצפנה ולא מבצע remediation |
| **Microsoft Kerberos-Crypto scripts** | `Get-KerbEncryptionUsage.ps1`, `List-AccountKeys.ps1` על אירועי 4768/4769 | חינם (GitHub) | מנהלי AD | גילוי בלבד. סקריפטים גולמיים, בלי דוח, בלי תיקון ובלי rollback ([MS Learn](https://learn.microsoft.com/en-us/windows-server/security/kerberos/detect-remediate-rc4-kerberos)) |
| **RC4-ADAssessment** (Jan Tiedemann) | מודול PSGallery שבודק DC, trusts, KRBTGT, חשבונות שירות, KDCSVC ומשווה forest | חינם (v5.1) ([PSGallery](https://www.powershellgallery.com/packages/RC4-ADAssessment/), [GitHub](https://github.com/BetaHydri/RC4_AD_Check)) | מנהלי AD | **המתחרה הישיר ביותר לכלי של המייסד.** חזק בגילוי, אבל בלי remediation מבוקר עם rollback ובלי מוצר מסחרי |

---

## 3. כאבי לקוח אמיתיים (פרפרזה + מקור)

1. **"אין לי מושג מה עוד משתמש ב-RC4."** Microsoft עצמה כותבת שהיעדר אירועי Audit *לא* מבטיח שהתקנים שאינם Windows יעבדו ([MC1279830](https://mc.merill.net/message/MC1279830)). זה הפחד המרכזי: שבירה שקטה שלא הופיעה בלוגים.
2. **NAS ותיקי keytab.** NAS (NetApp, Synology, QNAP) שהצטרפו לדומיין לפני שנים, עם `msDS-SupportedEncryptionTypes` ריק או keytab שמכיל RC4 בלבד, הפסיקו לבצע אימות. ב[פורום Synology](https://community.synology.com/enu/forum/1/post/195973) משתמשים מתלוננים שאין שום תיעוד רשמי לנטרול RC4 ושגם התמיכה לא עזרה. NetApp נאלצה לפרסם KB ייעודי ([NetApp](https://kb.netapp.com/on-prem/ontap/da/NAS/NAS-KBs/ONTAP_Guidance_for_Microsoft_Security_Update_KB5073381_(CVE%E2%80%912026%E2%80%9120833))).
3. **חשבונות שירות ישנים בלי מפתחות AES.** חשבון שהסיסמה שלו לא הוחלפה מאז רמת ה-DFL הישנה מחזיק רק מפתח RC4. התיקון הוא איפוס סיסמה, ובמערכות ייצור זה מפחיד ([4sysops](https://4sysops.com/archives/windows-kerberos-rc4-deprecation-what-will-break-in-active-directory-and-how-to-fix-it/), [myabt](https://www.myabt.com/blog/kerberos-rc4-aes-migration-service-accounts)).
4. **אפליקציות צד שלישי נשברות.** Specops מתעדים כשל SSPI בכלי ה-password reset שלהם אחרי העדכון ([Specops KB](https://specopssoft.com/knowledge-base/specops-password-reset/error-security-support-provider-interface-sspi-authentication-failed/)). ב-Microsoft Q&A יש שרשור על חשבון SQL שהמשיך לקבל כרטיסי RC4 בזמן שכל השאר עברו ל-AES ([Q&A](https://learn.microsoft.com/en-us/answers/questions/50334/kerberos-encryption-types-an-account-persists-in-u)), ושרשור ADFS שבו הפתרון שהוצע היה *להחזיר* את RC4 ([Q&A](https://learn.microsoft.com/en-us/answers/questions/1167926/adfs-redirect-to-login-page-after-successful-login)).
5. **"workarounds" שמנציחים את הבעיה.** מנהלים מגדירים `DefaultDomainSupportedEncTypes=0x24` או RC4 מפורש על חשבונות רק כדי להשתיק את השגיאות. Microsoft ממשיכה לכבד את זה ואירוע 205 ממשיך להופיע ([ecorpit](https://ecorpit.com/kerberos-rc4-hard-enforcement-july-2026-remediation/), [Microsoft KB](https://support.microsoft.com/en-us/topic/how-to-manage-kerberos-kdc-usage-of-rc4-for-service-account-ticket-issuance-changes-related-to-cve-2026-20833-1ebcda33-720a-4da8-93c1-b0496e1910dc)). אחרי יולי 2026 נוצר "חוב RC4" נסתר בהרבה ארגונים.
6. **מידע סותר.** בלוגים של ספקים סותרים זה את זה בתאריכים ובמשמעות של האירועים (201/202 לעומת 203/204/208/209), וגם התגובות לפוסט של Veeam חלקו על הניסוח שלו ([Veeam](https://community.veeam.com/blogs-and-podcasts-57/microsoft-rc4-deprecation-what-to-check-before-july-2026-updates-detect-and-remediate-rc4-usage-in-kerberos-13702)). מנהלים רוצים מקור אחד שאפשר לסמוך עליו.
7. **לינוקס ו-Java.** אחרי שינוי enc types צריך לייצר מחדש keytab, אחרת יש KVNO mismatch ([grandlinux](https://www.grandlinux.com/en/blogs/kerberos-rc4-enforcement-july-2026-ad.html)). כלים שבנויים רק ל-Windows מפספסים את כל המקרים האלה.

**מה מנהלים רוצים שיהיה** (מסקנה מהמקורות): (א) מפה אחת של "מי עדיין תלוי ב-RC4/NTLM", שמחברת לוגים ממספר DC עם אובייקטים ב-AD, (ב) תיקון מדורג עם בדיקה ו-rollback בלחיצה, (ג) הדרכה לפי התקן (NAS, לינוקס, SQL, ADFS), (ד) דוח שאפשר להראות להנהלה או ל-auditor.

---

## 4. White space: פערים שצוות זעיר יכול לכבוש

1. **Remediation בטוח במקום detection בלבד.** כל הכלים החינמיים (PingCastle, Purple Knight, RC4-ADAssessment, הסקריפטים של Microsoft) מסתפקים בגילוי. מי שמתקן עם rollback הוא DSP של Semperis או Tenable, ועולה עשרות אלפי דולרים. הכלי של המייסד כבר כולל OS gate, read-back ו-rollback. **זה היתרון הייחודי שלנו.**
2. **"RC4 Debt Cleanup" שאחרי Enforcement.** לסרוק חשבונות שהוגדרו RC4 מפורש כ-workaround, את `DefaultDomainSupportedEncTypes` עם 0x24, חשבונות בלי מפתחות AES (גיל סיסמה) ואירועי 205, ולבנות תוכנית יציאה. אף מתחרה לא ממצב את עצמו על המצב *שאחרי* יולי 2026.
3. **NTLM Readiness: ה-deadline הבא, ב-2027–2028.** לאסוף אירועי NTLM audit מה-DCs, לשייך אותם לאפליקציה או להתקן, ולסווג מה יעבור ל-Kerberos (IAKerb / Local KDC) ומה צריך exception. עוד אין כלי SMB ממוקד לזה. אפשר להיכנס מוקדם ולתפוס את מילות החיפוש ואת התוכן.
4. **MSP multi-tenant במחיר פשוט.** רישוי MSP של PingCastle יקר (\$1,000 לבדיקה) ומסורבל. אפשר להציע agent/סקריפט שרץ אצל כל לקוח, דוח white-label ותמחור שטוח לכל tenant (בסביבות \$X לחודש). זה מתאים לערוץ ההפצה של Pax8.
5. **Playbooks לפי התקן.** NAS (Synology, QNAP, NetApp), keytab בלינוקס, SQL SPN, ADFS. מנהלים לא מוצאים את התוכן הזה אצל אף ספק. בשבילנו זה כמעט חינם להפקה בעזרת AI agents, ומביא SEO ו-trust.
6. **שקיפות ותמחור self-serve.** כמעט כל המתחרים המסחריים מוכרים רק דרך sales. מוצר בתמחור גלוי, עם כרטיס אשראי ובלי שיחת מכירה, הוא בידול אמיתי ב-SMB.

**סיכונים:** RC4-ADAssessment החינמי מתפתח מהר, ו-Microsoft עלולה להוסיף כלים מובנים (כמו שעשתה עם audit ל-NTLM). הגנה סבירה: להתמקד ב-remediation, ב-NTLM, ב-MSP ובדוחות. אלה התחומים שבהם Microsoft וכלים חינמיים לא משקיעים.
