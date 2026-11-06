# تحدّي العباقرة

لعبة أسئلة عربية ثلاثية الأبعاد مبنية باستخدام **Godot 4.4.1**، ومصممة للعمل دون اتصال بالإنترنت على Android.

## الموجود حاليًا

- واجهة عربية واتجاه كتابة من اليمين إلى اليسار.
- مشهد ثلاثي الأبعاد بعناصر هندسية مضيئة.
- أسئلة محلية في العلوم والتاريخ والجغرافيا والرياضيات والمنطق.
- نظام نقاط (10 نقاط لكل إجابة صحيحة).
- توضيح الإجابة الصحيحة مع معلومة قصيرة.
- ترتيب عشوائي للأسئلة وإعادة اللعب.

## البناء من GitHub

يعمل سير العمل تلقائيًا عند كل تحديث على فرع `main)، ويمكن تشغيله يدويًا من تبويب **Actions** عبر **Build Android APK**.

بعد نجاح البناء:
1. افتح تبويب Actions في المستودع.
2. اختر آخر عملية Build Android APK ناجحة.
3. نزّل ملف artifact باسم `challenge-android-apk`.
4. ستجد داخله `Challenge.apk`.

## إعدادات Android

- Application ID: `com.mahdialloui.challenge`
- الإصدار الابتدائي: `1.0.0` (version code 1)
- المعمارية: ARM64
- لا يتطلب اتصال إنترنت أثناء اللعب.

> هذه نسخة تأسيسية قابلة للتطوير. لم يتم اعتمادها كإصدار نهائي قبل نجاح اختبار البناء والتشغيل على جهاز Android.


## World journey prototype

The game now includes offline Natural Earth country boundaries, a rotatable 3D globe, sequential country unlocking, and an initial multidisciplinary Algeria question bank. Country boundaries and quiz content are packaged locally for offline play.


## Realistic offline Earth globe

The Android build creates an offline 5400 × 2700 NASA Blue Marble topography texture and bakes the Natural Earth country boundaries into the equirectangular map at their geographic longitude/latitude positions. The globe uses a custom UV sphere that matches the same geographic coordinate system used by country selection. NASA Blue Marble source: https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-topography/ (NASA imagery); country boundaries: Natural Earth 1:110m Admin-0, public-domain data.


## Offline multi-scale satellite map

- Global view: NASA Blue Marble base-topography texture with Natural Earth country boundaries.
- Regional zoom: an offline North Africa satellite mosaic (northern Algeria, Tunisia and nearby coast) is assembled from NASA GIBS MODIS Terra Corrected Reflectance True Color tiles during the Android build.
- The regional layer is mapped to its real longitude/latitude bounds on the 3D globe and appears when the player zooms in. It is packaged in the APK, so the map does not need a network connection during play.
- The regional imagery is satellite browse imagery, not Google Earth building-level photography; street/building detail would require a separate licensed/open high-resolution dataset.

NASA GIBS imagery service: https://nasa-gibs.github.io/gibs-api-docs/ (NASA Earth science visualization tiles). NASA Blue Marble base map: https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-topography/.
