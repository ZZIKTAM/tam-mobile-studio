# Design Spec — Couple Date App
**Aesthetic Direction:** Refined Dark Romance — 고급스러운 다크 네이비 베이스에 보라+로즈골드 포인트로 설렘과 친밀감을 표현

---

## 색상 팔레트

| Token | Hex | 용도 |
|---|---|---|
| `bgDeep` | `0xFF1A1A2E` | 앱 배경, Scaffold (기존 유지) |
| `bgCard` | `0xFF16213E` | 카드/시트 배경 (약간 밝은 네이비) |
| `bgElevated` | `0xFF1F2B4A` | 선택된 날짜 셀, 입력 필드 배경 |
| `primary` | `0xFFA78BFA` | 보라 — 주요 액션, 선택 상태 (기존 유지) |
| `accent` | `0xFFE8A598` | 로즈골드 — 기념일, 특별 이벤트, 버킷리스트 포인트 |
| `accentWarm` | `0xFFFFB8A0` | 연한 산호 — hover/shimmer 효과 |
| `textPrimary` | `0xFFF0EAF8` | 주요 텍스트 (차가운 화이트 피함) |
| `textSecondary` | `0xFF8892B0` | 보조 텍스트, 날짜 비활성 |
| `textMuted` | `0xFF4A5568` | 비활성 요소, placeholder |
| `divider` | `0xFF2D3A5C` | 구분선 |
| `dotEvent` | `0xFFA78BFA` | 일반 이벤트 도트 |
| `dotAnniversary` | `0xFFE8A598` | 기념일 도트 |
| `dotBucketlist` | `0xFF6EE7B7` | 버킷리스트 완료 도트 |
| `success` | `0xFF6EE7B7` | 완료 상태 (민트) |

---

## 폰트 선택

### Display / 제목 — Playfair Display
- 감성적인 세리프 폰트. 달력 월/년, 이벤트 제목, 버킷리스트 헤더에 사용
- 클리셰 산세리프를 피하고 따뜻한 로맨틱 감성 부여

### Body / UI — Nunito (기존 시스템 폰트 대체)
- 부드러운 둥근 산세리프. 카드 본문, 폼 입력, 태그에 사용
- Material 기본 Roboto보다 친근하고 커플 앱 톤에 적합

### pubspec.yaml 추가 방법

```yaml
dependencies:
  google_fonts: ^6.2.1
  table_calendar: ^3.1.2
  home_widget: ^0.6.0
```

### 코드에서 사용

```dart
import 'package:google_fonts/google_fonts.dart';

// ThemeData에 적용
theme: ThemeData(
  textTheme: GoogleFonts.nunitoTextTheme(
    ThemeData.dark().textTheme,
  ).copyWith(
    displayLarge: GoogleFonts.playfairDisplay(
      color: Color(0xFFF0EAF8),
      fontSize: 32,
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: GoogleFonts.playfairDisplay(
      color: Color(0xFFF0EAF8),
      fontSize: 22,
      fontWeight: FontWeight.w600,
    ),
  ),
)
```

---

## 화면별 레이아웃 명세

### 1. DatePage — 월별 캘린더

```
┌─────────────────────────────────────┐
│ [←]  April 2026  [→]          [+]  │  ← AppBar 없음, 커스텀 헤더
│      Playfair Display, 22sp          │    [+] = 이벤트 추가 FAB-style 아이콘
├─────────────────────────────────────┤
│  일  월  화  수  목  금  토          │  ← 요일 헤더, textMuted
│                                     │
│   .  1   2   3   4   5   6          │
│         [7]  8   9  10  11          │  [7] = 오늘: 보라 동그라미 bg
│  12  13  14  15  16  17  18         │
│  19 [20] 21  22  23  24  25         │  [20] = 선택: 로즈골드 동그라미 bg
│  26  27  28  29  30                 │
│                                     │
│   •       ••        •               │  ← 이벤트 도트 (최대 3개)
├─────────────────────────────────────┤
│ ─── 선택된 날짜 이벤트 리스트 ───   │
│                                     │
│  [로즈골드 바] 저녁 데이트          │  ← 이벤트 카드
│               오후 7시 · 한남동      │
│                                     │
│  [보라 바]    영화 예약             │
│               오후 2시              │
└─────────────────────────────────────┘
```

