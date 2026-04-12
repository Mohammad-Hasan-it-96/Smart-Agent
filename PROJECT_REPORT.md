# 📋 تقرير شامل عن مشروع — المندوب الذكي (Smart Agent)

> **تاريخ إعداد التقرير:** 12 أبريل 2026
> **مُعدّ بواسطة:** فريق التطوير — مراجعة تقنية كاملة للمشروع

---

## 1. نظرة عامة على التطبيق

| البند | التفاصيل |
|---|---|
| **اسم التطبيق** | المندوب الذكي |
| **الاسم التقني** | `smart_agent` |
| **الإصدار الحالي** | `1.0.9+1009` |
| **منصة التطوير** | Flutter (Dart) |
| **المنصات المدعومة** | Android، iOS |
| **الحد الأدنى لـ SDK** | Dart SDK `>=3.0.0 <4.0.0` |
| **اللغة الافتراضية** | العربية (RTL) |
| **الخط المستخدم** | Cairo (عربي) |
| **نمط التصميم** | Glassmorphism + Material Design 3 |

### وصف التطبيق
نظام متكامل لإدارة الطلبيات الميدانية يُستخدم من قِبَل المناديب التجاريين (خصوصاً في مجال الأدوية)، يعمل بشكل محلي أوف-لاين مع دعم المزامنة والتفعيل عبر السيرفر. يُتيح للمندوب تسجيل وإدارة الطلبيات، الأدوية، الشركات، والصيدليات، مع إمكانية تصدير الفواتير بصيغة PDF.

---

## 2. بنية المشروع (Project Structure)

```
Smart-Agent/
├── lib/
│   ├── main.dart                    # نقطة الدخول الرئيسية
│   ├── core/                        # المنطق المشترك
│   │   ├── db/                      # قاعدة البيانات المحلية
│   │   ├── models/                  # نماذج البيانات
│   │   ├── providers/               # إدارة الحالة
│   │   ├── services/                # الخدمات الأساسية
│   │   ├── theme/                   # الثيم والألوان
│   │   ├── utils/                   # أدوات مساعدة
│   │   └── widgets/                 # ودجت مشتركة
│   ├── features/                    # الميزات (Feature-based Architecture)
│   │   ├── activation/              # التفعيل والاشتراك
│   │   ├── companies/               # إدارة الشركات
│   │   ├── home/                    # الشاشة الرئيسية
│   │   ├── medicines/               # إدارة الأدوية
│   │   ├── onboarding/              # شاشة الترحيب
│   │   ├── orders/                  # إدارة الطلبيات
│   │   ├── pharmacies/              # إدارة الصيدليات
│   │   ├── search/                  # البحث الشامل
│   │   ├── settings/                # الإعدادات
│   │   └── splash/                  # شاشة البداية
│   └── widgets/                     # (محجوز - فارغ حالياً)
├── assets/
│   ├── fonts/Cairo-Regular.ttf      # الخط العربي
│   └── images/                      # الشعارات
├── android/                         # إعدادات أندرويد
├── ios/                             # إعدادات iOS
└── pubspec.yaml                     # إعداد المشروع والتبعيات
```

---

## 3. قاعدة البيانات المحلية (SQLite)

**اسم قاعدة البيانات:** `smart_agent.db`
**الإصدار الحالي:** `v11`

### الجداول

#### 3.1 `companies` — الشركات
| العمود | النوع | الوصف |
|---|---|---|
| `id` | INTEGER PK | معرّف فريد |
| `name` | TEXT | اسم الشركة |

#### 3.2 `medicines` — الأدوية
| العمود | النوع | الوصف |
|---|---|---|
| `id` | INTEGER PK | معرّف فريد |
| `name` | TEXT | اسم الدواء |
| `company_id` | INTEGER | رابط الشركة |
| `price_usd` | REAL | السعر بالدولار |
| `price_syp` | REAL | السعر بالليرة السورية |
| `source` | TEXT | المصدر (محلي/مستورد) |
| `form` | TEXT | الشكل الدوائي (حبوب/شراب...) |
| `notes` | TEXT | ملاحظات |

**الفهارس:** `idx_medicine_name`، `idx_medicine_company`

