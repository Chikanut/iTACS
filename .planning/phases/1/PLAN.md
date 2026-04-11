# Phase 1 — Auth Stability & File Management UX

## Goal

Після завершення фази:
- Користувач перезавантажує сторінку → Firebase Auth відновлюється автоматично → Google Drive доступний без повторного логіну (або з одним кліком "Поновити")
- Матеріали та інструменти оновлюються в реальному часі в усіх вкладках браузера (Firestore stream)
- Додавання/видалення матеріалу одразу відображається в списку без перезавантаження
- Помилки при роботі з файлами показуються явно, а не зникають мовчки

---

## Root Cause Analysis

### Проблема 1: Втрата Google Drive токена при перезавантаженні

**Де:** `lib/services/auth_service.dart`

`_cachedAccessToken` — це статична in-memory змінна. При page reload вона скидається.
`signInSilently()` на web ненадійний — часто повертає `null` якщо вкладка була закрита і відкрита знову.

Критичний баг: `getAccessToken()` викликається з `allowInteractiveRecovery: false`:
```dart
// Поточний код — тихо провалюється
Future<String?> getAccessToken() async {
  return _getAccessTokenForScopes(
    _driveReadScopes,
    allowInteractiveRecovery: false, // ← ніколи не запитує у користувача
    requireScopeConfirmation: false,
  );
}
```
Результат: читання файлів (відкрити, завантажити) повертає null токен → `MetadataException` → помилка в UI.

Водночас `getDriveWriteAccessToken()` вже має `allowInteractiveRecovery: true` — тому запис іноді працює, а читання — ні. Асиметрія.

### Проблема 2: Матеріали — one-shot Future без real-time оновлень

**Де:** `lib/services/materials_service.dart` + `lib/pages/materials_page/materials_page.dart`

`getMaterials()` — це `Future` що викликається один раз при `initState`. Результат зберігається у widget state. Кожен браузер/вкладка має свою копію. Зміни (додавання, видалення) не поширюються між вкладками.

Firestore overlay (колекція `materials/{groupId}/items`) вже підтримує streams — це стандартний `collection().snapshots()`. Але поточний код використовує `get()` замість `snapshots()`.

### Проблема 3: Silent failures приховують помилки

**Де:** `lib/pages/materials_page/material_dialogs.dart` рядки 108, 129, 243, 262

```dart
} catch (_) {}  // помилка поглинається — користувач нічого не бачить
```

---

## Tasks

### Task 1.1 — Drive Session Recovery: Auth layer

**Files:** `lib/services/auth_service.dart`

**Changes:**

1. Додати `bool get isDriveSessionAvailable => _currentGoogleUser != null;`

2. Додати публічний метод `reconnectDrive()` для явного відновлення Drive сесії:
```dart
Future<bool> reconnectDrive() async {
  try {
    final account = await _googleSignInWithDrive.signIn();
    if (account == null) return false;
    _currentGoogleUser = account;
    final auth = await account.authentication;
    _cachedAccessToken = auth.accessToken;
    _tokenExpirationTime = DateTime.now().add(const Duration(hours: 1));
    await _saveSignInState(true);
    return true;
  } catch (e) {
    debugPrint('AuthService: reconnectDrive failed: $e');
    return false;
  }
}
```

3. Виправити `getAccessToken()` — дозволити interactive recovery як fallback:
```dart
Future<String?> getAccessToken() async {
  return _getAccessTokenForScopes(
    _driveReadScopes,
    allowInteractiveRecovery: true,  // було false
    requireScopeConfirmation: false,
  );
}
```
Це означає: якщо `signInSilently()` провалився, але Firebase user є → один раз показати Google sign-in popup. Popup триггериться по user gesture (tap "відкрити файл") → browser popup blocker не заблокує.

**Verification:** `isDriveSessionAvailable` повертає `false` після hot reload без попереднього логіну → `true` після виклику `reconnectDrive()`.

---

### Task 1.2 — Drive Session Recovery: UI Banner