**캘린더 셀 규격:**
- 날짜 숫자: Nunito 16sp, bold
- 오늘 셀: bgCard 원형 + primary 테두리 1.5px
- 선택 셀: accent(로즈골드) 원형 배경
- 이벤트 도트: 직경 5px, 셀 하단 중앙 정렬, 최대 3개

**이벤트 카드 (하단 리스트):**
- 좌측 컬러 바 4px (이벤트 타입별 색상)
- 카드 배경: bgCard, borderRadius 12
- staggered slide-up 애니메이션

---

### 2. 이벤트 상세 — 풀스크린 Bottom Sheet

```
┌─────────────────────────────────────┐
│ ▬▬▬  (drag handle)                  │
│                                     │
│  April 20, 2026                     │  ← Playfair, textSecondary, 14sp
│  저녁 데이트                        │  ← Playfair Display, 28sp, textPrimary
│                                     │
│  ────────────────────────────────   │
│                                     │
│  ⏰  오후 7:00                      │  ← 아이콘 + Nunito 16sp
│  📍  한남동 레스토랑                │
│  📝  분위기 좋은 이탈리안 식당      │  ← 메모 (멀티라인)
│  🏷  #데이트 #저녁                  │  ← 태그 칩
│                                     │
│  ────────────────────────────────   │
│                                     │
│  [ 수정하기 ]     [ 삭제하기 ]     │  ← outlined + ghost 버튼
│                                     │
└─────────────────────────────────────┘
```

**스펙:**
- `showModalBottomSheet(isScrollControlled: true, ...)`
- `DraggableScrollableSheet(initialChildSize: 0.85, maxChildSize: 1.0)`
- 배경: bgCard, 상단 borderRadius 24
- drag handle: 40×4px, color: divider

---

### 3. 이벤트 추가/수정 — Bottom Sheet (풀스크린)

```
┌─────────────────────────────────────┐
│ ▬▬▬                                 │
│  새 이벤트                          │  ← Playfair, 22sp
│                                     │
│  ┌─ 제목 ─────────────────────────┐ │
│  │ 우리의 특별한 날...            │ │  ← TextFormField, bgElevated
│  └────────────────────────────────┘ │
│                                     │
│  날짜    2026. 04. 20               │  ← InkWell → DatePicker
│  시간    오후 7:00                  │  ← InkWell → TimePicker
│                                     │
│  장소    ─────────────────────────  │
│  메모    ─────────────────────────  │
│                                     │
│  이벤트 유형:                       │
│  [◯ 일반] [◎ 기념일] [◯ 버킷완료]  │  ← SegmentedButton
│                                     │
│  태그:  #   +추가                   │
│  [#데이트 ×]  [#저녁 ×]            │  ← Chip (wrap)
│                                     │
│       [    저장하기    ]            │  ← primary 버튼, full-width, h52
└─────────────────────────────────────┘
```

**스펙:**
- `DraggableScrollableSheet(initialChildSize: 0.9)`
- 필드 배경: bgElevated, borderRadius 10, border: none
- 저장 버튼: primary gradient (0xFFA78BFA → 0xFF8B6FD4), borderRadius 14

---

### 4. BucketlistPage — 미확정 항목 관리

```
┌─────────────────────────────────────┐
│  Bucket List              [+ 추가]  │  ← Playfair 26sp
│  12개 중 4개 완료                   │  ← textSecondary, Nunito 13sp
│                                     │
│  ┌── 진행 바 ──────────────────┐   │
│  │ ████████░░░░░░░░░░░░░░ 33%  │   │  ← LinearProgressIndicator
│  └────────────────────────────┘   │
│                                     │
│  [ 전체 ] [ 미완료 ] [ 완료 ]      │  ← FilterChip row
│                                     │
│  [accent 바] 제주도 여행            │  ← 미완료 카드
│              우선순위 높음 · 2025   │
│              [ 완료로 표시 ]        │
│                                     │
│  [success 바] 한강 피크닉 ✓        │  ← 완료 카드 (opacity 0.6)
│               2024.10.15 달성       │
│                                     │
└─────────────────────────────────────┘
```

