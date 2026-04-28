---
name: date-feature
description: tam-mobile-studio 앱의 데이트 일정 관리 기능 개발 스킬. 캘린더 UI, Firebase 연동, 버킷리스트, 홈 위젯 구현을 포함한다. "데이트 기능", "날짜 일정", "캘린더 추가", "홈 위젯" 등의 요청이나 이 기능의 설계/구현/수정/재실행 요청 시 반드시 date-orchestrator 스킬을 호출할 것.
---

# date-feature 가이드라인

이 스킬은 date-architect와 date-implementer 에이전트가 참조하는 **도메인 지식**을 담는다.

## Firebase 데이터 구조

### 확정 이벤트 (`/users/{uid}/dates/{dateId}`)
```json
{
  "title": "첫 번째 데이트",
  "date": "2026-05-10",
  "time": "18:00",
  "location": "홍대 맛집",
  "category": "식사",
  "memo": "예약 필요",
  "imageUrl": "",
  "confirmed": true,
  "createdAt": 1714000000000
}
```

### 미확정 버킷리스트 (`/users/{uid}/bucketlist/{itemId}`)
```json
{
  "title": "제주도 여행",
  "category": "여행",
  "priority": 1,
  "memo": "여름에 가고 싶어",
  "done": false,
  "createdAt": 1714000000000
}
```

**카테고리 예시:** 식사, 카페, 여행, 영화, 공연, 야외, 기타

## 필요 패키지

| 패키지 | 용도 | 버전 |
|--------|------|------|
| `table_calendar` | 캘린더 UI | ^3.1.2 |
| `home_widget` | 홈 스크린 위젯 | ^0.7.0 |
| `intl` | 날짜 포맷 | ^0.20.2 |

> 추가 전 기존 pubspec.yaml에서 동일 패키지 여부 확인 필수

## UI 구조

### HomePage 탭 구성 (기존 탭에 추가)
기존: [Drop, Chat, Settings]
추가: [Drop, **Date**, Chat, Settings] 또는 별도 FAB로 접근

### DatePage (캘린더)
- `TableCalendar` 위젯으로 월별 뷰
- 이벤트 있는 날 마커 표시 (보라색 도트)
- 날짜 탭 → 해당 날 이벤트 목록 표시
- 이벤트 탭 → 상세 다이얼로그

### 이벤트 상세 다이얼로그
- title, date, time, location, category, memo 표시
- 기존 `showDialog` 패턴 사용

### BucketlistPage (미확정)
- ListView로 항목 나열
- 우선순위(priority)로 정렬
- 완료 체크 가능 (done 토글)
- DatePage 하단 탭 또는 섹션으로 배치

### 홈 스크린 위젯
- 다음 가장 가까운 이벤트 title + date 표시
- `home_widget` 패키지 사용
- Android: AppWidgetProvider 등록 필요

## 구현 체크리스트

- [ ] pubspec.yaml 패키지 추가
- [ ] DateEvent / BucketItem 모델 클래스
- [ ] DatePage (캘린더 + 이벤트 목록)
- [ ] BucketlistPage
- [ ] 상세 다이얼로그
- [ ] HomePage 탭 연결
- [ ] 홈 위젯 (마지막 단계)

## 주의사항

- Firebase path: `/users/{uid}/dates` — uid는 `FirebaseAuth.instance.currentUser!.uid`
- 기존 앱 색상 테마 유지 (배경 `0xFF1A1A2E`, primary `0xFFA78BFA`)
- 홈 위젯은 Android만 (iOS 미지원)
- `flutter pub get` 후 `flutter build apk --release` 순서 준수
