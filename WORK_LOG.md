# WORK_LOG — tam-mobile-studio

## CURRENT TASK
버전 0.3.1 빌드 및 배포 (위젯 수정사항 포함)

## CURRENT STEP
1. [DONE] 위젯 파일 수정 (home_widget_large.xml, date_widget_info.xml, DateWidgetProvider.kt)
2. [DONE] Firebase 테스트 데이터 삽입 (4월 2026, 5개 이벤트 + 3개 버킷리스트)
3. [DONE] v0.3.0 빌드/배포 (date feature 포함)
4. [PENDING] v0.3.1 appVersion 업데이트 → 빌드 → GitHub Release → Firebase app_version

---

## DONE

### 2026-04-28 — v0.3.0
- Date 피처 전체 구현 (Calendar, EventCRUD, BucketlistCRUD)
- Firebase 경로: /users/{uid}/dates/, /users/{uid}/bucketlist/
- 패키지 추가: google_fonts, table_calendar, home_widget
- Android 홈 위젯 초기 구현 (DateWidgetProvider)
- GitHub Release v0.3.0 배포 완료

### 2026-04-28 — 위젯 버그 수정
- "표시할 수 없음" 원인: fontFamily="serif" → 제거
- 5×6 리사이즈: maxResize 500dp, targetCellWidth/Height 5×6
- 캘린더 그리드: 42 TextView 하드코딩 (tv_d00~tv_d41)
- Firebase 테스트 데이터 삽입 완료

---

## FAILED / ISSUES

- `android:description="TAM Studio Date Widget"` → raw string 불가, 제거
- `android:description="@string/app_name"` → strings.xml에 없어서 빌드 오류, 제거
- RemoteViews에 fontFamily → 위젯 크래시, 제거
- bash `UID` readonly → Firebase 삽입 시 Python urllib 사용

---

## NEXT STEPS

1. main.dart `appVersion` → '0.3.1'
2. `flutter build apk --release`
3. `cp app-release.apk tam-studio.apk`
4. `gh release create v0.3.1 tam-studio.apk`
5. Firebase app_version 업데이트 (latest: "0.3.1", apk_url 업데이트)
6. git commit + push

---

## DECISIONS

- 위젯 fontFamily: RemoteViews에서 커스텀 폰트 불가 → 시스템 기본 폰트 사용
- 위젯 그리드: 동적 생성 불가 → 42개 TextView 하드코딩
- 위젯 크기 단위: Galaxy One UI 기준 1셀 ≈ 73dp

---

## ANTI-PATTERNS

- APK 파일명 리네임 안하고 업로드 → tam-studio.apk가 아닌 이름으로 올라감
- appVersion 빌드 후 bump → APK 내부 버전 불일치
- RemoteViews XML에 fontFamily 사용 → 위젯 크래시
- `android:description`에 raw string 또는 미존재 @string 참조 → 빌드 오류
