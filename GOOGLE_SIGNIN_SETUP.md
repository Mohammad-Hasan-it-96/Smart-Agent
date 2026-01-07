# إعداد Google Sign-In للنسخ الاحتياطي

## الخطوات المطلوبة

### 1. الحصول على SHA-1 Certificate Fingerprint

#### للـ Debug Build:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

#### للـ Release Build:
```bash
keytool -list -v -keystore [path-to-your-keystore] -alias [your-key-alias]
```

انسخ SHA-1 من النتيجة (يبدأ بـ `SHA1:`)

### 2. إعداد Google Cloud Console

1. اذهب إلى [Google Cloud Console](https://console.cloud.google.com/)
2. اختر المشروع `lectures-d4f78` أو أنشئ مشروع جديد
3. فعّل **Google Drive API**:
   - اذهب إلى "APIs & Services" > "Library"
   - ابحث عن "Google Drive API"
   - اضغط "Enable"

### 3. إنشاء OAuth 2.0 Client ID

1. اذهب إلى "APIs & Services" > "Credentials"
2. اضغط "Create Credentials" > "OAuth client ID"
3. إذا طُلب منك، أنشئ OAuth consent screen أولاً
4. اختر "Android" كنوع التطبيق
5. أدخل:
   - **Name**: Smart Agent (أو أي اسم)
   - **Package name**: `com.example.lectures`
   - **SHA-1 certificate fingerprint**: الصق SHA-1 الذي حصلت عليه من الخطوة 1
6. اضغط "Create"

### 4. تحديث google-services.json

بعد إنشاء OAuth Client ID، يجب أن يتحدث `google-services.json` تلقائياً. إذا لم يحدث ذلك:

1. اذهب إلى Firebase Console
2. Project Settings > Your apps
3. اختر تطبيق Android
4. حمّل `google-services.json` الجديد
5. استبدل الملف الموجود في `android/app/google-services.json`

### 5. التحقق من الإعدادات

تأكد من:
- ✅ Google Drive API مفعّل
- ✅ OAuth 2.0 Client ID للـ Android موجود
- ✅ SHA-1 مضاف بشكل صحيح
- ✅ Package name يطابق `com.example.lectures`
- ✅ `google-services.json` محدّث

### 6. إعادة بناء التطبيق

```bash
flutter clean
flutter pub get
flutter run
```

## ملاحظات

- SHA-1 للـ Debug و Release مختلفان، أضف كليهما
- قد يستغرق التحديث في Google Cloud Console بضع دقائق
- تأكد من أن Package name في `build.gradle` يطابق ما في Google Cloud Console

