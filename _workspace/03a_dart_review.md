# Dart Review — Date/Bucketlist Feature
**리뷰어:** dart-reviewer
**날짜:** 2026-04-28
**대상 커밋:** main (latest)

---

[REVIEW RESULT]

---

### 1. Firebase 안전성

- 심각도: CRITICAL
- 항목: `_DropTrackerPageState.initState()`에서 `ref.onValue.listen()` 구독 후 반환된 `StreamSubscription`을 저장하지 않아 `dispose()`에서 `cancel()` 불가. 위젯 해제 후에도 Firebase 이벤트가 계속 수신되어 `setState()` 호출 → `mounted` 체크도 없음.
- 위치: `lib/main.dart:341` (`_DropTrackerPageState.initState`)
- 수정 방향: `StreamSubscription? _dropSub;` 필드 추가 → `_dropSub = ref.onValue.listen(...)` → `dispose()`에 `_dropSub?.cancel();` 추가. 리스너 내부 `setState` 앞에 `if (mounted)` 체크 추가.

---

- 심각도: WARNING
- 항목: `_DropTrackerPageState` 리스너 내부의 `setState(...)` 호출에 `if (mounted)` 체크 없음. 위젯 해제 후 호출 시 assertion 오류 발생 가능.
- 위치: `lib/main.dart:345` (`ref.onValue.listen` 콜백 내)
- 수정 방향: `if (mounted) setState(() { ... });` 로 감싸기.

---

- 심각도: INFO
- 항목: Firebase 경로 패턴 준수 확인 완료.
  - `users/${widget.userKey}/dates` ✅
  - `users/${widget.userKey}/bucketlist` ✅
  - `users/${widget.userKey}/drops` ✅
  - `app_version` (인증 불필요 공용 경로) ✅
- 위치: 전체
- 수정 방향: 없음.

---

- 심각도: INFO
- 항목: `DatePage._sub` / `BucketlistPage._sub` — `dispose()`에서 정상 `cancel()` 처리됨. `WidgetsBindingObserver` `removeObserver()` 처리도 정상.
- 위치: `lib/main.dart:1382~1386`, `1713~1715`
- 수정 방향: 없음.

---

### 2. Flutter 코드 품질

- 심각도: INFO
- 항목: `_SlideFadeItem` — `Future.delayed` 후 `if (mounted) _ctrl.forward()` 체크 정상. `_ctrl.dispose()` dispose에서 처리됨.
- 위치: `lib/main.dart:1333~1334`
- 수정 방향: 없음.

---

- 심각도: INFO
- 항목: `_AddEditEventSheetState._save()`, `_AddEditBucketSheetState._save()` — `await` 이후 `if (mounted)` 체크 후 `Navigator.pop(context)` 호출. 정상.
- 위치: `lib/main.dart:2239`, `2732`
- 수정 방향: 없음.

---

- 심각도: INFO
- 항목: `_EventDetailSheet._delete()`, `_BucketDetailSheet._delete()` — StatelessWidget에서 `BuildContext ctx`를 파라미터로 받아 `await` 이후 `ctx.mounted` 체크 후 `Navigator.pop(ctx)` 호출. 올바른 패턴.
- 위치: `lib/main.dart:1959~1981`, `2510~2532`
- 수정 방향: 없음.

---

- 심각도: INFO
- 항목: `_pickDate()`, `_pickTime()` — `await` 이후 `if (picked != null && mounted)` 체크. 정상.
- 위치: `lib/main.dart:2185`, `2204`
- 수정 방향: 없음.

---

- 심각도: INFO
- 항목: null safety — `fromMap` 팩토리에서 `?.toString() ?? ''`, `as int? ?? 0` 등 방어적 처리. `!` 남용 없음. (`FirebaseAuth.instance.currentUser!.uid` L158 — signIn 직후이므로 null 불가, 허용 범위).
- 위치: `lib/main.dart:1120~1139`, `1197~1214`
- 수정 방향: 없음.

---

- 심각도: INFO
- 항목: `_pushWidgetData()`가 `HomeWidget.saveWidgetData` / `updateWidget` 호출을 `try-catch`로 감싸고 있어 위젯 미설치 시 크래시 방지. 구현 로그 ANTI-PATTERN 반영됨.
- 위치: `lib/main.dart:1424~1455`
- 수정 방향: 없음.

---

### 3. 스타일 일관성

