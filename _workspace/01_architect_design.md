# Architect Design — Date Feature
**작성일:** 2026-04-28
**에이전트:** date-architect
**기반 산출물:** 00_design_spec.md (flutter-designer), lib/main.dart, pubspec.yaml, SKILL.md

---

## STATE

- CURRENT_TASK: 데이트 기능 설계
- STATUS: COMPLETE (설계 완료, 구현 대기)

---

## 1. Firebase 데이터 스키마

### 1-1. 확정 이벤트 — `/users/{uid}/dates/{dateId}`

| 필드 | 타입 | 필수 | 예시 값 | 설명 |
|------|------|------|---------|------|
| `title` | String | Y | `"저녁 데이트"` | 이벤트 제목 |
| `date` | String | Y | `"2026-05-10"` | ISO 날짜 (yyyy-MM-dd) |
| `time` | String | N | `"18:00"` | HH:mm, 없으면 빈 문자열 |
| `location` | String | N | `"한남동 레스토랑"` | 장소 |
| `category` | String | Y | `"식사"` | 카테고리 (아래 목록) |
| `memo` | String | N | `"예약 필요"` | 메모 (멀티라인 허용) |
| `tags` | List\<String\> | N | `["데이트", "저녁"]` | 태그 (Wrap Chip 표시용) |
| `eventType` | String | Y | `"normal"` | `"normal"` / `"anniversary"` |
| `confirmed` | bool | Y | `true` | 항상 true (dates 컬렉션이므로) |
| `createdAt` | int | Y | `1714000000000` | millisecondsSinceEpoch |

**카테고리 목록:** `식사`, `카페`, `여행`, `영화`, `공연`, `야외`, `기념일`, `기타`

**eventType 색상 매핑:**
- `"normal"` → primary `0xFFA78BFA` (보라)
- `"anniversary"` → accent `0xFFE8A598` (로즈골드)

### 1-2. 미확정 버킷리스트 — `/users/{uid}/bucketlist/{itemId}`

| 필드 | 타입 | 필수 | 예시 값 | 설명 |
|------|------|------|---------|------|
| `title` | String | Y | `"제주도 여행"` | 항목 제목 |
| `category` | String | Y | `"여행"` | 위 카테고리 목록과 동일 |
| `priority` | int | Y | `1` | 1=HIGH, 2=MEDIUM, 3=LOW |
| `memo` | String | N | `"여름에 가고 싶어"` | 메모 |
| `tags` | List\<String\> | N | `["버킷", "여행"]` | 태그 |
| `done` | bool | Y | `false` | 완료 여부 |
| `doneAt` | String | N | `"2026-10-15"` | 완료 날짜 (done=true 시 기록) |
| `createdAt` | int | Y | `1714000000000` | millisecondsSinceEpoch |

**priority 색상 매핑:**
- `1` (HIGH) → accent `0xFFE8A598`
- `2` (MEDIUM) → primary `0xFFA78BFA`
- `3` (LOW) → textSecondary `0xFF8892B0`

---

## 2. 필요 패키지

기존 pubspec.yaml 대비 신규 추가만 기록. 버전 충돌 없음.

```yaml
dependencies:
  # --- 신규 추가 ---
  google_fonts: ^6.2.1        # Playfair Display (제목) + Nunito (본문)
  table_calendar: ^3.1.2      # 월별 캘린더 UI
  home_widget: ^0.6.0         # Android 홈스크린 위젯

  # --- 기존 유지 (변경 없음) ---
  firebase_core: ^3.12.1
  firebase_database: ^11.3.5
  firebase_auth: ^5.5.1
  google_sign_in: ^6.2.2
  url_launcher: ^6.3.1
  dio: ^5.7.0
  path_provider: ^2.1.5
  firebase_messaging: ^15.2.4
  flutter_local_notifications: ^18.0.1
```

> `intl` 패키지는 `table_calendar`의 의존성으로 간접 포함되므로 직접 추가 불필요. 날짜 포맷은 Dart 내장 `DateTime` 또는 `table_calendar`의 `intl` 재사용.

---

## 3. UI 구조

### 3-1. HomePage 탭 연결

