# ROADMAP — AI Footprint Scanner

**מחבר:** Product Manager · **תאריך:** 2026-10-21 · **בסיס:** [PRD](PRD.md), [החלטה 003](../../decisions/003-ai-security-product.md)

> עיקרון: כל milestone חייב לספק ערך גם בלי הבא אחריו. עד v0.2 אין שום ענן ושום חשבון חיצוני. התקציב 0 בכל השלבים.

## v0.1: Local agent ודוח (שבועות 1–2) — אין ענן
**היקף:**
- מודול PowerShell בשם `AIFootprint`.
- `catalog/*.yaml` עם apps, extensions, clients ו-secret patterns.
- כל ה-detections שמסומנים MVP ב-PRD §5.
- דוח HTML offline ו-JSON (`schemaVersion 1.0.0`).
- `-RedactUser` ו-`-WhatWouldBeCollected`.
- CI ב-GitHub Actions: Pester, PSScriptAnalyzer ובדיקת canary secrets.
- Release ב-GitHub: zip ו-SHA256.

**Exit criteria:**
- כל תנאי הקבלה ב-PRD §8 מתקיימים.
- הנתיבים ב-PRD §5.1 נבדקו על Windows אמיתי או ב-VM, ועודכנו בקטלוג ל-verified או לנתיב מתוקן.
- Release ציבורי עם README באנגלית ודוח לדוגמה עם נתונים סינתטיים.
- **שעון 14 הימים מתחיל:** ≥30 stars ו-≥100 downloads. אם היעד לא הושג, עוצרים וחוזרים לדירקטוריון לפני שמתחילים את v0.2.

## v0.2: Cloudflare dashboard ו-enrollment (שבוע 3)
> ### ⚠️ כאן נדרש חשבון Cloudflare (free tier)
> לפי החלטת הדירקטוריון ב-003, המנכ"ל מודיע לדירקטוריון ומקבל אישור **לפני** שהעבודה על v0.2 מתחילה. עד אז הפיתוח מקומי בלבד: `wrangler dev` ו-D1 מקומי. ה-API tokens נשמרים רק ב-GitHub Actions secrets או במשתני סביבה, **לעולם לא בריפו**.

**היקף:**
- Worker `/ingest` שמקבל POST של JSON ומאמת אותו מול `report.v1.json`.
- D1 עם הטבלאות tenants, devices, scans ו-findings.
- Enrollment token לכל tenant (write-only, ניתן לביטול). rate-limit לכל device.
- Dashboard סטטי ב-Cloudflare Pages: רשימת devices, findings לפי חומרה, ו-drill-down לכל תחנה.
- Login דרך GitHub OAuth או magic link.
- בצד ה-agent: הדגל `-Upload -EnrollmentToken`. בלי הדגל לא נשלח שום דבר.
- Detections חדשים: AIS-SEC-002, AIS-PERM-003, ו-drift מקומי (AIS-MCP-005).
- Salt לכל tenant ל-fingerprints.

**Exit criteria:**
- 25 תחנות (SaaS Free) מדווחות ביציבות במשך 7 ימים בתוך מגבלות ה-free tier.
- Security review פנימי (QA/אבטחה) עבר: אין ערכי סודות ב-D1, ובדיקת בידוד בין tenants עברה.
- לפחות 3 אדמינים חיצוניים (pilot מ-r/sysadmin, r/Intune או issues) רשמו tenant ונתנו פידבק.
- מדיניות פרטיות ו-DPIA template מעודכנים להעלאה לענן.

## v0.3: Intune/GPO packaging, signing ו-drift alerts (שבועות 4–6)
**היקף:**
- חבילת Intune Remediation (detection + report script) ו-Platform Script.
- GPO Startup Script ו-scheduled task יומי. דוגמה ל-RMM עבור MSPs.
- חתימת קוד דרך SignPath Foundation, עם build ב-CI ציבורי. אם הבקשה לא תאושר בזמן: חתימה self-signed עם הוראות trust, וסימון ברור של המצב.
- Drift alerts דרך webhook ל-Teams, Slack או email. זהו פיצ'ר Pro, אבל בלי גבייה.
- AIS-MCP-006 (config hash).
- Script read-only בסיסי ל-macOS.

**Exit criteria:**
- פריסה מוצלחת דרך Intune וגם דרך GPO בסביבת lab, מתועדת צעד אחר צעד.
- Release חתום, ו-`Get-AuthenticodeSignature` מחזיר Valid (או fallback מתועד).
- התראת drift מגיעה תוך 24 שעות לכל היותר מרגע הוספת MCP server.
- Zero false-positive קריטי ב-pilot (ניתן לדיווח ב-issue template).

## v1.0: מוצר שלם (יעד: רבעון 1, 2027)
**היקף:**
- Policy engine: allowlist ו-denylist ל-MCP servers ולאפליקציות.
- דוחות compliance: ISO 42001 evidence, EU AI Act inventory ושאלון ביטוח.
- Multi-tenant ל-MSP.
- AIS-ID-002 (קישור לקבוצות AD/Entra privileged).
- macOS parity בסיסי.
- Schema v1 יציב (מתחייבים לא לשבור עד v2).
- קטלוג עם לפחות 60 כלים.

**Exit criteria:**
- לפחות 300 stars ולפחות 10 PRs חיצוניים לקטלוג.
- לפחות 20 tenants פעילים, ולפחות 2 MSPs.
- מוכנות לתמחור Pro: מסמך מחירים ואמצעי תשלום מוגשים לדירקטוריון. **הגבייה מתחילה רק אחרי אישורו.**

## תלויות והחלטות פתוחות
| נושא | מתי | מי מחליט |
|---|---|---|
| חשבון Cloudflare | לפני v0.2 | דירקטוריון |
| שם סופי ומיתוג | לפני release v0.1 | שיווק + מנכ"ל |
| בקשה ל-SignPath | להגיש בשבוע 2 (התהליך לוקח זמן) | הנדסה |
| תמחור Pro ואמצעי תשלום | v1.0 | דירקטוריון |