**Files:**
- Новий файл: `lib/widgets/drive_session_banner.dart`
- `lib/pages/materials_page/materials_page.dart`
- `lib/pages/tools_page/tools_page.dart`

**New widget `DriveSessionBanner`:**

Stateful widget. При `initState` перевіряє `Globals.authService.isDriveSessionAvailable`.
Якщо `false` — показує жовтий banner:

```
⚠️  Google Drive сесія не відновлена — файли можуть бути недоступні
                                          [Поновити зв'язок]
```

При натисканні "Поновити зв'язок":
1. Показати `CircularProgressIndicator` замість кнопки
2. Викликати `await Globals.authService.reconnectDrive()`
3. Якщо успішно → сховати banner → сповістити батьківський віджет через callback `onReconnected`
4. Якщо помилка → показати `ErrorNotificationManager.showError()`

```dart
class DriveSessionBanner extends StatefulWidget {
  const DriveSessionBanner({super.key, required this.onReconnected});
  final VoidCallback onReconnected;
  // ...
}
```

**Integration в MaterialsPage:** Додати `DriveSessionBanner` над списком матеріалів.
У `onReconnected` → викликати `fetchMaterials()` щоб оновити список після відновлення Drive.

**Integration в ToolsPage:** Аналогічно.

**Verification:** Після page reload (без Drive сесії) — banner видно. Tap "Поновити зв'язок" → Google popup → після auth banner зникає → список оновлюється.

---

### Task 1.3 — Materials: Firestore real-time stream

**Files:**
- `lib/services/materials_service.dart`
- `lib/pages/materials_page/materials_page.dart`

**Зміни в MaterialsService:**

Додати новий метод поруч із `getMaterials()`:

```dart
Stream<List<Map<String, dynamic>>> streamOverlayMaterials({
  required String groupId,
}) {
  return Globals.firestoreManager
      .streamDocumentsForGroup(groupId: groupId, collection: 'materials')
      .map((docs) => docs.map(_mapDocToMaterial).toList(growable: false));
}

Map<String, dynamic> _mapDocToMaterial(DocumentSnapshot doc) {
  // Існуюча логіка з _getOverlayMaterials, витягнута в окремий метод
}
```

Потрібно додати `streamDocumentsForGroup` до `FirestoreManager`:
```dart
Stream<List<DocumentSnapshot>> streamDocumentsForGroup({
  required String groupId,
  required String collection,
}) {
  return _db
      .collection('$collection/$groupId/items')
      .snapshots()
      .map((snap) => snap.docs);
}
```

**Зміни в MaterialsPage:**

Конвертувати з one-shot fetch на StreamSubscription:

```dart
StreamSubscription? _materialsSubscription;

@override
void initState() {
  super.initState();
  _hydrateCachedMaterials();           // залишити як є (швидкий показ з кешу)
  _subscribeToMaterialsStream();       // нова підписка
  unawaited(_loadDriveFolderFiles());  // Drive частина — окремо, один раз
}

void _subscribeToMaterialsStream() {
  final groupId = Globals.profileManager.currentGroupId;
  if (groupId == null) return;

  _materialsSubscription = _materialsService
      .streamOverlayMaterials(groupId: groupId)
      .listen((overlayItems) {
        // Merge overlay з вже завантаженими Drive files
        _mergeAndUpdate(overlayItems);
      }, onError: (e) {
        debugPrint('MaterialsPage: stream error: $e');
      });
}

@override
void dispose() {
  _materialsSubscription?.cancel();
  // ...
  super.dispose();
}
```

`_loadDriveFolderFiles()` — завантажує Drive folder files один раз при старті та після `onReconnected`.

**Примітка:** Drive folder listing НЕ потрібно стрімити (Drive API не підтримує webhooks в browser). Достатньо: Firestore overlay — real-time stream, Drive files — on-demand fetch.

**Verification:** Відкрити 2 вкладки → в одній додати матеріал → другий браузер автоматично показує новий матеріал без refresh.

---

### Task 1.4 — Fix silent failures in material_dialogs.dart

**Files:** `lib/pages/materials_page/material_dialogs.dart`

