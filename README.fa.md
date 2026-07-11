# NetStatusWidget

[English](README.md)

یه اپ نوار منوی مک که در لحظه نشون می‌ده:

- پروکسی (HTTP/HTTPS/SOCKS یا PAC خودکار) ست شده یا نه
- DNS به‌صورت دستی تنظیم شده یا نه
- VPN فعاله یا نه، و اگه فعاله چه VPN‌ای
- به چه شبکه‌ای وصلی (نام Wi-Fi یا سرویس Ethernet)

## دانلود (بدون نیاز به بیلد)

1. آخرین فایل `NetStatusWidget-*-macos.zip` رو از صفحه‌ی [Releases](../../releases) بردار.
2. بازش کن (unzip) و `NetStatusWidget.app` رو بکش توی `/Applications`.
3. این نسخه با **امضای رسمی اپل (Developer ID) امضا نشده**، پس دفعه‌ی اول که بازش می‌کنی macOS
   (Gatekeeper) با پیام "توسعه‌دهنده ناشناس" جلوش رو می‌گیره. برای بازکردنش:
   - روی `NetStatusWidget.app` راست‌کلیک (یا Control-click) کن → **Open** → توی دیالوگ باز هم
     **Open** رو تأیید کن.
   - اگه بازم کار نکرد، توی ترمینال بزن: `xattr -cr /Applications/NetStatusWidget.app`
4. یه آیکون شبکه توی نوار منو ظاهر می‌شه. روش کلیک کن تا پنل وضعیت باز بشه.

### اعتبارسنجی فایل دانلودشده

چون این بیلد فقط امضای ad-hoc داره (نه امضای رسمی اپل)، نمی‌شه با امضا مطمئن شد فایل دست‌نخورده
مونده. هر [Release](../../releases) یه چک‌سام SHA256 برای zip خودش منتشر می‌کنه — قبل از باز
کردن اپ، فایلی که دانلود کردی رو باهاش مقایسه کن:

```bash
shasum -a 256 NetStatusWidget-*-macos.zip
```

خروجی رو با چک‌سامی که توی صفحه‌ی همون Release نوشته شده مقایسه کن. اگه یکی نبود، اپ رو باز نکن
و دوباره از صفحه‌ی رسمی Releases دانلود کن.

## بیلد از روی سورس

نیاز به Xcode Command Line Tools (`xcode-select --install`) و Swift نسخه‌ی 5.9 به بالا داره.

```bash
swift run
```

## ساخت نسخه‌ی release

```bash
./scripts/build_app.sh 1.0.0
```

خروجیش `dist/NetStatusWidget.app` و `dist/NetStatusWidget-1.0.0-macos.zip` هست که آماده‌ی پیوست
به یه GitHub Release هستن. آیکون اپ از قبل توی `Packaging/AppIcon.icns` ساخته شده؛ اگه خواستی از
اول بسازیش:

```bash
swiftc scripts/generate_icon.swift -o /tmp/gen_icon -framework AppKit
/tmp/gen_icon Packaging/AppIcon.iconset
iconutil -c icns Packaging/AppIcon.iconset -o Packaging/AppIcon.icns
rm -rf Packaging/AppIcon.iconset
```

وقتی یه release جدید می‌سازی، چک‌سام SHA256 فایل zip رو توی توضیحات release منتشر کن:

```bash
shasum -a 256 dist/NetStatusWidget-1.0.0-macos.zip
```

## نکات فنی

- اپ فقط از `networksetup`، `scutil` و `route` استفاده می‌کنه — همه‌شون فقط خواندنی هستن و به
  دسترسی بالا (elevated permissions) نیازی ندارن.
- تشخیص VPN اول سرویس‌های VPN سیستمی رو چک می‌کنه (`scutil --nc list`)؛ اگه هیچ‌کدوم وصل نبود،
  می‌ره سراغ رابط‌های تونل فعال (`utunN`) و اپ‌های شناخته‌شده‌ی VPN که در حال اجرا هستن
  (Tailscale, NordVPN, WireGuard و امثالشون).
- اپ هیچ تماس شبکه‌ای، تله‌متری، یا کار با اطلاعات حساس نداره — فقط تنظیمات شبکه‌ی لوکال رو
  می‌خونه.
- بیلد فقط ad-hoc امضا شده. اگه این پروژه یه روز مشارکت خارجی (PR) قبول کنه، قبل از هر release
  حتماً کد رو دستی ریویو کن — چون هیچ لایه‌ی notarization اپل برای گرفتن باینری دستکاری‌شده وجود
  نداره.
