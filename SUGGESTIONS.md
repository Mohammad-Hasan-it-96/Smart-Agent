# 💡 اقتراحات التحسين — مشروع المندوب الذكي

> **تاريخ الإعداد:** 12 أبريل 2026
> **الهدف:** رفع جودة التطبيق وتجربة المستخدم وأمانه وقابليته للتوسعة

---

## 🔴 الأولوية العالية (Critical)

### 1. إضافة اختبارات تلقائية (Unit & Widget Tests)
**المشكلة الحالية:** التطبيق لا يحتوي على أي اختبارات تلقائية.
**المقترح:**
- كتابة Unit Tests لـ `ActivationService`، `UpdateService`، `SettingsService`
- كتابة Widget Tests للشاشات الرئيسية
- استخدام `mockito` أو `mocktail` لمحاكاة الـ HTTP والـ Database
```dart
// مثال مقترح
test('isOfflineLimitExceeded returns false when within 72h', () async {
  // ...
});
```

---

### 2. إضافة Dependency Injection (DI)
**المشكلة الحالية:** كل شاشة تُنشئ `ActivationService()` وباقي الخدمات مباشرة بـ `new`، مما يصعّب الاختبار والصيانة.
**المقترح:**
- استخدام `get_it` أو `riverpod` لتسجيل الخدمات كـ singletons
```dart
// مثال مقترح
final getIt = GetIt.instance;
getIt.registerLazySingleton<ActivationService>(() => ActivationService());
```

---

### 3. تأمين مفاتيح API (API Key Security)
**المشكلة الحالية:** عنوان السيرفر `harrypotter.foodsalebot.com` وبيانات التواصل الشخصية مكتوبة مباشرة في الكود (hardcoded).
**المقترح:**
- استخدام ملف `.env` مع `flutter_dotenv`
- أو استخدام `--dart-define` عند البناء
- نقل المفاتيح الحساسة خارج الكود المصدري

---

### 4. إضافة Error Boundary ومعالجة شاملة للأخطاء
**المشكلة الحالية:** بعض الـ `catch` blocks فارغة أو تطبع فقط للـ debug.
**المقترح:**
- استخدام `FlutterError.onError` لتسجيل الأخطاء غير المتوقعة
- استخدام `Sentry` أو `Firebase Crashlytics` لتتبع الأخطاء في الإنتاج
- إضافة رسائل خطأ واضحة للمستخدم في جميع الحالات

---

### 5. إزالة `print()` من كود الإنتاج
**المشكلة الحالية:** يوجد `print()` في `BackupService` و`UpdateService`.
**المقترح:**
- استبدال جميع `print()` بـ Logger مخصص
- استخدام حزمة `logger` أو `logging`
- في الإنتاج: إيقاف التسجيل كلياً أو توجيهه لـ Crashlytics

---

## 🟡 الأولوية المتوسطة (Important)

### 6. إضافة تأكيد قبل حذف البيانات
**المشكلة الحالية:** حذف الأدوية/الشركات/الصيدليات قد يتم بضغطة واحدة.
**المقترح:**
```dart
showDialog(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('تأكيد الحذف'),
    content: const Text('هل أنت متأكد من حذف هذا العنصر؟'),
    actions: [/* إلغاء، تأكيد */],
  ),
);
```

---

### 7. إضافة Pagination للقوائم الطويلة
**المشكلة الحالية:** شاشات الأدوية والصيدليات والطلبيات تجلب كل البيانات مرة واحدة، قد يبطئ التطبيق مع كثرة البيانات.
**المقترح:**
- استخدام `LIMIT` و `OFFSET` في استعلامات SQLite
- تطبيق Infinite Scroll أو Pagination بأزرار
- أو استخدام `flutter_staggered_grid_view` للعرض الفعّال

---

### 8. تحسين أداء البحث (Debouncing)
**المشكلة الحالية:** البحث يُنفَّذ مع كل حرف قد يسبب ضغطاً على قاعدة البيانات.
**المقترح:**
```dart
Timer? _debounce;
void _onSearchChanged(String q) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () {
    _performSearch(q);
  });
}
```

---