#### 3.3 `pharmacies` — الصيدليات
| العمود | النوع | الوصف |
|---|---|---|
| `id` | INTEGER PK | معرّف فريد |
| `name` | TEXT | اسم الصيدلية |
| `address` | TEXT | العنوان |
| `phone` | TEXT | رقم الهاتف |

**الفهارس:** `idx_pharmacies_name`

#### 3.4 `orders` — الطلبيات
| العمود | النوع | الوصف |
|---|---|---|
| `id` | INTEGER PK | معرّف فريد |
| `pharmacy_id` | INTEGER | رابط الصيدلية |
| `created_at` | TEXT | تاريخ الإنشاء (ISO 8601) |

**الفهارس:** `idx_orders_date`، `idx_orders_pharmacy`

#### 3.5 `order_items` — عناصر الطلبية
| العمود | النوع | الوصف |
|---|---|---|
| `id` | INTEGER PK | معرّف فريد |
| `order_id` | INTEGER | رابط الطلبية |
| `medicine_id` | INTEGER | رابط الدواء |
| `qty` | INTEGER | الكمية |
| `price` | REAL | السعر |
| `is_gift` | INTEGER | هل هو هدية (0/1) |
| `gift_qty` | INTEGER | كمية الهدية |

#### 3.6 `notifications` — الإشعارات
| العمود | النوع | الوصف |
|---|---|---|
| `id` | INTEGER PK | معرّف فريد |
| `title` | TEXT | عنوان الإشعار |
| `body` | TEXT | نص الإشعار |
| `type` | TEXT | نوع الإشعار |
| `action` | TEXT | الإجراء المرتبط |
| `created_at` | TEXT | تاريخ الاستقبال |
| `is_read` | INTEGER | مقروء (0/1) |

---

## 4. نماذج البيانات (Models)

| الملف | الكلاس | الوصف |
|---|---|---|
| `company.dart` | `Company` | بيانات الشركة |
| `medicine.dart` | `Medicine` | بيانات الدواء مع الأسعار |
| `pharmacy.dart` | `Pharmacy` | بيانات الصيدلية |
| `order.dart` | `Order` | بيانات الطلبية |
| `order_item.dart` | `OrderItem` | عنصر ضمن طلبية |
| `notification_model.dart` | `NotificationModel` | نموذج الإشعار |
| `subscription_plan.dart` | `SubscriptionPlan` | باقة الاشتراك |
| `update_config.dart` | `UpdateConfig` | إعدادات التحديث من السيرفر |

---

## 5. الخدمات (Services)

### 5.1 `ActivationService` — خدمة التفعيل ⭐ (الأهم)
الخدمة الأكثر تعقيداً في التطبيق، تتضمن:

**وظائف التفعيل الأساسية:**
- `getDeviceId()` — إنشاء معرّف جهاز فريد: `SHA256(ANDROID_ID + "smart_agent_app")`
- `sendActivationRequest()` — إرسال طلب تفعيل للسيرفر
- `checkDeviceStatus()` — التحقق من حالة الجهاز على السيرفر
- `isActivated()` — التحقق من حالة التفعيل محلياً
- `isLicenseExpired()` — فحص انتهاء صلاحية الترخيص

**وظائف الوضع التجريبي:**
- `enableTrialMode()` — تفعيل النسخة التجريبية (مرة واحدة فقط)
- `disableTrialMode()` — إيقاف التجريبي عند انتهائه
- `checkTrialLimitPharmacies/Companies/Medicines()` — التحقق من حدود التجريبي

**حدود النسخة التجريبية:**
| العنصر | الحد الأقصى |
|---|---|
| الصيدليات | 1 |
| الشركات | 2 |
| الأدوية | 10 |

**وظائف الأمان:**
- `checkTimeTampering()` — كشف التلاعب بتاريخ الجهاز (حد 5 دقائق)
- `isOfflineLimitExceeded()` — فحص تجاوز 72 ساعة بدون إنترنت
- `_updateLastOnlineSync()` — تحديث وقت آخر اتصال ناجح

**التخزين المحلي (SharedPreferences keys):**
- `is_activated`، `activation_verified`
- `expires_at`، `last_trusted_time`، `time_offset_seconds`
- `last_online_sync`، `offline_limit_exceeded`
- `agent_full_name`، `agent_phone`
- `trial_enabled`، `trial_active`

---