기존 탭 구조 (main.dart L281-286):
```
[드랍, 채팅, 설정] — index 0,1,2
```

변경 후:
```
[드랍, 데이트, 채팅, 설정] — index 0,1,2,3
```

**변경 위치 (main.dart):**
- L271-275: `body: [...]` 배열에 `DatePage(userKey: widget.userKey)` 인덱스 1 삽입
- L281-286: `destinations:` 리스트에 `NavigationDestination(icon: Icon(Icons.favorite), label: '데이트')` 인덱스 1 삽입

### 3-2. 클래스/페이지 목록

| 클래스 | 타입 | 역할 |
|--------|------|------|
| `DateEvent` | Model | 확정 이벤트 데이터 클래스 |
| `BucketItem` | Model | 버킷리스트 항목 데이터 클래스 |
| `DatePage` | StatefulWidget | 캘린더 탭 전체 (캘린더 + 이벤트 목록) |
| `_DatePageState` | State | Firebase 구독, 선택 날짜 상태, 이벤트 맵 |
| `BucketlistPage` | StatefulWidget | 버킷리스트 탭 (DatePage 내부 탭 또는 독립 페이지) |
| `_BucketlistPageState` | State | 버킷리스트 Firebase 구독, 필터 상태 |
| `EventCard` | StatelessWidget | 좌측 컬러 바 + 제목/시간/장소 카드 |
| `_SlideFadeItem` | StatefulWidget | staggered slide-up + fade 애니메이션 래퍼 |
| `_EventDetailSheet` | StatefulWidget | 이벤트 상세 풀스크린 Bottom Sheet |
| `_AddEditEventSheet` | StatefulWidget | 이벤트 추가/수정 풀스크린 Bottom Sheet |
| `_BucketDetailSheet` | StatefulWidget | 버킷리스트 상세 Bottom Sheet |
| `_AddEditBucketSheet` | StatefulWidget | 버킷리스트 추가/수정 Bottom Sheet |

### 3-3. DatePage 구조

```
DatePage (StatefulWidget)
├── 상태: _selectedDay, _focusedDay, Map<DateTime, List<DateEvent>> _events
├── initState: Firebase /users/{uid}/dates onValue 구독 → _events 갱신
├── CustomHeader: "April 2026 [←][→] [+]"
│     - Playfair Display 22sp
│     - [+] → _AddEditEventSheet 열기
├── TableCalendar
│     - format: CalendarFormat.month
│     - eventLoader: (day) => _events[day] ?? []
│     - onDaySelected: setState(_selectedDay)
│     - CalendarStyle: 디자인 스펙 적용
│     - HeaderStyle: visible=false (커스텀 헤더 사용)
├── 구분선 (divider 색상)
├── 선택 날짜 이벤트 목록 (Expanded ListView)
│     - 각 항목: _SlideFadeItem > EventCard
│     - 탭 → _EventDetailSheet(event) 열기
└── 하단 탭 바 (DatePage 내부): [캘린더 | 버킷리스트]
      - TabBar 또는 SegmentedButton (2개)
      - 버킷리스트 탭 → BucketlistPage 전환
```

> 구현 단순화를 위해 DatePage는 DefaultTabController로 내부에 [캘린더 탭, 버킷리스트 탭] 2개를 가진다. HomePage의 단일 "데이트" 탭 안에서 처리.

### 3-4. DatePage Firebase 패턴

기존 코드 패턴 준수 (DropTrackerPage, ChatSendPage와 동일):

```dart
// initState에서
final ref = FirebaseDatabase.instance.ref('users/${widget.userKey}/dates');
ref.onValue.listen((event) {
  final data = event.snapshot.value;
  if (data == null) { setState(() => _events = {}); return; }
  final rawMap = Map<String, dynamic>.from(data as Map);
  final parsed = <DateTime, List<DateEvent>>{};
  rawMap.forEach((key, value) {
    final item = DateEvent.fromMap(key, Map<String, dynamic>.from(value as Map));
    final day = _normalizeDate(item.date);
    parsed.putIfAbsent(day, () => []).add(item);
  });
  setState(() => _events = parsed);
});
```