**Зміни:**

Замінити всі `catch (_) {}` на логований fallback:

1. **Рядок 108** (`_loadSuggestedTags`):
```dart
} catch (e) {
  debugPrint('MaterialDialog: failed to load suggested tags: $e');
  // Показуємо порожній список тегів — не критично
}
```

2. **Рядок 129** (`_loadCatalogConfig`):
```dart
} catch (e) {
  debugPrint('MaterialDialog: failed to load catalog config: $e');
  if (mounted) setState(() => _useManualLink = true); // fallback на ручне посилання
}
```

3. **Рядок 243** (metadata при update через Drive):
```dart
} catch (e) {
  debugPrint('MaterialDialog: could not fetch metadata for file $fileId: $e');
  // modifiedAt залишається DateTime.now() — прийнятний fallback
}
```

4. **Рядок 262** (metadata при manual URL):
```dart
} catch (e) {
  debugPrint('MaterialDialog: could not fetch metadata for manual url: $e');
  // modifiedAt залишається DateTime.now() — прийнятний fallback
}
```

Також виправити `_pasteFromClipboard` (рядок 181):
```dart
} catch (e) {
  debugPrint('MaterialDialog: clipboard read failed: $e');
  // Silently ignore — клавіатурний буфер може бути заблокований
}
```

**Verification:** Відкрити матеріал dialog при відсутньому Drive токені → замість тихого збою показується fallback "ручне посилання".

---

## File Summary

| File | Action | Notes |
|------|--------|-------|
| `lib/services/auth_service.dart` | Modify | Add `isDriveSessionAvailable`, `reconnectDrive()`, fix `getAccessToken()` |
| `lib/services/materials_service.dart` | Modify | Add `streamOverlayMaterials()`, extract `_mapDocToMaterial()` |
| `lib/services/firestore_manager.dart` | Modify | Add `streamDocumentsForGroup()` |
| `lib/widgets/drive_session_banner.dart` | Create | Drive reconnect banner widget |
| `lib/pages/materials_page/materials_page.dart` | Modify | Add banner, switch to stream subscription |
| `lib/pages/tools_page/tools_page.dart` | Modify | Add banner, same pattern as materials |
| `lib/pages/materials_page/material_dialogs.dart` | Modify | Replace silent catch blocks |

---

## Implementation Order

1. `auth_service.dart` (Task 1.1) — основа, від якої залежить все
2. `drive_session_banner.dart` (Task 1.2 widget) — standalone, немає залежностей
3. `firestore_manager.dart` + `materials_service.dart` (Task 1.3 service layer) — stream infrastructure
4. `materials_page.dart` + `tools_page.dart` (Task 1.2 integration + Task 1.3 UI) — всі попередні задачі мають бути готові
5. `material_dialogs.dart` (Task 1.4) — незалежна, може паралельно з Task 1.3

---

## UAT Criteria (Definition of Done)

1. **Auth restore:** Після `Ctrl+F5` (hard reload) → Firebase Auth відновлюється → Materials page завантажується → якщо Drive сесія не відновлена автоматично → видно `DriveSessionBanner` → tap "Поновити" → popup → логін → banner зникає → файли відкриваються
2. **Real-time sync:** 2 вкладки відкриті на Materials → адмін додає матеріал в першій → в другій матеріал з'являється без refresh (≤3 сек)
3. **No silent failures:** При відсутньому Drive token у `MaterialDialog` → відображається форма з `_useManualLink = true` і логується помилка замість тихого збою
4. **Token recovery:** Відкрити файл при протермінованому токені → автоматично спробується silent sign-in → якщо не вдалося → Google popup → після auth файл відкривається

---

## Out of Scope (цієї фази)

- Реальне offline editing — лише read-only cache (вже є)
- Firebase Storage замість Google Drive
- Tools сторінка streaming (зробити в наступній фазі після materials)
- Streaming для Drive folder listing (Drive API не підтримує webhooks в browser context)
- Renaming / moving files in Drive UI

---

*Plan created: 2026-03-27*
