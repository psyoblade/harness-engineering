# gitbook-remaster 진행 프로세스

## 목표
oneday 깃북 6권을 오케스트레이터 스킬(`gitbook-remaster`)로 리마스터한다. `git-for-oneday` 로 파일럿을 완성한 뒤 나머지 5권으로 확장한다 (`docs/book-inventory.md`).

## 성공 기준
- 정답지(`fixtures/answer-key.md`) 항목을 오케스트레이터가 모두 탐지한다 (재현율 100%).
- 리마스터 후 모든 실습 블록이 sandbox 재실행에서 PASS 한다.
- 원본 레포 PR 이 GitBook 에서 정상 렌더링된다.

## 목표 구조
```
gitbook-remaster/
├── CLAUDE.md
├── PROCESS.md
├── docs/style-guide.md              # 1단계: 책 작성 규칙
├── docs/remaster-policy.md          # 저자 결정 (버전, 브랜치 등)
├── fixtures/answer-key.md           # 1단계: 정답지 (알려진 결함 목록)
├── .claude/
│   ├── settings.json                # 권한 (git push, merge 금지)
│   ├── agents/
│   │   ├── gitbook-linter.md        # 2단계
│   │   ├── lab-verifier.md          # 3단계
│   │   ├── learner-sim.md           # 4단계
│   │   └── reviser.md               # 4단계
│   └── skills/gitbook-remaster/
│       ├── SKILL.md                 # 5단계: 6 Phase 오케스트레이터 (dry-run: docs/dry-run-log.md)
│       └── scripts/
│           ├── lint.py              # 2단계: 결정적 구조 검사
│           ├── lab_run.py           # 3단계: 실습 블록 추출·sandbox 실행
│           ├── check_refs.py        # 3단계: 리포트 줄 번호 검증
│           ├── check_report.py      # 체크포인트: 리포트 형식 게이트 (check_refs 포함)
│           └── book_sync.py         # 5단계: 원본↔사본 비교·반영 (review/ 브랜치 가드)
└── _workspace/                      # 실행 산출물
```

## 단계

| 단계 | 내용 | 산출물 | 확인 |
|---|---|---|---|
| 0 | 프로젝트 골격 | `CLAUDE.md`, `PROCESS.md` | 디렉토리 생성 |
| 1 | 기준 정립 | `docs/style-guide.md`, `fixtures/answer-key.md` | 정답지 항목이 실제 파일·줄 번호와 일치 |
| 2 | gitbook-linter (6권 대상) | 에이전트 + `scripts/lint.py` | git lint 항목 + 교차 세트 X03~X05 전부 탐지, 책별 변형은 오탐 없음 |
| 3 | lab-verifier (bash 런타임) | 에이전트 + 실습 블록 실행 스크립트 | git lab 항목 탐지 |
| 4 | learner-sim, reviser | 에이전트 2개 | 단독 실행으로 챕터 1개 리포트/수정안 생성 |
| 5 | 오케스트레이터 | `SKILL.md` (6 Phase) + dry-run 로그 | Phase 순서·의존성·루프 상한 확인 |
| 6 | 실제 팀 실행 E2E | `docs/stage6-runbook.md` 로 Claude Code 실행 (git 책 전체) | 팀 동작 체크리스트, dry-run 결과·정답지 대비 |
| 7 | git 리마스터 | env 공통 + git 전 챕터 수정, `review/YYYYMMDD` PR | 실습 재실행 PASS, GitBook 미리보기 |
| 7+ | 확장 | 런타임 어댑터(python → sql → hdfs) 추가 후 linux → python → mysql → hadoop → docker | 책별 실습 재실행 PASS |
| 8 | 회고·릴리스 | 루트 README 회고, 설치 검증 | `install-claude-skill.bat gitbook-remaster` 동작 |
| (확장) | 신규 챕터 모드 | 예: `git stash`, `git worktree` 챕터 | 같은 파이프라인 통과 |

## 6 Phase 매핑 (5단계 설계 초안)

| Phase | 내용 |
|---|---|
| 0 입력 | 대상 챕터와 SUMMARY.md 를 `_workspace/input/` 에 복사 |
| 1 팀 | linter, lab-verifier, learner-sim, reviser |
| 2 태스크 | reviser 는 리뷰어 3개 작업에 의존 |
| 3 Fan-out | `01_lint.md`, `02_lab.md`, `03_learner.md` 병렬 생성 |
| 4 생성·검증 루프 | reviser 수정 → lint·lab 재실행, 최대 3회 |
| 5 통합 | `_workspace/remaster_report.md`, 승인 시 브랜치·PR 생성 |