### 3-5. BucketlistPage 구조

```
BucketlistPage (StatefulWidget)
├── 상태: List<BucketItem> _items, String _filter ('전체'|'미완료'|'완료')
├── initState: Firebase /users/{uid}/bucketlist onValue 구독
├── 헤더: "Bucket List [+ 추가]" (Playfair 26sp)
├── 진행 바: LinearProgressIndicator (완료/전체)
├── 필터 칩: [전체][미완료][완료] ChoiceChip row
├── Dismissible ListView (좌 스와이프 삭제)
│     - 각 항목: EventCard (accent 또는 success 바)
│     - 탭 → _BucketDetailSheet(item) 열기
└── [+ 추가] → _AddEditBucketSheet 열기
```

### 3-6. _EventDetailSheet 구조

```
showModalBottomSheet(isScrollControlled: true, backgroundColor: transparent)
└── DraggableScrollableSheet(initialChildSize: 0.85, maxChildSize: 1.0, minChildSize: 0.5)
    └── Container(color: bgCard, borderRadius: top 24)
        ├── Drag handle (40×4px, divider 색)
        ├── 날짜 (Playfair, textSecondary, 14sp)
        ├── 제목 (Playfair Display, 28sp, textPrimary)
        ├── Divider
        ├── 시간 Row (Icon(clock) + text)
        ├── 장소 Row (Icon(location) + text)
        ├── 메모 Row (Icon(notes) + text)
        ├── 태그 Wrap (Chip)
        ├── Divider
        └── 버튼 Row: [수정하기(outlined)] [삭제하기(ghost, red)]
```

### 3-7. _AddEditEventSheet 구조

```
showModalBottomSheet(isScrollControlled: true, backgroundColor: transparent)
└── DraggableScrollableSheet(initialChildSize: 0.9)
    └── Container(color: bgCard)
        ├── Drag handle
        ├── 제목: "새 이벤트" / "수정" (Playfair 22sp)
        ├── TextFormField: 제목 (bgElevated, border: none)
        ├── 날짜 InkWell → showDatePicker
        ├── 시간 InkWell → showTimePicker
        ├── TextFormField: 장소
        ├── TextFormField: 메모 (maxLines: 3)
        ├── SegmentedButton: [일반 | 기념일]
        ├── 태그 입력 + Wrap Chip
        └── ElevatedButton: "저장하기" (primary gradient, h52, full-width)
            → Firebase ref.push().set() / ref.update()
```

---

## 4. Android 홈 위젯 구조

### 4-1. home_widget 패키지 연동

```
Flutter 앱 측:
- HomeWidget.setAppGroupId('group.com.zziktam.tamMobileStudio')  ← iOS 미사용이므로 생략 가능
- HomeWidget.saveWidgetData<String>('widgetMonth', 'April 2026')
- HomeWidget.saveWidgetData<String>('widgetEventPreview', '♥ 오늘: 저녁 데이트 오후 7시')
- HomeWidget.saveWidgetData<String>('widgetDatesJson', jsonEncode(datesForCurrentMonth))
- HomeWidget.updateWidget(name: 'DateWidgetProvider', iOSName: 'DateWidget')
```

호출 시점: DatePage initState 완료 후, 그리고 앱 `didChangeAppLifecycleState` resumed 시.

### 4-2. Android 파일 목록

| 파일 경로 | 역할 |
|-----------|------|
| `android/app/src/main/kotlin/.../DateWidgetProvider.kt` | AppWidgetProvider (onUpdate, onReceive) |
| `android/app/src/main/res/xml/date_widget_info.xml` | AppWidgetProviderInfo (minWidth, minHeight, resizable) |
| `android/app/src/main/res/xml/date_widget_info_small.xml` | 소형 위젯 AppWidgetProviderInfo |
| `android/app/src/main/res/layout/home_widget_large.xml` | 5×4 풀 캘린더 레이아웃 (RemoteViews) |
| `android/app/src/main/res/layout/home_widget_medium.xml` | 4×2 중형 레이아웃 |
| `android/app/src/main/res/layout/home_widget_small.xml` | 2×2 소형 레이아웃 |
| `android/app/src/main/res/drawable/circle_today.xml` | 오늘 셀 원형 배경 (primary border) |
| `android/app/src/main/res/drawable/circle_accent.xml` | 이벤트 셀 원형 배경 (accent fill) |
| `android/app/src/main/res/drawable/widget_bg.xml` | 위젯 배경 (bgDeep, rounded 16dp) |