**스펙:**
- 좌측 컬러 바: 미완료=accent(로즈골드), 완료=success(민트), width 4px
- 완료 항목: opacity 0.6, 텍스트 strikethrough
- 우선순위: `HIGH` 로즈골드, `MEDIUM` 보라, `LOW` textSecondary
- 항목 탭 → 상세 Bottom Sheet (이벤트 상세와 동일 패턴)
- dismiss to delete (좌 스와이프): 빨간 배경 + 휴지통 아이콘

---

### 5. 홈 위젯 — 5×6 갤럭시 캘린더 스타일

```
┌─────────────────────────────────────┐
│ April 2026              Tam Studio  │  ← 헤더 (Playfair + 로고텍스트)
├─────────────────────────────────────┤
│  일  월  화  수  목  금  토         │  ← 요일 (작은 텍스트)
├─────────────────────────────────────┤
│       1   2   3   4   5   6        │  행 1
│   7   8   9  10  11  12  13        │  행 2
│  14  15  16  17  18  19  20        │  행 3  (20 = 선택, 로즈골드 원)
│  21  22  23  24  25  26  27        │  행 4
│  28  29  30                        │  행 5
│                                     │  행 6 (빈 행 또는 다음달)
├─────────────────────────────────────┤
│  ♥ 오늘: 저녁 데이트 오후 7시      │  ← 오늘 이벤트 미리보기 (1줄)
└─────────────────────────────────────┘
```

**크기 조정 가능 규격:**
- 최소 크기: 2×2 (요일+날짜만, 이벤트 없음)
- 중간 크기: 4×2 (캘린더 + 이벤트 없음)
- 최대 크기: 5×4 이상 (풀 캘린더 + 이벤트 미리보기)

**구현 방식 (`home_widget` 패키지):**
- Android: AppWidgetProvider + RemoteViews (XML 레이아웃)
- 배경: bgDeep (`#1A1A2E`), 텍스트: textPrimary (`#F0EAF8`)
- 오늘 셀 강조: primary 원형 bg
- 갱신: `HomeWidget.updateWidget()` — 앱 포그라운드 진입 시 호출

---

## 핵심 위젯 구조 스니펫

### 이벤트 카드 구조

```dart
class EventCard extends StatelessWidget {
  final Color barColor;  // primary or accent
  final String title;
  final String? time;
  final String? location;
  final VoidCallback onTap;

  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),  // bgCard
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 좌측 컬러 바
            Container(width: 4, color: barColor,
              decoration: BoxDecoration(borderRadius: BorderRadius.horizontal(left: Radius.circular(12)))),
            // 콘텐츠
            Expanded(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
                if (time != null) Text(time!, style: GoogleFonts.nunito(fontSize: 13, color: Color(0xFF8892B0))),
              ]),
            )),
          ],
        ),
      ),
    );
  }
}
```

### 달력 테마 (table_calendar)

```dart
CalendarStyle(
  todayDecoration: BoxDecoration(
    shape: BoxShape.circle,
    color: const Color(0xFF1F2B4A),  // bgElevated
    border: Border.all(color: const Color(0xFFA78BFA), width: 1.5),
  ),
  selectedDecoration: BoxDecoration(
    shape: BoxShape.circle,
    color: const Color(0xFFE8A598),  // accent 로즈골드
  ),
  markerDecoration: BoxDecoration(
    shape: BoxShape.circle,
    color: const Color(0xFFA78BFA),  // dotEvent
  ),
  markerSize: 5,
  markersMaxCount: 3,
  defaultTextStyle: GoogleFonts.nunito(fontSize: 15, color: Color(0xFFF0EAF8)),
  weekendTextStyle: GoogleFonts.nunito(fontSize: 15, color: Color(0xFFE8A598)),
  outsideTextStyle: GoogleFonts.nunito(fontSize: 15, color: Color(0xFF4A5568)),
)
```