### 9. دعم الـ Undo عند الحذف (Snackbar + Undo)
**المقترح:**
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text('تم حذف العنصر'),
    action: SnackBarAction(
      label: 'تراجع',
      onPressed: () => _restore(item),
    ),
    duration: const Duration(seconds: 5),
  ),
);
```

---

### 10. إضافة صفحة تقارير/إحصائيات متقدمة
**المقترح:** إضافة شاشة `ReportsScreen` تتضمن:
- إجمالي المبيعات اليومية/الأسبوعية/الشهرية
- الصيدليات الأكثر طلباً
- الأدوية الأكثر مبيعاً
- رسوم بيانية بسيطة باستخدام `fl_chart`

---

### 11. تحسين نظام التسعير — دعم تعدد العملات
**المشكلة الحالية:** سعر الصرف يُدخله المستخدم يدوياً.
**المقترح:**
- إضافة خيار لتحديث سعر الصرف تلقائياً من API خارجية
- أو جلبه من ملف JSON في السيرفر عند التحديث

---

### 12. إضافة مزامنة بيانات المندوب (Sync)
**المشكلة الحالية:** بيانات الأدوية والشركات لا تُحدَّث من السيرفر.
**المقترح:**
- إضافة endpoint للحصول على قائمة الأدوية المعتمدة من السيرفر
- تحديثها تلقائياً عند كل تشغيل أو عند الطلب
- دمجها مع النظام الحالي

---

### 13. تحسين شاشة `OfflineLimitScreen`
**الوضع الحالي:** تعمل بشكل صحيح (محمية بـ `_isChecking` guard).
**مقترح إضافي:**
- إضافة عداد تنازلي لإظهار متى تجاوز الـ 72 ساعة
- إضافة زر "اتصال بالدعم الفني" مباشرة

---

## 🟢 الأولوية المنخفضة (Nice to Have)

### 14. دعم تعدد اللغات (i18n)
**المقترح:**
- استخدام `flutter_localizations` وملفات `.arb`
- البدء بالعربية كلغة أساسية مع إمكانية إضافة الإنجليزية لاحقاً
- هذا يُسهّل توسيع السوق

---

### 15. إضافة Widget Tests للشاشة الرئيسية
**المقترح:** اختبار الـ Carousel، قائمة الميزات، وبطاقات الإحصائيات

---

### 16. إضافة أنيميشن للانتقالات بين الشاشات
**الوضع الحالي:** يوجد `SlidePageRoute` للانتقال.
**مقترح إضافي:**
- إضافة `FadeTransition` للشاشات Modal
- استخدام `Hero` animations لانتقالات العناصر المشتركة

---

### 17. تحسين أيقونة التطبيق ومظهره في المتجر
**المقترح:**
- إضافة `Splash Screen` لـ iOS بشكل صحيح عبر `LaunchScreen.storyboard`
- تحسين الـ Adaptive Icon لتظهر بشكل مثالي على جميع Launchers
- إضافة Foreground animation لـ Android 12+ Splash API

---

### 18. إضافة Widget للـ Empty States
**الوضع الحالي:** يوجد `empty_state.dart` لكن قد لا يُستخدم في كل مكان.
**المقترح:** التأكد من تطبيقه في جميع القوائم: الطلبيات، الأدوية، الصيدليات، الشركات.

---

### 19. حذف الإشعارات القديمة تلقائياً
**المقترح:** تنظيف الإشعارات القديمة أكثر من 30 يوماً تلقائياً عند كل تشغيل.
```dart
Future<void> purgeOldNotifications() async {
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  await db.delete('notifications',
    where: 'created_at < ?',
    whereArgs: [cutoff.toIso8601String()],
  );
}
```

---

### 20. إضافة Biometric Authentication (اختياري)
**المقترح:** إضافة خيار في الإعدادات لحماية التطبيق ببصمة الإصبع أو الوجه عند الفتح
- استخدام `local_auth` package

---

### 21. إضافة نظام تقييم الصيدليات
**المقترح:** إضافة حقل `rating` أو `notes` لكل صيدلية لمساعدة المندوب في تقييم عملائه.

---

### 22. تحسين PDF المُصدَّر
**المقترح:**
- إضافة شعار الشركة في رأس الفاتورة
- إضافة QR Code للفاتورة
- إضافة خيار لإرسال PDF مباشرة عبر واتساب للصيدلي

---

### 23. إضافة Widget لعرض حالة الاتصال بالإنترنت
**المقترح:** شريط صغير في أعلى/أسفل الشاشة يظهر عند انقطاع الإنترنت
- استخدام `connectivity_plus` package

---

### 24. إضافة تتبع أداء الشبكة
**المشكلة:** timeout محدد بـ 10-15 ثانية لكل الطلبات، لا يوجد retry logic.
**المقترح:**
```dart
// Retry with exponential backoff
Future<T> retryRequest<T>(Future<T> Function() request, {int maxAttempts = 3}) async {
  for (int i = 0; i < maxAttempts; i++) {
    try {
      return await request();
    } catch (e) {
      if (i == maxAttempts - 1) rethrow;
      await Future.delayed(Duration(seconds: pow(2, i).toInt()));
    }
  }
  throw Exception('Max retries exceeded');
}
```

---

### 25. تحسين إدارة Google Drive Backup
**المشكلة الحالية:** يوجد `print()` في الـ error handling، وقد تفشل الاستعادة دون إشعار واضح.
**المقترح:**
- إضافة Progress Indicator أثناء الرفع/التنزيل
- إضافة تأكيد قبل الاستعادة (تحذير من الكتابة فوق البيانات)
- إظهار تاريخ آخر نسخة احتياطية

---

## 📊 ملخص الاقتراحات

| الأولوية | العدد |
|---|---|
| 🔴 عالية (Critical) | 5 |
| 🟡 متوسطة (Important) | 8 |
| 🟢 منخفضة (Nice to Have) | 12 |
| **المجموع** | **25** |

---

## 🗺️ خارطة الطريق المقترحة (Roadmap)

### المرحلة 1 — الجودة والأمان (شهر 1-2)
- [ ] إزالة جميع `print()` وإضافة Logger
- [ ] إضافة Crashlytics
- [ ] نقل بيانات API إلى `.env`
- [ ] إضافة تأكيد الحذف في جميع الشاشات
- [ ] Unit Tests لـ ActivationService

### المرحلة 2 — تحسين تجربة المستخدم (شهر 2-3)
- [ ] Pagination في القوائم
- [ ] Debouncing في البحث
- [ ] Undo Snackbar
- [ ] تحسين PDF بالشعار وـ WhatsApp

### المرحلة 3 — الميزات الجديدة (شهر 3-6)
- [ ] شاشة التقارير والإحصائيات
- [ ] مزامنة قائمة الأدوية من السيرفر
- [ ] دعم تعدد اللغات
- [ ] بيانات واتساب للصيدلي من الفاتورة

---

*تم إعداد هذا الملف بتاريخ 12 أبريل 2026*