### 4-3. AndroidManifest.xml 추가 내용

```xml
<!-- android/app/src/main/AndroidManifest.xml 의 <application> 내부에 추가 -->
<receiver
    android:name=".DateWidgetProvider"
    android:exported="true">
  <intent-filter>
    <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    <action android:name="android.appwidget.action.APPWIDGET_ENABLED" />
    <action android:name="es.antonborri.home_widget.action.UPDATE" />
  </intent-filter>
  <meta-data
      android:name="android.appwidget.provider"
      android:resource="@xml/date_widget_info" />
</receiver>
```

### 4-4. date_widget_info.xml 핵심 속성

```xml
<appwidget-provider
    android:minWidth="110dp"     <!-- 2 cells -->
    android:minHeight="110dp"    <!-- 2 cells -->
    android:minResizeWidth="110dp"
    android:minResizeHeight="110dp"
    android:maxResizeWidth="250dp"   <!-- 5 cells -->
    android:maxResizeHeight="250dp"  <!-- 5 cells - 갤럭시 기준 -->
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="1800000"   <!-- 30분마다 자동 갱신 -->
    android:initialLayout="@layout/home_widget_large"
    android:widgetCategory="home_screen"
    android:description="@string/app_name" />
```

### 4-5. DateWidgetProvider.kt 로직

```kotlin
class DateWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context, appWidgetManager, appWidgetIds, widgetData) {
        val month = widgetData.getString("widgetMonth", "")
        val preview = widgetData.getString("widgetEventPreview", "일정 없음")
        val datesJson = widgetData.getString("widgetDatesJson", "[]")

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.home_widget_large)
            views.setTextViewText(R.id.tv_month, month)
            views.setTextViewText(R.id.tv_event_preview, preview)
            // 날짜 셀 42개 동적 업데이트 (dates JSON 파싱)
            updateCalendarCells(views, datesJson)
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
```

---

## 5. 기존 코드 컨벤션 유지 규칙

### 5-1. 색상 상수

기존 앱에서 인라인 Color 리터럴 사용 방식 유지. 신규 색상 추가:

```dart
// 디자인 스펙 색상 — main.dart 상단 const 영역에 추가
const _bgCard      = Color(0xFF16213E);
const _bgElevated  = Color(0xFF1F2B4A);
const _accent      = Color(0xFFE8A598);   // 로즈골드
const _success     = Color(0xFF6EE7B7);   // 민트
const _textPrimary = Color(0xFFF0EAF8);
const _textSecondary = Color(0xFF8892B0);
const _divider     = Color(0xFF2D3A5C);
// 기존 유지
// primary = Color(0xFFA78BFA)
// bg = Color(0xFF1A1A2E)
// card = Color(0xFF22223A)  ← 기존 Drop/Chat 카드 (변경 안 함)
```

> 참고: `0xFF22223A`는 기존 Drop/Chat 카드 배경이고, `0xFF16213E`은 Date 기능 전용 bgCard다. 두 값이 공존하므로 Date 기능에서만 bgCard 사용.

### 5-2. StatefulWidget + setState 패턴

기존 DropTrackerPage/ChatSendPage와 동일하게:
- Firebase `ref.onValue.listen()` in `initState`
- `setState()` 로 UI 갱신
- `dispose()` 에서 구독 취소 (`StreamSubscription? _sub; ... _sub?.cancel()`)
- `WidgetsFlutterBinding.ensureInitialized()` 이미 완료 상태 → 추가 불필요

### 5-3. 섹션 구분자 패턴

```dart
// ══════════════════════════════════════
//  Date Page
// ══════════════════════════════════════
```

### 5-4. Google Fonts 적용 범위

