# Codex Cross-Review — tam-mobile-studio Date Feature + Android Widget
> 리뷰 기준일: 2026-04-28 | 검토자: Codex (read-only, 독립 교차 검증)

---

[REVIEW RESULT]
- 심각도: CRITICAL
- 항목: Firebase Realtime Database `onValue.listen()` 구독을 저장하지도 않고 `dispose()`에서 해제하지도 않아 페이지 폐기 후에도 리스너가 살아남음. 콜백 내부 `setState()`도 `mounted` 체크 없이 호출됨.
- 위치: lib/main.dart:341
- 수정 방향: `StreamSubscription` 필드에 구독을 저장하고 `dispose()`에서 `cancel()`할 것. 콜백의 `setState()` 전에도 `if (!mounted) return;` 확인 추가.

---

[REVIEW RESULT]
- 심각도: WARNING
- 항목: 채팅 페이지도 `onValue.listen()` 구독을 저장/해제하지 않아 동일한 생명주기 누수 존재. `data == null` 분기와 정상 분기 모두 `mounted` 확인 없이 `setState()`/`_scrollToBottom()` 호출.
- 위치: lib/main.dart:509
- 수정 방향: 별도 `StreamSubscription` 필드 추가 후 `dispose()`에서 해제. `setState()`와 `_scrollToBottom()` 진입 전 `mounted` 보장.

---

[REVIEW RESULT]
- 심각도: WARNING
- 항목: `FirebaseAuth.instance.currentUser!.uid` 강제 언래핑 — 인증 직후 `currentUser`가 null인 레이스 케이스에서 즉시 예외 발생 가능.
- 위치: lib/main.dart:158
- 수정 방향: `signInWithCredential()` 반환값인 `UserCredential.user`를 직접 사용하거나, null 체크 후 처리.

---

[REVIEW RESULT]
- 심각도: WARNING
- 항목: 여러 비동기 작업(`await`) 뒤 `setState()` 호출 전 `mounted` 확인 누락. 화면 이탈 중 구글 로그인/파일 I/O 완료 시 폐기된 State에 접근 가능.
- 위치: lib/main.dart:120, lib/main.dart:147, lib/main.dart:163, lib/main.dart:165
- 수정 방향: 각 `await` 이후 `if (!mounted) return;` 패턴 적용 후 `setState()` 호출.

---

[REVIEW RESULT]
- 심각도: WARNING
- 항목: 홈 위젯 달력 그리드가 저장된 `widgetMonth`/`widgetDatesJson` 기준이 아니라 항상 디바이스의 현재 월로 계산됨. 월 경계에서 위젯 데이터가 미갱신된 상태면 헤더/이벤트 데이터와 그리드가 서로 다른 월을 가리킴.
- 위치: android/app/src/main/kotlin/com/zziktam/tam_mobile_studio/DateWidgetProvider.kt:47
- 수정 방향: 저장된 연/월 값을 파싱해 그 월 기준으로 `firstDayOffset`, `daysInMonth`, `today` 강조 여부를 계산할 것.

---

[REVIEW RESULT]
- 심각도: WARNING
- 항목: 이벤트 표시용 날짜 파싱이 `yyyy-MM-dd`에서 일(day) 숫자만 추출. 월/연도 정보가 버려져 저장 데이터와 렌더링 대상 월이 어긋나면 동일 일자 번호가 잘못 강조됨.
- 위치: android/app/src/main/kotlin/com/zziktam/tam_mobile_studio/DateWidgetProvider.kt:39
- 수정 방향: day만 저장하지 말고 전체 날짜 기준 비교, 또는 최소한 렌더링 월/연도와 함께 검증.

---

[REVIEW RESULT]
- 심각도: INFO
- 항목: HYPOTHESIS — `targetCellWidth="4"`, `targetCellHeight="5"` 는 월 헤더 + 요일 헤더 + 6주 그리드 + 하단 프리뷰를 포함하는 large 위젯 의도에 비해 작을 수 있음. 일부 런처에서 기본 배치 크기가 과소하게 잡힐 가능성.
- 위치: android/app/src/main/res/xml/date_widget_info.xml:9
- 수정 방향: 주요 런처에서 실제 기본 배치 크기 검증 후 large 위젯 의도에 맞게 cell 수 조정.

---

[REVIEW RESULT]
- 심각도: INFO
- 항목: home_widget_large.xml의 42개 TextView 전수 확인 결과, 명백한 RemoteViews 비호환 속성(예: ripple, clip 관련, ConstraintLayout 복잡 constraint 등)은 이번 검토 범위에서 발견되지 않음.
- 위치: android/app/src/main/res/layout/home_widget_large.xml
- 수정 방향: 해당 없음.

---

[OVERALL]
FAIL

사유:
- Flutter: 확인된 구독 해제 누락(CRITICAL x1), 강제 언래핑 및 비동기 mounted 누락(WARNING x2)
- Android: 위젯 월 계산 기준이 저장 데이터와 분리됨(WARNING x2)
- 기존 dart-reviewer 3개 항목 독립 교차 확인 결과: 모두 실제 코드에서 재확인됨 (CONFIRMED)