### 풀스크린 Bottom Sheet 호출 패턴

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (ctx) => DraggableScrollableSheet(
    initialChildSize: 0.85,
    maxChildSize: 1.0,
    minChildSize: 0.5,
    builder: (_, scrollController) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),  // bgCard
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF2D3A5C),  // divider
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(child: SingleChildScrollView(
          controller: scrollController,
          child: /* 내용 */,
        )),
      ]),
    ),
  ),
);
```

### Staggered Slide-Up 애니메이션 (이벤트 카드)

```dart
class _SlideFadeItem extends StatefulWidget {
  final int index;
  final Widget child;
}

class _SlideFadeItemState extends State<_SlideFadeItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final delay = Duration(milliseconds: widget.index * 60);
    Future.delayed(delay, () { if (mounted) _ctrl.forward(); });

    _slide = Tween(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  Widget build(BuildContext context) =>
    FadeTransition(opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child));
}
```

---

## 애니메이션 명세

| 요소 | 트리거 | 애니메이션 | Duration | Curve |
|---|---|---|---|---|
| 이벤트 카드 목록 | 날짜 선택 변경 | staggered slide-up + fade | 300ms (60ms 간격) | easeOutCubic |
| 달력 날짜 탭 | 탭 | scale 1.0→1.15→1.0 (bounce) | 200ms | elasticOut |
| Bottom Sheet 열기 | 이벤트 탭 / [+] 탭 | 기본 modal 슬라이드업 | 350ms | easeOutExpo |
| 버킷리스트 완료 | 완료 버튼 | 좌측 바 색상 전환 + opacity 0.6 | 400ms | easeInOut |
| 진행 바 | 페이지 진입 | 0 → 실제 값으로 애니메이션 | 600ms | easeOutCubic |
| 홈 위젯 | 앱 재개 | subtle pulse (scale 1.0→1.02→1.0) | 800ms | easeInOut |
| 월 전환 (달력) | [←][→] 탭 | 기본 PageView slide | 300ms | easeInOut |

---

## 홈 위젯 Android 레이아웃 구조

```
res/layout/home_widget_calendar.xml

LinearLayout (vertical, bgDeep)
├── LinearLayout (horizontal) — 헤더
│   ├── TextView: "April 2026"  (Playfair, 14sp, textPrimary)
│   └── TextView: "Tam Studio"  (Nunito, 11sp, accent)
├── GridLayout (7 cols) — 요일 헤더
│   └── 7× TextView (일~토, 10sp, textMuted)
├── GridLayout (7 cols × 6 rows) — 날짜 셀
│   └── 42× TextView (15sp)
│       - 오늘: drawable/circle_today (primary border)
│       - 선택/이벤트: drawable/circle_accent (accent fill)
└── TextView — 이벤트 미리보기 (Nunito, 12sp, textSecondary)
    "♥ 오늘: 저녁 데이트 오후 7시"
```

**크기별 layout 파일:**
- `home_widget_small.xml` — 2×2: 오늘 날짜 + 다음 이벤트 1개
- `home_widget_medium.xml` — 4×2: 주 단위 캘린더 + 이벤트 없음
- `home_widget_large.xml` — 5×4: 풀 캘린더 + 이벤트 미리보기

---

## pubspec.yaml 최종 추가 목록

```yaml
dependencies:
  google_fonts: ^6.2.1        # Playfair Display + Nunito
  table_calendar: ^3.1.2      # 월별 캘린더
  home_widget: ^0.6.0         # 안드로이드 홈 위젯
  # 기존 유지: firebase_core, firebase_database, firebase_auth,
  #            google_sign_in, url_launcher, dio, path_provider,
  #            firebase_messaging, flutter_local_notifications
```

---

*Spec version: 1.0 | 작성일: 2026-04-28 | 에이전트: flutter-designer*