Date 기능 전용 텍스트에만 적용. 기존 Drop/Chat/Settings 위젯은 손대지 않음.

```dart
import 'package:google_fonts/google_fonts.dart';
// Date 기능 내부에서만: GoogleFonts.playfairDisplay(...), GoogleFonts.nunito(...)
```

### 5-5. CRUD Firebase 패턴

```dart
// Create
final ref = FirebaseDatabase.instance.ref('users/${widget.userKey}/dates');
await ref.push().set(event.toMap());

// Update
await ref.child(event.id).update(event.toMap());

// Delete
await ref.child(event.id).remove();

// Read (실시간 구독 — initState에서)
_sub = ref.onValue.listen((e) { ... });
```

---

## 6. 모델 클래스 설계

### 6-1. DateEvent

```dart
class DateEvent {
  final String id;          // Firebase push key
  final String title;
  final String date;        // "yyyy-MM-dd"
  final String time;        // "HH:mm" or ""
  final String location;
  final String category;
  final String memo;
  final List<String> tags;
  final String eventType;   // "normal" | "anniversary"
  final bool confirmed;
  final int createdAt;

  // fromMap, toMap 메서드
  // barColor getter: eventType == "anniversary" ? _accent : primary
  // formattedDate getter: "April 20, 2026" 포맷
}
```

### 6-2. BucketItem

```dart
class BucketItem {
  final String id;          // Firebase push key
  final String title;
  final String category;
  final int priority;       // 1=HIGH, 2=MEDIUM, 3=LOW
  final String memo;
  final List<String> tags;
  final bool done;
  final String doneAt;      // "yyyy-MM-dd" or ""
  final int createdAt;

  // fromMap, toMap 메서드
  // priorityColor getter
  // barColor getter: done ? _success : _accent
}
```

---

## 7. 구현 순서 체크리스트

date-implementer가 순서대로 따를 것. 각 단계 완료 후 다음 단계 진행.

### Phase 1 — 기반 (빌드 확인)
- [ ] `pubspec.yaml`에 `google_fonts`, `table_calendar`, `home_widget` 추가
- [ ] `flutter pub get` 실행, 에러 없음 확인
- [ ] `flutter build apk --release` — 빌드 성공 확인 (아직 기능 없음)

### Phase 2 — 모델 + Firebase
- [ ] `DateEvent` 클래스 구현 (main.dart 상단 AssetService 아래에 추가)
- [ ] `BucketItem` 클래스 구현
- [ ] 색상 상수 (`_bgCard`, `_bgElevated`, `_accent`, `_success`, `_textPrimary`, `_textSecondary`, `_divider`) main.dart 상단에 추가

### Phase 3 — DatePage 핵심 UI
- [ ] `EventCard` StatelessWidget 구현 (디자인 스펙 스니펫 참조)
- [ ] `_SlideFadeItem` StatefulWidget 구현 (디자인 스펙 스니펫 참조)
- [ ] `DatePage` StatefulWidget 구현
  - [ ] Firebase 구독 (`/users/{uid}/dates`)
  - [ ] 커스텀 헤더 (Playfair, 월/년, [←][→], [+])
  - [ ] `TableCalendar` 위젯 (디자인 스펙 CalendarStyle 적용)
  - [ ] 선택 날짜 이벤트 리스트 (ListView + _SlideFadeItem + EventCard)
  - [ ] 내부 탭바: [캘린더 | 버킷리스트]
- [ ] `HomePage` 탭 배열에 `DatePage` 인덱스 1 삽입
- [ ] `HomePage` NavigationDestination에 데이트 탭 삽입

### Phase 4 — 이벤트 CRUD
- [ ] `_EventDetailSheet` 구현 (DraggableScrollableSheet, 상세 필드)
- [ ] `_AddEditEventSheet` 구현 (DatePicker, TimePicker, SegmentedButton, 태그)
- [ ] EventCard 탭 → `_EventDetailSheet` 연결
- [ ] `_EventDetailSheet` 수정 버튼 → `_AddEditEventSheet` 연결
- [ ] `_EventDetailSheet` 삭제 버튼 → Firebase remove() 연결
- [ ] `_AddEditEventSheet` 저장 → Firebase push()/update() 연결

