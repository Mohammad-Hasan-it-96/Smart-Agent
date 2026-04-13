# Smart Agent — Release Readiness Checklist
> Version: 1.0.9+1009 · Date: April 2026

---

## ⚠️ RELEASE BLOCKERS (must fix before shipping)

| # | Item | Status |
|---|------|--------|
| 1 | **Release signing keystore** — `build.gradle` currently uses `signingConfigs.debug`. Replace with a real release keystore before distributing APKs. | ❌ TODO |
| 2 | **Google Drive update JSON** — Ensure the file at `https://drive.google.com/uc?export=download&id=1aMv_VNEFff1XzQeiG80s0aEL4r5_c9ao` is publicly shared and returns raw JSON (not an HTML redirect page) with `latest_version` and `downloads` fields. | ❌ Verify |
| 3 | **`android:usesCleartextTraffic="true"`** — Required only if the activation server uses plain HTTP. If the server is HTTPS-only, remove this flag for production hardening. | ⚠️ Verify |

---

## ✅ Pre-Ship Config Verification

| # | Item | Notes |
|---|------|-------|
| 1 | `applicationId` | `com.mohamad.hasan.org.smart.agent` — unique, confirmed |
| 2 | `versionName` / `versionCode` | Sourced from `pubspec.yaml` `version: 1.0.9+1009` |
| 3 | Firebase `google-services.json` | Present in `android/app/`. Verify it matches the correct Firebase project |
| 4 | API base URL | `https://harrypotter.foodsalebot.com/api` — confirm server is live |
| 5 | Support contacts | Email / Telegram / WhatsApp in `SettingsService` defaults — verify correct |
| 6 | `minSdk = 24` | Android 7.0+ — good coverage |
| 7 | `targetSdk = 35` | Android 15 — confirmed |
| 8 | ProGuard rules | Extended in `proguard-rules.pro` to protect Firebase, SQLite, Bluetooth, Flutter embedder |
| 9 | `debugShowCheckedModeBanner: false` | ✅ Already set in `main.dart` |
| 10 | Portrait-only lock | ✅ Enforced via `SystemChrome.setPreferredOrientations` |

---

## 📋 Manual QA Checklist (Real Device — Android)

### 1. Activation Flow
- [ ] Fresh install → Splash → Onboarding → Registration screen appears
- [ ] Enter name + phone → tap Activate → server responds correctly
- [ ] Verified activation → Home screen loads
- [ ] Expired/unverified state → redirected to Activation screen
- [ ] "Re-check activation" in Settings syncs with server and shows correct status
- [ ] Settings shows correct plan, expiry date, device ID

### 2. Create Order
- [ ] Tap New Order → pharmacy picker appears
- [ ] Select pharmacy → medicine search works
- [ ] Add medicine (regular qty)
- [ ] Add medicine with gift qty
- [ ] Add gift-only item
- [ ] Save order → success message shown
- [ ] Order appears in daily list

### 3. Edit Order
- [ ] Open order details → tap Edit (pencil icon in AppBar)
- [ ] Existing items are pre-loaded in the form
- [ ] Add a new item, remove an existing one
- [ ] Save → details screen refreshes with updated data
- [ ] Verify DB: original order_items replaced with new set

### 4. Delete Order
- [ ] Open order details → tap Delete (trash icon in AppBar)
- [ ] Confirmation dialog appears
- [ ] Tap Cancel → nothing happens
- [ ] Tap Delete → order and all order_items removed from DB
- [ ] Navigated back to daily list, order is gone
- [ ] List refreshes automatically

### 5. Global Search Navigation
- [ ] Tap search icon → Search screen opens
- [ ] Type a pharmacy name → results appear
- [ ] Tap result → navigates to correct screen
- [ ] Search for medicine → correct result shown
- [ ] Empty query → shows empty state (no crash)
- [ ] Back button returns to previous screen

### 6. Advanced Order Filters
- [ ] Open Orders list → tap Filter button
- [ ] Select month filter → list narrows correctly
- [ ] Select date range → list narrows correctly
- [ ] Select specific pharmacies → filter applies
- [ ] Select specific companies → filter applies
- [ ] Combine multiple filters → combined result correct
- [ ] Clear filter → full list restores
- [ ] Active filter indicator is visible when filter is on

### 7. PDF Export
- [ ] Order Details → tap "تصدير PDF" → share sheet appears
- [ ] PDF opens and renders Arabic text correctly (Cairo font)
- [ ] Pharmacy name, date, items, total all present
- [ ] Orders List → tap PDF button → filtered report generated
- [ ] Filtered PDF includes correct filter summary section
- [ ] Share to WhatsApp (PDF file) works from order details
- [ ] Send text message to inventory works