- 심각도: INFO
- 항목: 색상 테마 확인.
  - 배경 `Color(0xFF1A1A2E)` — `ThemeData.scaffoldBackgroundColor`, `TabBar` 컨테이너 색상에 사용 ✅
  - primary `Color(0xFFA78BFA)` — `_primary` 상수로 정의 ✅
  - 추가 색상 (`_bgCard: 0xFF16213E`, `_accent`, `_success` 등) — 테마 확장으로 일관성 있음.
- 위치: `lib/main.dart:22~30`
- 수정 방향: 없음.

---

- 심각도: INFO
- 항목: 섹션 구분자 `// ══════════════════════════════════════` — Date Feature 관련 섹션에서 사용됨 (`// ── Date Feature Color Constants ──`, `// ══ Date Page`, `// ══ Event Detail Sheet`, etc.). 기존 앱 스타일과 일치.
- 위치: `lib/main.dart:21`, `1229`, `1353`, `1950`, 외
- 수정 방향: 없음.

---

- 심각도: INFO
- 항목: StatefulWidget + setState 패턴 유지. Provider/Riverpod 등 추가 패키지 없음.
- 위치: 전체
- 수정 방향: 없음.

---

### 4. home_widget (홈 위젯)

- 심각도: INFO
- 항목: `AndroidManifest.xml` — `<receiver android:name=".DateWidgetProvider" android:exported="true">` 등록됨. `APPWIDGET_UPDATE`, `APPWIDGET_ENABLED`, `home_widget UPDATE` 액션 모두 포함. `<meta-data android:resource="@xml/date_widget_info">` 연결됨. ✅
- 위치: `android/app/src/main/AndroidManifest.xml:44~55`
- 수정 방향: 없음.

---

- 심각도: INFO
- 항목: `res/xml/date_widget_info.xml` — 존재함. `initialLayout="@layout/home_widget_large"`, `updatePeriodMillis="1800000"` (30분) ✅
- 위치: `android/app/src/main/res/xml/date_widget_info.xml`
- 수정 방향: 없음.

---

- 심각도: INFO
- 항목: `HomeWidget.saveWidgetData` / `HomeWidget.updateWidget` 호출 쌍 확인. `_pushWidgetData()`에서 `saveWidgetData` 3회 + `updateWidget` 1회 호출. `initState` → `_subscribeEvents()` → 데이터 수신 시 및 `AppLifecycleState.resumed` 시 호출 ✅
- 위치: `lib/main.dart:1451~1454`
- 수정 방향: 없음.

---

- 심각도: INFO
- 항목: `DateWidgetProvider.kt` — `R.id.widget_root` PendingIntent 타겟. `home_widget_large.xml` 루트 LinearLayout에 `android:id="@+id/widget_root"` 정상 선언됨 ✅
- 위치: `android/app/src/main/kotlin/.../DateWidgetProvider.kt:31`, `res/layout/home_widget_large.xml:3`
- 수정 방향: 없음.

---

### 5. pubspec.yaml

- 심각도: INFO
- 항목: 추가 패키지 3종 — `google_fonts: ^6.2.1`, `table_calendar: ^3.1.2`, `home_widget: ^0.6.0`. 기존 패키지(`firebase_*`, `google_sign_in`, `dio`, `flutter_local_notifications`)와 직접 버전 충돌 없음. `flutter pub get` 성공 확인됨 (구현 로그 기준: `intl 0.20.2`, `simple_gesture_detector 0.2.1`, `crypto 3.0.7` 간접 의존성).
- 위치: `pubspec.yaml:43~45`
- 수정 방향: 없음.

---

- 심각도: WARNING
- 항목: `home_widget: ^0.6.0` — pub.dev 최신 버전은 0.9.1. 0.6.0은 설계에서 고정했으나 API 호환성 변경 가능성 있음. 구현 로그에서도 "빌드 테스트 필요, API 호환성 확인 필요"로 명시.
- 위치: `pubspec.yaml:45`
- 수정 방향: `flutter build apk --release` 실행으로 실제 빌드 검증 필수. 빌드 실패 시 0.9.1로 업그레이드 후 API 변경 사항 적용.

---

[OVERALL]
**FAIL** — `_DropTrackerPageState` Firebase 리스너 StreamSubscription 미저장/미해제(CRITICAL) 확인. dispose 후 `setState` 호출 위험 동반.

---

## 수정 우선순위 요약

| 우선순위 | 항목 | 위치 |
|---------|------|------|
| 1 (CRITICAL) | DropTrackerPage Firebase 리스너 cancel 누락 | `main.dart:341`, `362~365` |
| 2 (WARNING) | DropTrackerPage 리스너 내 mounted 체크 없음 | `main.dart:345` |
| 3 (WARNING) | home_widget 0.6.0 빌드 검증 필요 | `pubspec.yaml:45` |