### Phase 5 — BucketlistPage
- [ ] `BucketlistPage` StatefulWidget 구현
  - [ ] Firebase 구독 (`/users/{uid}/bucketlist`)
  - [ ] 진행 바 (LinearProgressIndicator, 600ms 애니메이션)
  - [ ] 필터 칩 [전체|미완료|완료]
  - [ ] Dismissible ListView (스와이프 삭제)
  - [ ] 완료 토글 (done 업데이트 + doneAt 기록)
- [ ] `_BucketDetailSheet` 구현
- [ ] `_AddEditBucketSheet` 구현

### Phase 6 — 홈 위젯 (마지막)
- [ ] `android/app/src/main/res/xml/date_widget_info.xml` 생성
- [ ] `android/app/src/main/res/layout/home_widget_large.xml` 생성 (5×4)
- [ ] `android/app/src/main/res/layout/home_widget_medium.xml` 생성 (4×2)
- [ ] `android/app/src/main/res/layout/home_widget_small.xml` 생성 (2×2)
- [ ] `android/app/src/main/res/drawable/circle_today.xml` 생성
- [ ] `android/app/src/main/res/drawable/circle_accent.xml` 생성
- [ ] `android/app/src/main/res/drawable/widget_bg.xml` 생성
- [ ] `DateWidgetProvider.kt` 생성
- [ ] `AndroidManifest.xml` receiver 등록
- [ ] Flutter 측: `HomeWidget.saveWidgetData` + `HomeWidget.updateWidget` 호출 (DatePage initState + AppLifecycleObserver resumed)
- [ ] `flutter build apk --release` 빌드 + 위젯 동작 확인

---

## 8. 기존 코드 연결 포인트 (main.dart 라인 기준)

| 변경 내용 | 현재 라인 | 액션 |
|-----------|-----------|------|
| 색상 상수 추가 | L16 (`const appVersion`) 아래 | 삽입 |
| DateEvent 클래스 | L1034 (`AssetService`) 아래 | 삽입 |
| BucketItem 클래스 | DateEvent 아래 | 삽입 |
| EventCard 클래스 | BucketItem 아래 | 삽입 |
| _SlideFadeItem 클래스 | EventCard 아래 | 삽입 |
| DatePage 클래스 | _SlideFadeItem 아래 | 삽입 |
| BucketlistPage 클래스 | DatePage 아래 | 삽입 |
| Sheet 클래스들 | BucketlistPage 아래 | 삽입 |
| HomePage body 배열 | L271-275 | index 1에 DatePage 삽입 |
| HomePage destinations | L281-286 | index 1에 데이트 탭 삽입 |
| google_fonts import | L1-14 imports 섹션 | import 추가 |
| table_calendar import | L1-14 imports 섹션 | import 추가 |
| home_widget import | L1-14 imports 섹션 | import 추가 |

---

## 9. 위험 요소 및 주의사항

1. **home_widget ^0.6.0** — 최신 버전 확인 필요. SKILL.md에는 ^0.7.0, 디자인 스펙에는 ^0.6.0. 구현 시 pub.dev에서 최신 호환 버전 확인 후 사용.

2. **홈 위젯 날짜 셀 동적 생성** — Android RemoteViews는 동적 View 추가 불가. 42개 TextView를 XML에 정적으로 선언하고 ID로 개별 접근해야 함.

3. **TabController 라이프사이클** — DatePage가 DefaultTabController를 사용하면 dispose 시 TabController 자동 해제. vsync 문제 없음.

4. **Firebase 구독 중복** — DatePage와 BucketlistPage가 각각 별도 구독을 가짐. dispose에서 반드시 `_sub?.cancel()` 호출.

5. **DateTime 키 정규화** — `_normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day)` 헬퍼 필수. Firebase에서 파싱한 `"2026-05-10"` 문자열을 날짜 Map 키로 쓸 때 시/분/초를 0으로 맞춰야 `TableCalendar` eventLoader가 정상 작동.

---

*Architect Design version: 1.0 | 작성일: 2026-04-28 | 에이전트: date-architect*