### 8. Update Flow from Server
- [ ] Settings → "التحقق من التحديثات" → loading spinner appears
- [ ] If server returns newer version → update dialog shown with notes
- [ ] Tap "تحميل التحديث" → browser opens direct download URL
- [ ] If already up-to-date → "لا يوجد تحديث جديد" dialog shown
- [ ] Network offline → graceful error message (no crash)
- [ ] Server JSON must be at: Google Drive file `1aMv_VNEFff1XzQeiG80s0aEL4r5_c9ao` (direct-download export URL)

### 9. Bluetooth Printer Flow
- [ ] Order Details → tap "طباعة بلوتوث"
- [ ] **First time**: printer selection dialog shows paired devices
- [ ] Select printer → connecting progress dialog shown
- [ ] Print completes → success snackbar with printer name
- [ ] **Second time**: auto-connects to saved printer silently
- [ ] If saved printer unavailable → falls back to manual selection dialog
- [ ] Invoice printout contains: pharmacy name, date, agent name, item list with qty, total qty
- [ ] No BT devices paired → informative snackbar (no crash)
- [ ] Print error → error snackbar (no crash)
- [ ] Preferred printer survives app restart

---

## 🔐 Android Permissions — Verified

| Permission | Purpose | Declared |
|-----------|---------|---------|
| `INTERNET` | Activation, update check | ✅ |
| `POST_NOTIFICATIONS` | FCM push | ✅ |
| `BLUETOOTH` + `BLUETOOTH_ADMIN` (≤API 30) | BT printing legacy | ✅ |
| `ACCESS_FINE_LOCATION` + `COARSE_LOCATION` (≤API 30) | BT scan on Android 11 | ✅ |
| `BLUETOOTH_SCAN` (API 31+) | BT scan Android 12+ | ✅ |
| `BLUETOOTH_CONNECT` | BT connect | ✅ |
| FileProvider | PDF sharing via WhatsApp | ✅ |
| WhatsApp package visibility | Direct PDF share | ✅ |

---

## 🔴 Risky Areas — Require Real-Device Testing

| Area | Risk | Notes |
|------|------|-------|
| **Bluetooth printing** | High | Depends on printer model/firmware. Test with actual ESC/POS thermal printer. Arabic text may not render on all printers (ASCII-only fallback). |
| **WhatsApp PDF share** | Medium | Uses native Android channel (`sharePdfToWhatsApp`). Test with both WhatsApp and WhatsApp Business installed. |
| **Activation offline limit** | Medium | 72-hour offline window — test by disabling network and checking behaviour at boundary. |
| **Time tamper guard** | Medium | Setting device clock back should revoke activation. Test manually on real device. |
| **R8 / ProGuard in release** | Medium | `minifyEnabled true` + `shrinkResources true` — always install a release APK (not debug) and test full flow before distributing. |
| **Update download on Android 14+** | Low-Medium | Installing APKs from browser requires "Install unknown apps" permission — document this for users. |
| **FCM on device without GMS** | Low | Push notifications won't work on Huawei/AOSP devices without GMS. App should not crash. |
| **PDF Arabic font** | Low | Cairo font is bundled in assets. Verify it loads correctly in release build (ProGuard must not strip assets). |

---

## 📝 Server-Side Checklist

```json
// Required: GET {API_BASE}/app_update → 200 JSON
{
  "latest_version": "1.0.9",
  "downloads": {
    "arm64-v8a": "https://yourserver.com/app-arm64.apk",
    "armeabi-v7a": "https://yourserver.com/app-arm32.apk",
    "default": "https://yourserver.com/app-latest.apk"
  },
  "update_notes": ["وصف التحديث هنا"],
  "api": { "base_url": "https://yourserver.com/api" },
  "support": {
    "email": "support@yourcompany.com",
    "telegram": "https://t.me/yourchannel",
    "whatsapp": "963XXXXXXXXX"
  }
}
```

---

## 🚀 Build Command for Release APK

```bash
# Clean + build release APK (split by ABI for smaller size)
flutter clean
flutter build apk --release --split-per-abi

# Output files:
# build/app/outputs/apk/release/app-arm64-v8a-release.apk   ← most phones
# build/app/outputs/apk/release/app-armeabi-v7a-release.apk ← older 32-bit
```

> **Before distributing**: replace `signingConfigs.debug` in `android/app/build.gradle`
> with a proper release keystore.

---

## ✅ Automated Test Status

```
140 tests — All passed ✓
```

Tests cover: ActivationService, BluetoothPrintService, OfflineLimitGuard,
TimeTamperGuard, TrialModeService.