## 결정 기록
- 2026-11-12: 6단계 실제 팀 실행 성공($2.99, 27분, V1~V4 PASS, review/20261112 커밋). new-style 병합 삭제 유지, 컨테이너 git 2.34.1 확인
- 2026-11-12: gitbook-linter 를 haiku 로 전환 — 단독 실행 $0.026, 정답지 lint 13/14(sonnet 실행 11/13), 신규 L14
- 2026-11-12: 실습 컨테이너 ubuntu:22.04 고정(-multi 미사용), training 레포 compose `version` 제거, 사람 판단 잔여 모두 반영, V3 생략 판정(`book_sync.py code`) 추가
- 2026-11-12: 브랜치 명령 명시, 실습 컨테이너 ubuntu:22.04 + git 2.28 확인 단계, 루프 보완(원인 우선 수정·재검증 모드·반복 실패 조기 중단)
- 2026-11-12: V3 잔여 5건 리마스터 포함, 루프 조건(실행 실패·출력 불일치만 자동) 확정, 팀원 스크립트 실행·_workspace 쓰기 allow, SKILL 팀 동작은 6단계에서 확인
- 2026-11-11: Claude Code v2.1.311 기준 → 에이전트 팀은 자연어로 구성 (TeamCreate/TeamDelete 없음, TaskCreate·SendMessage 사용). 사람 검토 게이트는 reviser 뒤 diff 승인 1곳
- 2026-11-11: R01 은 "잘못된 커밋 → revert", 보류 5건 모두 수정, Compose 최소 v2.5.0, 리뷰어는 1회 실행 + 사람 검토 (5단계에 사람 검토 게이트 포함)
- 2026-11-09: 오케스트레이션은 에이전트 팀 방식 (학습 목적). 실험 기능, 대화형 세션 전용
- 2026-11-09: R01 예제 재작성, 실습 환경 = training/basic
- 2026-11-09: `_workspace/` 는 git 제외 / git 2.28+, Compose v2 전환, master 흐름 유지 (`docs/remaster-policy.md`)
- 2026-11-09: 6권 조사 후 "넓게 조사, 좁게 구현, 순서대로 확장"으로 결정 (`docs/book-inventory.md`)

## 체크포인트 기록
- 2026-11-09: Claude Code 직접 실행(`01_lint.cc.md`) 결과가 정의된 형식과 다르고 의미 검사 0건. check_refs 는 참조 0개라 PASS (게이트 구멍) → `check_report.py` 추가. 원인(서브에이전트 실제 호출 여부) 확인 중
- 2026-11-10: `claude --agent gitbook-linter` 재실행 → check_report PASS, lint 정답 11/13 (L12·L13 누락, L06 부분). 판단 차이 1건(.bashrc 블록) → style-guide 보완, agent 규칙명 고정

## 미결정 사항

## 진행 기록
- [x] 0단계: 프로젝트 골격 생성
- [x] 1단계: style-guide.md, answer-key.md (결함 25건: lint 11 / lab 8 / learner 6)
- [x] 1.5단계: 6권 조사, style-guide 일반화, 교차 검증 세트(X01~X05)
- [x] 2단계: lint.py(6권 실행) + gitbook-linter. git lint 11/11, X03~X05 탐지. 신규 L12·L13·X06~X09, 오탐 1건 → 에이전트 규칙 보완
- [x] 3단계: lab_run.py + lab-verifier + check_refs.py. git lab 8/8(2회 실행 모두), R01 교차 탐지. 신규 B09~B11. 1회차 누적 줄 번호 오류 7건 → check_refs 게이트 추가 후 0건
- [x] 4단계: learner-sim + reviser + check_report(learner, revise). learner R01~R05 5/5 (R06 은 lint 로 재분류), 신규 R07~R09, 오탐 1. reviser 43건 (수정 37/보류 5/거부 1), lint ERROR 2→0, 원본 무변경. R01 재작성 결과는 정책 문구 모호로 의도와 반대(올바른 수정을 revert) → 정책 문구 수정 후 reviser feedback 1회로 재작성(잘못된 커밋 `4,기생충` → revert, sandbox 확인), 보류 5건 반영 → 수정 42/보류 0/거부 1, lint ERROR 0 WARN 0
- [x] 5단계: settings.json(팀 env, deny/ask) + SKILL.md(6 Phase, 게이트 G1·V1~V4, 사람 승인) + book_sync.py. dry-run: 게이트 전부 real 실행 PASS, V3 재검증 실행 실패 0. 반영 절차 위험(.git 비교) 발견 → book_sync 로 교체
- [ ] 6단계
- [ ] 7단계
- [ ] 8단계