### 5.2 `BackupService` — النسخ الاحتياطي على Google Drive
- تسجيل الدخول بحساب Google
- رفع قاعدة البيانات `smart_agent.db` إلى مجلد `appDataFolder` على Drive
- استعادة قاعدة البيانات من Drive
- الاحتفاظ بنسخة قديمة قبل الاستعادة (`smart_agent.db.old`)

---

### 5.3 `UpdateService` — خدمة التحديث التلقائي
- قراءة ملف JSON من Google Drive لمعرفة آخر إصدار
- مقارنة الإصدار الحالي مع آخر إصدار
- كشف نوع معالج الجهاز (arm64-v8a / armeabi-v7a) لتوفير APK مناسب
- تحديث إعدادات API والدعم الفني من ملف JSON عن بُعد

---

### 5.4 `PushNotificationService` — إشعارات Firebase
- تهيئة Firebase + FCM
- استقبال الإشعارات (foreground + background + app launch)
- إشعارات محلية عند وجود إشعار في المقدمة
- حفظ الإشعارات في قاعدة البيانات
- استقبال إشعار `new_plan_activated` لإعادة التحقق من التفعيل تلقائياً
- إدارة FCM Token وتحديثه تلقائياً على السيرفر

---

### 5.5 `SettingsService` — إعدادات التطبيق
- إدارة عنوان API القابل للتعديل
- إعدادات التسعير (تفعيل/تعطيل، عملة USD/SYP)
- سعر الصرف الدولار إلى الليرة السورية
- رقم هاتف المستودع (للإرسال عبر واتساب)
- بيانات التواصل مع الدعم (إيميل، تيليغرام، واتساب)

**قيم افتراضية:**
- API: `https://harrypotter.foodsalebot.com/api`
- Support Email: `mohamad.hasan.it.96@gmail.com`
- Support Telegram: `https://t.me/+963983820430`
- Support WhatsApp: `963983820430`

---

### 5.6 `DataExportService` — تصدير/استيراد البيانات
- تصدير الشركات والأدوية إلى ملف JSON
- مشاركة الملف عبر `share_plus`
- استيراد ملف JSON وإدراج البيانات في قاعدة البيانات

---

### 5.7 `SubscriptionService` — باقات الاشتراك
- جلب باقات الاشتراك من السيرفر (endpoint: `getPlans`)
- دعم عرض الباقات مع خصومات وتوصيات

---

## 6. الشاشات (Screens)

### 6.1 تدفق التطبيق (App Flow)

```
تشغيل التطبيق
      │
      ▼
[Splash Screen] ──── 2.4 ثانية ────►
      │
      ├─► هل أكمل الـ Onboarding؟
      │         لا ──► [Onboarding Screen]
      │         نعم ──►
      │
      ├─► هل تم تسجيل بيانات المندوب؟
      │         لا ──► [Agent Registration Screen]
      │         نعم ──►
      │
      ├─► هل كُشف تلاعب بالتاريخ؟
      │         نعم ──► Dialog ──► إعادة الاتصال
      │         لا ──►
      │
      ├─► هل تجاوز 72 ساعة بدون نت؟
      │         نعم ──► [Offline Limit Screen]
      │         لا ──►
      │
      ├─► هل انتهى الترخيص/التجريبي؟
      │         نعم ──► [Trial Expired Plans Screen]
      │         لا ──►
      │
      ├─► هل مفعَّل؟
      │         نعم ──► [Home Screen]
      │         لا ──► [Activation Screen]
```

---

### 6.2 قائمة جميع الشاشات

