# Налаштування iTACS на чистій Windows

Ця інструкція розрахована на Windows 10/11 x64 і нову робочу машину. Найкоротший шлях до першого запуску — **Web у Chrome**. Для Android потрібні Android Studio, SDK та емулятор. Нативна Windows-збірка є додатковою ціллю й потребує Visual Studio з C++ toolchain.

## 1. Що використовується в проєкті

| Частина | Технології та вимоги |
| --- | --- |
| Клієнт | Flutter, Dart `>=3.8.1 <4.0.0`; `pubspec.lock` вимагає Flutter `>=3.32.0` |
| Основні цілі | Web/Chrome та Android; runner-и також є для Windows, iOS, macOS і Linux |
| Android | API 35, `minSdk 23`, `targetSdk 35`, NDK `27.0.12077973`, Gradle 8.12, Android Gradle Plugin 8.7.3, Kotlin 2.1.0 |
| Backend | Firebase Auth, Cloud Firestore, Cloud Functions, Hosting, Cloud Messaging |
| Авторизація та файли | Google Sign-In і прямі запити до Google Drive API |
| Локальні дані | Hive, SharedPreferences, cache manager |
| Звіти | Dart-пакет `excel`; Cloud Functions використовують `exceljs` |
| Серверні інструменти | Node.js 22 і npm; Firebase CLI; опційно FlutterFire CLI |
| Перевірки | `dart format`, `flutter analyze`, `flutter test`, Node test runner для Functions |

Конфігурація Firebase для чинного проєкту вже лежить у репозиторії:

- `lib/services/firebase_options.dart`;
- `android/app/google-services.json`;
- `firebase.json` і `.firebaserc` (проєкт `gspp-9e089`);
- web client ID у `web/index.html`.

Не запускайте `flutterfire configure` для звичайного локального старту: це не потрібно й може перезаписати чинні platform-конфіги. Команда потрібна лише коли свідомо додається/перереєстровується платформа або Firebase app.

## 2. Базове середовище розробки

Встановіть:

1. [Git for Windows](https://git-scm.com/download/win).
2. [Visual Studio Code](https://code.visualstudio.com/) з розширенням **Flutter** (розширення Dart встановиться як залежність).
3. [Flutter SDK stable](https://docs.flutter.dev/install/with-vs-code). Зберігайте SDK, наприклад, у `C:\src\flutter`, а не в `Program Files`; додайте `C:\src\flutter\bin` до користувацького `PATH`.
4. [Google Chrome](https://www.google.com/chrome/) для web-запуску.
5. [Node.js 22](https://nodejs.org/en/download) — саме ця major-версія вказана в `functions/package.json`. Для самого Flutter-клієнта Node.js не потрібен, але він потрібен для повної роботи з репозиторієм, Functions і Firebase CLI.

Після зміни `PATH` повністю перезапустіть PowerShell і VS Code, потім перевірте:

```powershell
git --version
flutter --version
dart --version
node --version
npm --version
flutter doctor -v
flutter devices
```

Очікується Flutter не старіше 3.32.0, Dart не старіше 3.8.1 і Node `v22.x`. Dart окремо не встановлюється — він входить до Flutter SDK. Попередження `flutter doctor` щодо Android або Visual Studio можна тимчасово ігнорувати, якщо спочатку потрібен лише Web.

## 3. Android toolchain

Встановіть [Android Studio](https://developer.android.com/studio). У **SDK Manager** перевірте наявність:

- Android SDK Platform 35;
- Android SDK Build-Tools;
- Android SDK Platform-Tools;
- Android SDK Command-line Tools (latest);
- Android Emulator;
- NDK (Side by side) версії `27.0.12077973`.

Android Studio постачає сумісний JDK. Якщо Flutter підхопив іншу Java й Gradle скаржиться на версію JDK, укажіть шлях до вбудованого JBR:

```powershell
flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"
```

Прийміть Android SDK licenses і повторно перевірте toolchain:

```powershell
flutter doctor --android-licenses
flutter doctor -v
```

Для емулятора створіть в Android Studio (**Device Manager**) AVD з назвою `Medium_Phone` та образом API 35 з Google Play. Саме цю назву використовує `.vscode/tasks.json`; інший AVD теж працює, але його треба запускати вручну або змінити локальну launch-конфігурацію.

```powershell
flutter emulators
flutter emulators --launch Medium_Phone
flutter devices
```

Для фізичного Android-пристрою ввімкніть Developer options і USB debugging, підтвердьте RSA-запит на телефоні та перевірте його через `flutter devices`.

## 4. Опційно: нативна Windows-збірка

VS Code і Visual Studio — різні програми. Для `flutter run -d windows` встановіть [Visual Studio Community](https://visualstudio.microsoft.com/vs/community/) і workload **Desktop development with C++** разом із рекомендованими компонентами Windows SDK та CMake. Потім виконайте:

```powershell
flutter config --enable-windows-desktop
flutter doctor -v
flutter devices
```

Поточна версія `google_sign_in` у проєкті не має Windows-реєстратора. Windows runner придатний для компіляції та часткової перевірки UI, але Google login на ньому не слід вважати підтриманим сценарієм. Для повної локальної роботи використовуйте Chrome або Android.

iOS і macOS неможливо збирати на Windows: для них потрібні macOS та Xcode. Linux runner присутній, але Firebase options для Linux зараз не налаштовані.

## 5. Клонування та залежності

У PowerShell:

```powershell
git clone <URL-репозиторію> D:\Projects\iTACS
Set-Location D:\Projects\iTACS
git status
flutter pub get
npm ci --prefix functions
# опційно: root Node-залежності з package.json
npm ci
```

`flutter pub get` використовує зафіксований `pubspec.lock`. Не запускайте `flutter pub upgrade` під час первинного сетапу. `npm ci --prefix functions` потрібен для Cloud Functions; root `npm ci` встановлює окремі залежності з кореневого `package.json` і не потрібен для звичайного запуску Flutter-клієнта.

Якщо клон уже є, починайте з `Set-Location`, `git status` та потрібних команд встановлення залежностей.

## 6. Перший запуск

Рекомендований перший запуск:

```powershell
flutter run -d chrome --web-hostname=localhost --web-port=5000
```

Android:

```powershell
flutter emulators --launch Medium_Phone
flutter run -d emulator-5554
```

Якщо ID емулятора відрізняється, візьміть його з `flutter devices`:

```powershell
flutter run -d <device-id>
```

Windows smoke test після встановлення Visual Studio:

```powershell
flutter run -d windows
```

Також можна відкрити workspace у VS Code й скористатися конфігураціями з `.vscode/launch.json`.

## 7. Firebase CLI та доступи

Для локального запуску Firebase CLI не потрібен. Він потрібен для deploy, емуляторів, Functions logs та зміни Firebase-конфігурації.

```powershell
npm install -g firebase-tools
firebase --version
firebase login
firebase projects:list
firebase use
```

`firebase use` має показати `gspp-9e089`. Потрібно входити Google-акаунтом, якому власник надав доступ до цього Firebase-проєкту. Наявність конфігів у Git не дає права на deploy.

FlutterFire CLI потрібна лише для керованої зміни Firebase app configuration:

```powershell
dart pub global activate flutterfire_cli
flutterfire --version
```

Якщо PowerShell не знаходить `flutterfire`, додайте `%LOCALAPPDATA%\Pub\Cache\bin` до користувацького `PATH`. Не запускайте `flutterfire configure` без окремої задачі та перевірки diff.

Для входу в сам застосунок акаунт також повинен:

- бути дозволений у Firestore-колекції `allowed_users`;
- мати доступ до потрібної навчальної групи;
- мати доступ у Google Drive до папок матеріалів/інструментів цієї групи.

## 8. Android Google Sign-In на новій Windows

Нова машина створює новий debug keystore, тому його SHA-1 може бути відсутній у Firebase. Симптом: застосунок збирається, але Google Sign-In на Android завершується `ApiException: 10`, `DEVELOPER_ERROR` або скасуванням після вибору акаунта.

Після першої Android-збірки отримайте fingerprint:

```powershell
Set-Location android
.\gradlew.bat signingReport
Set-Location ..
```

Знайдіть SHA-1 варіанта `debug` і передайте його адміністратору Firebase для додавання до Android app `com.example.flutter_application_1`. Після цього може знадобитися свіжий `android/app/google-services.json`. Не змінюйте та не комітьте Firebase-конфіг без погодження.

Якщо у свіжому clone відсутній `android/gradlew.bat`, не регенеруйте всю Android-папку поверх проєктних налаштувань. Спершу повідомте команді: wrapper має бути відновлений контрольованою зміною репозиторію. Тимчасово fingerprint можна прочитати через `keytool`, якщо debug keystore уже створений:

```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
```

## 9. Web push і VAPID

Public VAPID key уже має fallback у коді та прописаний у VS Code task `BuildWeb`. Для звичайного web-запуску додатковий секрет не потрібен. За потреби ключ можна явно передати:

```powershell
flutter run -d chrome --web-port=5000 --dart-define=FCM_WEB_VAPID_KEY=<public-key>
```

Private VAPID key ніколи не зберігається в репозиторії та не потрібен клієнтській збірці.

## 10. Команди щоденної роботи

```powershell
# залежності Flutter
flutter pub get

# форматування перед завершенням змін
dart format lib test scripts

# для великих/ризикових змін або за окремим запитом
flutter analyze
flutter test

# тести Cloud Functions
npm test --prefix functions

# генерація Hive-коду, лише коли змінені адаптери/моделі
dart run build_runner build --delete-conflicting-outputs

# web build із проєктного VS Code task або вручну
flutter build web
```

Deploy виконуйте лише з відповідними правами та усвідомленням середовища:

```powershell
firebase deploy --only hosting
firebase deploy --only firestore:rules
firebase deploy --only functions
```

Functions використовують Node.js 22 і для deploy потребують Firebase Blaze plan. Не запускайте загальний deploy як тест сетапу.

## 11. Фінальний чекліст

Сетап готовий, якщо:

- `flutter doctor -v` не має помилок для обраної платформи;
- `flutter devices` показує Chrome і/або Android device;
- `flutter pub get` завершується без помилок;
- для роботи з Functions `node --version` показує `v22.x`, а `npm ci --prefix functions` успішний;
- `flutter run -d chrome --web-port=5000` відкриває сторінку входу;
- дозволений акаунт проходить Google login і бачить свою групу;
- для Firebase-роботи `firebase projects:list` показує `gspp-9e089`.

Офіційні довідки: [Flutter на Windows](https://docs.flutter.dev/install/with-vs-code), [Android setup](https://docs.flutter.dev/platform-integration/android/setup), [Windows desktop setup](https://docs.flutter.dev/platform-integration/windows/setup), [Firebase CLI](https://firebase.google.com/docs/cli), [Firebase for Flutter](https://firebase.google.com/docs/flutter/setup).

Якщо Flutter повідомляє `Building with plugins requires symlink support`, увімкніть у Windows **Settings → Privacy & security → For developers → Developer Mode**, перезапустіть IDE й повторіть команду.
