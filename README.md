# RTL Antigravity

[![Platform](https://img.shields.io/badge/platform-Windows-0078D6)](#)
[![PowerShell](https://img.shields.io/badge/language-PowerShell-5391FE)](#)
[![Release](https://img.shields.io/github/v/release/Sajadapp/rtl-antigravity)](https://github.com/Sajadapp/rtl-antigravity/releases)
[![Stars](https://img.shields.io/github/stars/Sajadapp/rtl-antigravity)](https://github.com/Sajadapp/rtl-antigravity/stargazers)

<div dir="rtl">

پچ **راست‌به‌چپ (RTL)** برای چت فارسی در اپلیکیشن **Antigravity** — یک اسکریپت یک‌کلیکی که بعد از هر آپدیت اپ، دوباره اعمال می‌شود.

Antigravity رابط چت را از سرور زبان (language server) سرو می‌کند، بنابراین فایل‌های CSS خودش قابل ویرایش نیستند. این اسکریپت یک استایل‌شیت را داخل شل اپ تزریق می‌کند تا هر پنجره در هر بار لود کامل صفحه آن را دریافت کند.

> این ابزار فایل `app.asar` نصب محلی شما را تغییر می‌دهد. قبل از هر تغییر بکاپ می‌گیرد و در صورت خطا به‌صورت خودکار rollback می‌کند.

## مشکل چیست

در Antigravity متن فارسی در چت درست نمایش داده نمی‌شود:

- جمله‌های فارسی چپ‌چین می‌شوند و علائم نگارشی سر جای خود نیستند.
- ترکیب فارسی و انگلیسی (مثل نام فایل، URL، کد) به‌هم می‌ریزد و کلمات جابه‌جا می‌شوند.

## این پچ چه می‌کند

- حباب‌های پیام کاربر و پاسخ دستیار را راست‌چین می‌کند (`direction: rtl`، `text-align: right`).
- برای پاراگراف‌ها از `unicode-bidi: plaintext` استفاده می‌کند تا جهت هر پاراگراف بر اساس محتوای خودش تعیین شود؛ نتیجه: متن فارسی و انگلیسی قاطی نمی‌شود.
- کد، `pre`، جدول و فرمول‌های ریاضی (KaTeX) را عمداً **چپ‌چین** نگه می‌دارد.
- لیست‌ها (`ul`/`ol`) را برای RTL اصلاح می‌کند.
- فیلد ورودی پیام (`contenteditable`) را راست‌چین می‌کند.

## پیش‌نیازها

| مورد | توضیح |
|---|---|
| Windows | اسکریپت PowerShell است |
| Antigravity | نصب‌شده در `%LOCALAPPDATA%\Programs\antigravity` |
| Node.js | باید `node` روی `PATH` باشد (برای `node --check`) |
| اینترنت | `npx @electron/asar` در اولین اجرا دانلود می‌شود |

## استفاده

1. فایل `RTL Antigravity.cmd` را اجرا کنید (دابل‌کلیک).
2. اسکریپت خودش اپ را می‌بندد، بکاپ می‌گیرد، پچ می‌زند، دوباره پک می‌کند و اپ را باز می‌کند.
3. اگر می‌خواهید اپ خودکار باز نشود:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\RTL Antigravity.ps1" -NoLaunch
```

### اجرای مجدد

اسکریپت **idempotent** است: اگر قبلاً پچ شده باشد (وجود marker `RTL_FARSI_CSS` در `dist/utils.js`)، پیام `Already patched` می‌دهد و خارج می‌شود.

بعد از هر آپدیت Antigravity دوباره اجرا کنید. اگر ساختار داخلی `dist/utils.js` عوض شده باشد، اسکریپت به‌جای خراب‌کردن فایل با پیام `anchor not unique` متوقف می‌شود.

## چه فایل‌هایی تغییر می‌کنند

| مسیر | نقش |
|---|---|
| `%LOCALAPPDATA%\Programs\antigravity\resources\app.asar` | فایل اصلی که پچ می‌شود |
| `app.asar.pre-rtl` | بکاپ خودکار قبل از تغییر |
| `app.asar.unpacked.bak-<timestamp>` | بکاپ موقت درخت unpacked (در پایان پاک می‌شود) |
| `%TEMP%\agy-rtl-repatch\` | پوشه کار موقت |

## بازگردانی (Rollback)

اپ را ببندید و بکاپ را جای فایل اصلی برگردانید:

```powershell
$Res = Join-Path $env:LOCALAPPDATA 'Programs\antigravity\resources'
Copy-Item -LiteralPath (Join-Path $Res 'app.asar.pre-rtl') -Destination (Join-Path $Res 'app.asar') -Force
```

## نکات فنی

- نقطه اتصال (anchor) در `dist/utils.js` تابعی است که `win.loadURL(url)` را صدا می‌زند؛ پچ دقیقاً یک بار جایگزین می‌شود.
- تزریق با `webContents.insertCSS` روی رویداد `did-finish-load` انجام می‌شود، پس با ناوبری SPA از بین نمی‌رود.
- اسکریپت قبل از نصب، خروجی پک‌شده را اعتبارسنجی می‌کند: تعداد entry ها، تعداد فایل‌های unpacked و وجود marker.
- پس از پچ، `node --check` روی `utils.js` اجرا می‌شود.
- پوشه unpacked پیش‌فرض `node_modules/chrome-devtools-mcp` است؛ اگر نسخه شما مسیر دیگری دارد، متغیر `$UnpackD` را در ابتدای اسکریپت تغییر دهید.

## هشدار

این پروژه به Antigravity وابسته نیست و توسط توسعه‌دهنده آن تأیید نشده است. استفاده از آن مسئولیت خودتان است؛ ممکن است با آپدیت‌های آینده یا سیاست‌های اپ ناسازگار شود.

### امنیت
- تنها ارتباط شبکه‌ای، دریافت پکیج **نسخه‌ثابت** `@electron/asar@3.4.1` از npm است (بار اول؛ بعد کش می‌شود). هیچ تلمتری، حساب، توکن یا ارسال داده‌ای وجود ندارد.
- پیام‌ها و مکالمات شما خوانده یا جایی فرستاده نمی‌شود؛ فقط جهت و چینش متن در رابط تغییر می‌کند.
- به دسترسی **Administrator** نیاز ندارد؛ همه‌چیز داخل `%LOCALAPPDATA%`، `%TEMP%` و کش npm انجام می‌شود.
- قبل از هر تغییر از `app.asar` بکاپ گرفته می‌شود و در صورت خطا خودکار rollback می‌شود؛ اگر ساختار فایل داخلی عوض شده باشد، به‌جای خراب‌کردن، متوقف می‌شود.
- کد کامل و قابل بازبینی است؛ همین دو فایل، بدون باینری مخفی.

### جست‌وجو
اگر دنبال این بودی، همین‌جایی: راست‌چین کردن Antigravity، فارسی‌سازی Antigravity، پچ RTL چت Antigravity، متن فارسی در Antigravity به‌هم‌ریخته، Antigravity RTL، Antigravity فارسی، راست به چپ Antigravity، مشکل فارسی Antigravity، فونت و جهت متن Antigravity.

</div>

---

# RTL Antigravity (English)

A one-click **right-to-left (RTL) patch** for Persian/Farsi chat text in the **Antigravity** desktop app.

Antigravity serves its chat UI from the language-server binary, so its own assets cannot be patched. Instead, the shell gets a stylesheet injected into every window on each full page load.

## What it fixes

- Persian conversations are left-aligned and punctuation lands in the wrong place.
- Mixed Persian/English (file names, URLs, code) interleaves and becomes unreadable.

## What the patch does

- Right-aligns user and assistant message bubbles (`direction: rtl`).
- Uses `unicode-bidi: plaintext` per paragraph so each paragraph's direction follows its own content, preventing mixed-direction scrambling.
- Keeps `pre`, `code`, tables and KaTeX math **left-to-right** on purpose.
- Fixes `ul`/`ol` padding for RTL.
- Right-aligns the composer (`contenteditable`).

## Requirements

- Windows + PowerShell
- Antigravity installed at `%LOCALAPPDATA%\Programs\antigravity`
- Node.js on `PATH`
- Network access on first run (`npx @electron/asar`)

## Usage

Run `RTL Antigravity.cmd`, or:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\RTL Antigravity.ps1"
```

The script closes the app, backs up `app.asar`, injects the patch, repacks, verifies, replaces the archive, and relaunches. Pass `-NoLaunch` to skip the relaunch.

Re-run after every Antigravity update. The script is idempotent: if the marker `RTL_FARSI_CSS` is already present it exits immediately.

## Rollback

```powershell
$Res = Join-Path $env:LOCALAPPDATA 'Programs\antigravity\resources'
Copy-Item -LiteralPath (Join-Path $Res 'app.asar.pre-rtl') -Destination (Join-Path $Res 'app.asar') -Force
```

## FAQ

**Does it still work after an Antigravity update?**
Re-run the patcher. It backs up the archive first and refuses to touch it if the internal structure changed, so a broken patch cannot corrupt the app.

**Does it send my data anywhere?**
No. The script only edits the local `app.asar` on your disk. The single outbound request is `npx` fetching the pinned `@electron/asar@3.4.1` package from the npm registry (once, then it is cached).

**Why not a theme/extension?**
Antigravity renders chat from its language server, so there is no extension point for CSS. Injecting a stylesheet into the Electron shell is the only reliable route.

**Will my messages be affected?**
No. Only text direction and alignment are changed; message content and storage are untouched.

## Security

- **One outbound request only:** `npx` downloads the **pinned** `@electron/asar@3.4.1` from the npm registry (first run, then cached). There is no telemetry, no account, no token, and no upload of any kind.
- **Your conversations are never read or transmitted.** Only text direction/alignment in the UI is changed; message content and storage are untouched.
- **No administrator rights.** Everything runs under `%LOCALAPPDATA%`, `%TEMP%` and the npm cache.
- **Reversible by design.** `app.asar` is backed up to `app.asar.pre-rtl` before any change, and the script rolls back automatically if replacement fails. If the internal structure changed after an update, it aborts instead of corrupting the archive.
- **Auditable.** Two plain-text files, no binaries, no obfuscation.
- **Pinned dependency** so a future malicious release of the packaging tool cannot silently run. For a stricter setup, install it once yourself (`npm i -g @electron/asar@3.4.1`) and replace `npx --yes @electron/asar@3.4.1` with `asar` in the script.

## Keywords

Antigravity RTL, Antigravity Persian, Antigravity Farsi, Persian chat support, Farsi UI patch, right-to-left text, RTL patch, bidi text fix, mixed Persian English text, unicode-bidi plaintext, Electron asar patch, app.asar modification, Windows RTL editor, Arabic script support, RTL code editor, Antigravity Persian fix, Antigravity فارسی, راست‌چین کردن Antigravity.

## Disclaimer

Not affiliated with or endorsed by Antigravity. Use at your own risk; a future app update may change the anchor and the script will refuse to run rather than corrupt the archive.