| Route | الشاشة | الوصف |
|---|---|---|
| `/` | `SplashScreen` | شاشة البداية مع الأنيميشن |
| `/onboarding` | `OnboardingScreen` | 3 شرائح تعريفية |
| `/agent-registration` | `AgentRegistrationScreen` | تسجيل بيانات المندوب |
| `/activation` | `ActivationScreen` | تفعيل الجهاز أو بدء التجريبي |
| `/home` | `HomeScreen` | الصفحة الرئيسية |
| `/companies` | `CompaniesScreen` | قائمة الشركات |
| `/medicines` | `MedicinesScreen` | قائمة الأدوية |
| `/pharmacies` | `PharmaciesScreen` | قائمة الصيدليات |
| `/orders` | `OrdersListScreen` | قائمة الطلبيات |
| `/orders/create` | `NewOrderScreen` | إنشاء طلبية جديدة |
| `/settings` | `SettingsScreen` | الإعدادات |
| `/search` | `SearchScreen` | البحث الشامل |
| `/notifications` | `NotificationHistoryScreen` | سجل الإشعارات |
| `/subscription-plans` | `SubscriptionPlansScreen` | باقات الاشتراك |
| `/trial-expired-plans` | `TrialExpiredPlansScreen` | انتهاء التجريبي |
| `/contact-method` | `ContactMethodScreen` | طريقة التواصل |
| `/contact-developer` | `ContactDeveloperScreen` | التواصل مع المطوّر |
| `/offline-limit` | `OfflineLimitScreen` | تجاوز حد الأوف-لاين |

---

### 6.3 تفاصيل الشاشات الرئيسية

#### `HomeScreen` — الصفحة الرئيسية
- **Header** بأسلوب Glassmorphism: ترحيب بالمندوب + شعار + حالة الحساب (مفعّل/تجريبي/منتهي/غير مفعّل)
- **Carousel** إعلاني بـ 3 شرائح (قابل للإخفاء نهائياً) مع تشغيل تلقائي كل 4 ثوانٍ
- **قائمة الميزات** (شبكة 3×2): طلبية جديدة، الطلبيات، الأدوية، الشركات، الصيدليات، الإعدادات
- **ملخص اليوم**: طلبيات اليوم، إجمالي الطلبيات، الصيدليات، الأدوية، الشركات
- **FAB للبحث** الشامل
- تحديث تلقائي للإحصائيات عند العودة من أي شاشة
- فحص دوري لانتهاء الصلاحية

#### `SplashScreen` — شاشة البداية
- خلفية تدرج لوني `#1E3F73` ← `#0B1D3A`
- أنيميشن bounce للشعار (0 ← 1.18 ← 0.93 ← 1.0) خلال 1300ms
- حلقة نبض (pulse ring) متكررة بعد ظهور الشعار
- كشف النص (اسم التطبيق) بأنيميشن slide + fade
- مؤشر تحميل دائري في الأسفل
- تشغيل منطق التوجيه بشكل متوازٍ

#### `NewOrderScreen` — إنشاء طلبية
- اختيار الصيدلية من القائمة
- بحث عن الأدوية + إضافة كميات
- دعم الهدايا (is_gift + gift_qty)
- دعم التسعير بـ USD أو SYP
- حفظ الطلبية في SQLite
- تصدير الطلبية كـ PDF

#### `SettingsScreen` — الإعدادات
- بيانات المندوب (تعديل الاسم والهاتف)
- إعدادات التسعير (تفعيل/تعطيل، عملة، سعر صرف)
- رقم هاتف المستودع
- تصدير/استيراد البيانات (JSON)
- النسخ الاحتياطي على Google Drive
- التحقق اليدوي من التفعيل
- معلومات التواصل مع الدعم
- الوضع المظلم (Dark Mode)
- تحقق من التحديثات
- إصدار التطبيق

---

## 7. إدارة الحالة (State Management)

| الأداة | الاستخدام |
|---|---|
| `Provider` | إدارة ثيم التطبيق (ThemeProvider) |
| `ChangeNotifier` | `HomeController`، `SettingsController` |
| `StatefulWidget` | معظم الشاشات تدير حالتها محلياً |
| `ValueNotifier` | عداد الإشعارات غير المقروءة |

---

## 8. التصميم والثيم

### لوحة الألوان
| اللون | الكود | الاستخدام |
|---|---|---|
| Deep Navy Blue | `#1A4275` | اللون الأساسي |
| Medium Blue | `#2563A8` | اللون الثانوي |
| Sky Blue | `#4A8FD4` | لون التأكيد/Glow |
| Silver Accent | `#B8C4CE` | التفاصيل الرمادية |
| Error Red | `#E53935` | أخطاء |
| Success Green | `#4CAF50` | نجاح |

### الثيم
- دعم **Light Mode** و **Dark Mode** كاملاً
- أسلوب تصميم **Glassmorphism** (بطاقات شفافة، ظلال ناعمة)
- **Material Design 3** مع `useMaterial3: true`
- خط **Cairo** لجميع النصوص العربية
- اتجاه **RTL** كامل للعربية
- زوايا دائرية مخصصة (14px للأزرار والحقول، 20-24px للبطاقات)

