---
name: date-orchestrator
description: tam-mobile-studio 데이트 기능 개발의 전체 파이프라인을 조율하는 오케스트레이터. "데이트 기능 만들어줘", "캘린더 구현", "데이트 일정 추가", "홈 위젯 만들어줘", "데이트 기능 재실행", "수정", "보완", "다시" 등의 요청 시 이 스킬을 사용할 것. flutter-designer → date-architect → date-implementer → dart-reviewer + Codex(GPT-5.4) 이중 리뷰 파이프라인으로 실행한다.
---

# date-orchestrator

**실행 모드:** 하이브리드 (서브 에이전트 파이프라인)
**패턴:** Pipeline (순차 의존)

## Phase 0: 컨텍스트 확인

`_workspace/` 디렉토리 존재 여부 확인:

| 상황 | 실행 모드 |
|------|---------|
| `_workspace/` 없음 | 초기 실행 → Phase 1부터 전체 |
| `_workspace/01_architect_design.md` 있음 + 부분 수정 요청 | 부분 재실행 → 해당 Phase만 |
| `_workspace/` 있음 + 새 요구사항 | 새 실행 → `_workspace/`를 `_workspace_prev/`로 이동 후 재실행 |

## Phase 0.5: UI 디자인 (flutter-designer)

**실행 모드:** 서브 에이전트
**선행 조건:** Phase 0 완료

```
Agent(
  subagent_type: "general-purpose",
  model: "opus",
  prompt: """
  flutter-designer 에이전트 역할로 작업한다.
  에이전트 정의: .claude/agents/flutter-designer.md

  frontend-design 스킬을 활성화하여 작업한다.

  컨텍스트:
  - 앱: 커플 데이트 일정 관리 Flutter 앱 (다크 테마)
  - 기존 색상: 배경 0xFF1A1A2E, primary 0xFFA78BFA
  - 구현할 화면: 캘린더 페이지, 이벤트 상세, 버킷리스트, 홈 위젯

  작업:
  1. lib/main.dart와 pubspec.yaml을 읽어 기존 스타일 파악
  2. flutter-designer.md 디자인 철학 적용
  3. _workspace/00_design_spec.md 생성
  """
)
```

**성공 기준:** `_workspace/00_design_spec.md` 생성됨

## Phase 1: 설계 (date-architect)

**실행 모드:** 서브 에이전트

```
Agent(
  subagent_type: "general-purpose",
  model: "opus",
  prompt: """
  date-architect 에이전트 역할로 작업한다.
  에이전트 정의: .claude/agents/date-architect.md
  도메인 가이드: .claude/skills/date-feature/SKILL.md

  요구사항: {사용자_요구사항}

  작업:
  1. lib/main.dart와 pubspec.yaml을 읽는다
  2. .claude/skills/date-feature/SKILL.md를 읽는다
  3. _workspace/00_design_spec.md를 읽는다 (flutter-designer 산출물)
  4. Firebase 스키마, 패키지, UI 구조를 설계한다 (디자인 스펙 반영)
  5. _workspace/01_architect_design.md를 생성한다
  """
)
```

**성공 기준:** `_workspace/01_architect_design.md` 생성됨

## Phase 2: 구현 (date-implementer)

**실행 모드:** 서브 에이전트
**선행 조건:** Phase 1 완료

```
Agent(
  subagent_type: "general-purpose",
  model: "opus",
  prompt: """
  date-implementer 에이전트 역할로 작업한다.
  에이전트 정의: .claude/agents/date-implementer.md

  작업:
  1. _workspace/01_architect_design.md를 읽는다
  2. lib/main.dart 전체를 읽는다
  3. pubspec.yaml을 읽는다
  4. 설계에 따라 코드를 구현한다 (pubspec.yaml + main.dart 수정)
  5. _workspace/02_implementer_log.md를 생성한다
  """
)
```

**성공 기준:** `_workspace/02_implementer_log.md` 생성됨, main.dart/pubspec.yaml 수정됨

## Phase 3: 이중 코드 리뷰 (dart-reviewer + Codex GPT-5.4)

**실행 모드:** 서브 에이전트 2개 병렬 실행
**선행 조건:** Phase 2 완료

### Phase 3a: dart-reviewer (Claude Opus)

```
Agent(
  subagent_type: "general-purpose",
  model: "opus",
  prompt: """
  dart-reviewer 에이전트 역할로 작업한다.
  에이전트 정의: .claude/agents/dart-reviewer.md

  검토 대상:
  - lib/main.dart (새로 추가된 Date/Bucketlist 관련 클래스)
  - pubspec.yaml (추가된 패키지)
  - android/app/src/main/AndroidManifest.xml (홈 위젯 등록 여부)
  - _workspace/02_implementer_log.md (구현 로그)

  dart-reviewer.md의 리뷰 기준에 따라 검토 후
  [REVIEW RESULT] / [OVERALL] 형식으로 결과를
  _workspace/03a_dart_review.md에 저장한다.
  """
)
```

### Phase 3b: Codex GPT-5.4 크로스 리뷰

```
Skill(codex:codex-rescue,
  prompt: """
  Flutter 데이트 기능 구현 코드를 read-only 리뷰한다.

  검토 대상: lib/main.dart (Date/Bucketlist 관련 신규 클래스), pubspec.yaml
  관점: Firebase 메모리 누수, Dart null safety, 홈 위젯 Android 설정 누락
  출력: _workspace/03b_codex_review.md 에 CRITICAL/WARNING/INFO 형식으로 저장
  """
)
```

> Phase 3a, 3b는 독립적이므로 병렬 실행 가능. 단, 둘 다 완료 후 Phase 4 진행.

**성공 기준:** `_workspace/03a_dart_review.md` + `_workspace/03b_codex_review.md` 생성됨

## Phase 4: 리뷰 결과 종합 및 후처리

3a(Claude) + 3b(Codex) 결과를 합산하여 판단:
- 어느 쪽이든 CRITICAL 있으면 → 사용자에게 보고 후 Phase 2 재실행 여부 확인
- WARNING/INFO만 있으면 → 두 리뷰 결과 함께 표시, 사용자가 원할 때 수정
- 둘 다 PASS → 다음 단계 안내

**다음 단계 안내:**
```bash
# 1. 패키지 설치
flutter pub get

# 2. 빌드 테스트
export ANDROID_HOME="C:/android-sdk"
export JAVA_HOME="C:/Program Files/Microsoft/jdk-17.0.18.8-hotspot"
flutter build apk --release

# 3. 버전 bump 필요 시
# appVersion in lib/main.dart 업데이트 후 재빌드
```

## 에러 핸들링

| 상황 | 처리 |
|------|------|
| Phase 1 실패 (설계 파일 미생성) | 사용자에게 요구사항 명확화 요청 |
| Phase 2 실패 (컴파일 오류 예상) | `_workspace/02_implementer_log.md` 확인 후 보고 |
| Phase 3a FAIL | CRITICAL 항목 보고 → Phase 2 재실행 여부 확인 |
| Phase 3b Codex 미응답 | 3a 결과만으로 Phase 4 진행, "Codex 리뷰 미완료" 명시 |

## 테스트 시나리오

**정상 흐름:**
- 입력: "데이트 기능 만들어줘, 날짜/장소/메모 필드 필요하고 버킷리스트도"
- 기대: 설계 → 구현 → 리뷰 순서로 실행, main.dart에 DatePage/BucketlistPage 추가됨

**부분 재실행:**
- 입력: "캘린더 색상 바꿔줘" (기존 _workspace 존재 시)
- 기대: Phase 2만 재실행 (설계 재사용)

**에러 흐름:**
- Codex 미응답 → 3a(dart-reviewer)만으로 판단, "Codex 리뷰 미완료" 명시 후 Phase 4 진행