---

## 9. نظام التفعيل والترخيص

### آلية التفعيل
```
1. تسجيل بيانات المندوب (اسم + هاتف)
2. توليد Device ID فريد (SHA256 of ANDROID_ID)
3. إرسال طلب للسيرفر (create_device)
4. السيرفر يُعيد: is_verified، expires_at، plan، server_time
5. حفظ الحالة محلياً (SharedPreferences + ملف محلي)
```

### آلية الحماية (Security)
| الميزة | التفاصيل |
|---|---|
| **كشف التلاعب بالتاريخ** | مقارنة وقت الجهاز مع آخر وقت موثوق من السيرفر (حد 5 دقائق) |
| **حد الأوف-لاين** | 72 ساعة بدون اتصال → توجيه لشاشة التحقق |
| **انتهاء الترخيص** | فحص `expires_at` القادمة من السيرفر مع كل تشغيل |
| **حماية من التكرار** | لا يمكن تجربة النسخة التجريبية مرتين (ملف `trial_used_once.flag`) |
| **Double-tap protection** | زر "التحقق" محمي بـ `_isChecking` guard |

### حالات الحساب
| الحالة | اللون | الوصف |
|---|---|---|
| `active` | أخضر | مفعّل وصالح |
| `trial` | برتقالي | نسخة تجريبية |
| `expired` | أحمر | منتهي الصلاحية |
| `unknown` | رمادي | غير مفعّل |

---

## 10. التبعيات (Dependencies)

### تبعيات الإنتاج
| الحزمة | الإصدار | الاستخدام |
|---|---|---|
| `sqflite` | ^2.3.0 | قاعدة البيانات المحلية |
| `path` | ^1.8.3 | مسارات الملفات |
| `path_provider` | ^2.1.2 | مجلدات النظام |
| `provider` | ^6.1.1 | إدارة الحالة |
| `shared_preferences` | ^2.2.2 | التخزين المحلي |
| `pdf` | ^3.10.4 | توليد PDF |
| `printing` | ^5.12.0 | طباعة ومعاينة PDF |
| `http` | ^1.2.0 | طلبات HTTP |
| `device_info_plus` | ^10.1.0 | معلومات الجهاز |
| `android_id` | ^0.4.0 | ANDROID_ID |
| `crypto` | ^3.0.3 | SHA256 hashing |
| `package_info_plus` | ^8.0.0 | معلومات التطبيق |
| `url_launcher` | ^6.2.5 | فتح روابط/أرقام |
| `google_sign_in` | ^6.2.1 | تسجيل الدخول بـ Google |
| `googleapis` | ^13.2.0 | Google Drive API |
| `share_plus` | ^10.1.2 | مشاركة الملفات |
| `file_picker` | ^8.1.4 | اختيار الملفات |
| `firebase_core` | ^3.15.2 | Firebase |
| `firebase_messaging` | ^15.2.4 | FCM Push Notifications |
| `flutter_local_notifications` | ^18.0.1 | إشعارات محلية |
| `flutter_localizations` | SDK | دعم اللغات |

### تبعيات التطوير
| الحزمة | الإصدار | الاستخدام |
|---|---|---|
| `flutter_launcher_icons` | ^0.13.1 | توليد أيقونة التطبيق |
| `flutter_lints` | ^3.0.0 | تحليل الكود |
| `flutter_test` | SDK | الاختبارات |

---

## 11. إعدادات أيقونة التطبيق

```yaml
flutter_icons:
  android: true
  ios: true
  image_path: "assets/images/app_logo.png"
  adaptive_icon_background: "#1B3A6B"       # خلفية زرقاء داكنة
  adaptive_icon_foreground: "assets/images/app_logo_safe.png"
```

---

## 12. API Endpoints

| Endpoint | الطريقة | الوصف |
|---|---|---|
| `create_device` | POST | تسجيل/تفعيل الجهاز |
| `check_device` | POST | التحقق من حالة الجهاز |
| `update_my_data` | POST | تحديث بيانات المندوب |
| `getPlans` | GET | جلب باقات الاشتراك |

**قاعدة URL الافتراضية:** `https://harrypotter.foodsalebot.com/api`

---

## 13. ميزات خاصة

### تصدير PDF
- توليد فاتورة PDF للطلبية تتضمن: اسم الصيدلية، قائمة الأدوية، الكميات، الأسعار، الهدايا
- استخدام خط Cairo للعربية في PDF
- معاينة وطباعة مباشرة

### النسخ الاحتياطي على Google Drive
- رفع قاعدة البيانات كاملة بشكل فوري
- استعادة البيانات من Drive مع الاحتفاظ بنسخة قديمة
- مخزنة في `appDataFolder` (خاصة بالتطبيق)

### تصدير/استيراد JSON
- تصدير الشركات والأدوية كـ JSON قابل للمشاركة
- استيراد JSON من جهاز آخر

### التحديث التلقائي
- فحص الإصدار عند كل تشغيل عبر ملف JSON على Google Drive
- تحميل APK المناسب لنوع المعالج (arm64 / armeabi)
- تحديث إعدادات API و Support عن بُعد

### البحث الشامل
- البحث في الأدوية (مع الشركة)
- البحث في الشركات
- البحث في الصيدليات

---

## 14. إعدادات التوجيه (Routing)

- نظام توجيه مسمّى (Named Routes)
- أنيميشن انتقال `SlidePageRoute` (RTL: يمين لليسار)
- `AppNavigatorKey` للتنقل من خارج السياق (الإشعارات)
- `RouteObserver` للتحديث عند العودة من الشاشات

---

## 15. الإشعارات

### قنوات الإشعارات
| القناة | المعرّف | الأولوية |
|---|---|---|
| Subscription | `subscription_channel` | High |

### أنواع الإشعارات المدعومة
| النوع (`type`) | الوصف |
|---|---|
| `new_plan_activated` | تفعيل اشتراك جديد → يُعيد التحقق تلقائياً |
| `general` | إشعار عام |

---

## 16. إعدادات البناء (Build Config)

**Android:**
- `google-services.json` موجود في `android/app/`
- إعداد Firebase لـ FCM
- `proguard-rules.pro` للـ Release builds
- إعداد Adaptive Icons لـ Android 8+

**Pubspec version:** `1.0.9+1009`

---

## 17. تدفق بيانات الأوف-لاين (Offline Flow)

```
عند كل تشغيل:
  ├── فحص is_offline_limit_exceeded (72h)
  │      ├── تجاوز → شاشة OfflineLimit
  │      └── لم يتجاوز → متابعة
  │
  └── محاولة checkDeviceStatus()
         ├── نجح → تحديث last_online_sync + حالة التفعيل
         └── فشل → المتابعة بالبيانات المخزنة محلياً
```

---

## 18. ملخص إحصائيات الكود

| العنصر | العدد |
|---|---|
| الشاشات الكاملة | 18 شاشة |
| الخدمات (Services) | 13 خدمة |
| النماذج (Models) | 8 نماذج |
| جداول قاعدة البيانات | 6 جداول |
| نقاط API | 4 نقاط |
| الـ Routes المسماة | 17 route |
| المكتبات الخارجية | 20 مكتبة |

---

## 19. معلومات الفريق والتواصل

| البند | التفاصيل |
|---|---|
| **البريد الإلكتروني** | mohamad.hasan.it.96@gmail.com |
| **تيليغرام** | https://t.me/+963983820430 |
| **واتساب** | 963983820430 |

---

## 20. ملاحظات تقنية مهمة

1. **التطبيق يعمل بالكامل Offline** بعد التفعيل الأول — فقط يحتاج إنترنت كل 72 ساعة للتحقق
2. **قاعدة البيانات SQLite** تستخدم نظام migrations منظم (v1 → v11)
3. **الأمان**: معرف الجهاز مشفّر بـ SHA256 ولا يُحفظ ANDROID_ID مباشرة
4. **RTL كامل**: جميع النصوص والتخطيط من اليمين لليسار
5. **الإشعارات** تعمل حتى عند إغلاق التطبيق (Firebase Background Handler)
6. **التحديثات** تُجلب من Google Drive وتدعم ABI detection

---

*تم إعداد هذا التقرير بتاريخ 12 أبريل 2026 بناءً على مراجعة كاملة لكود المشروع*

