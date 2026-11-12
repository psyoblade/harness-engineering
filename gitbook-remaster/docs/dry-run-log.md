# gitbook-remaster dry-run 로그 (5단계)

대상: `git-for-oneday` (main@5b2cb5a), 2026-11-11
방식: 팀 생성·태스크·메시지는 **mock**(에이전트 팀은 대화형 세션 전용이라 6단계에서 실제 실행), 게이트 스크립트와 팀원 작업은 **real**(2~4단계 산출물과 이번 재검증 결과 사용).

| Phase | 단계 | 방식 | 실행 / 판정 | 결과 |
|---|---|---|---|---|
| 0 | 원본 미커밋 변경 | real | `git -C <book> status --porcelain` | 빈 출력 ✅ |
| 0 | 정책·스타일 문서 | real | `docs/remaster-policy.md`, `docs/style-guide.md` | 존재 ✅ |
| 0 | python3 | real | `python3 --version` | 3.10.12 ✅ |
| 0 | 팀 기능 | mock | `echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Claude Code 밖이라 빈 값. 세션 안에서는 `.claude/settings.json` env 로 `1` 예상 |
| 0 | 기준값 | real | `lint.py <book>` | ERROR=2 WARN=3 |
| 1 | 팀 구성 | mock | linter / lab / learner / reviser 생성 (agent type 지정) | — |
| 2 | 태스크 | mock | T1·T2·T3 → G1(리더, T1~T3 의존) → T5(G1 의존) | — |
| 3 | T1 lint | real | 사용자 Claude Code `--agent gitbook-linter` 결과 `01_lint.cc.md` | 14행 |
| 3 | T2 lab | real | `02_lab.md` (3단계 2회차) | 12행 |
| 3 | T3 learner | real | `03_learner.md` (4단계) | 16행 |
| 3 | G1 게이트 | real | `check_report.py lint/lab/learner` | 3개 모두 PASS → G1 completed |
| 4 | T5 수정 | real | reviser 1회 + 저자 feedback 1회 | 수정 42 / 보류 0 / 거부 1 |
| 4 | V1 | real | `check_report.py revise` | PASS ✅ |
| 4 | V2 | real | `lint.py <ws>/book` | ERROR=0 WARN=0 (기준 2) ✅ |
| 4 | V3 | real | lab-verifier 재검증 `verify-1/02_lab.md` | steps=26, 실행 실패·출력 불일치 0 ✅ (충돌 2건은 책이 안내한 의도된 충돌) |
| 4 | V4 | real | `book_sync.py diff` | M=6 D=1 (`images/git-small.png`, 04_revise 에 기록) ✅ |
| 4 | 루프 | — | 반복 1회차에 통과 | 상한 3회 미사용 |
| 5 | 보고서 | real | `_workspace/git/remaster_report.md` | 작성 |
| 5 | 사람 승인 | mock | AskUserQuestion 승인/수정 지시/중단 | 6단계에서 실제 |
| 5 | 반영 가드 | real | `book_sync.py apply` 를 main 브랜치에서 실행 | 거부 (exit 1) ✅ |
| 5 | push·PR | mock | settings `ask` 규칙으로 각각 확인 | — |

## dry-run 에서 발견해 고친 것
1. Phase 5 반영 방법이 위험했다. `git diff --no-index` 는 원본의 `.git` 까지 비교해서, "사본에 없는 파일은 git rm" 을 그대로 따르면 `.git`·`LICENSE` 삭제로 이어질 수 있었다. → `book_sync.py`(추적 파일 기준 비교, review/ 브랜치·깨끗한 트리에서만 apply) 추가, V4 게이트 추가.
2. 실제로 사본에 `LICENSE`, `.gitignore` 가 빠져 있었다 (사본을 md 파일만 옮긴 탓). V4 가 `D` 로 잡아냄 → 복원.

## 자동 검증 이후 남은 항목 (V3 리포트, 사람 판단)
| # | 파일:줄 | 유형 | 내용 | 메모 |
|---|---|---|---|---|
| 1 | core/branch.md:54 | 지시 누락 | old-style 커밋 후 main 으로 돌아가라는 지시 없음 → new-style 이 old-style 에서 파생 | 원본부터 있던 결함 (정답지 미수록) |
| 2 | core/README.md:23 | 버전·환경 | `docker compose exec -it` 이 v2 에서 오류라는 주장 | 확인 필요 — Compose v2 버전에 따라 `-i/-t` 지원 여부 다름 |
| 3 | core/version.md:25 | 설명 불일치 | `1,인간교실` — R01 재작성으로 이 오타는 더 이상 실습 소재가 아님 | R01 재작성의 파생 효과 |
| 4 | env/README.md:155 | 지시 누락 | hadoop 컨테이너 접속 명령 없음 | |
| 5 | env/README.md:145 | 설명 불일치 | `-ptiger` 인데 password 프롬프트 표시 | |

## 검증 루프 실연 (2026-11-12)
| 순서 | 작업 | 결과 |
|---|---|---|
| 1 | 저자 feedback: V3 잔여 5건 반영 (reviser R2, 수정 6행) | V1·V2 PASS |
| 2 | V3 verify-2 | 출력 불일치 1 (리베이스 충돌 중 로그) → 루프 |
| 3 | reviser R3 (출력 불일치만 수정) | V1·V2 PASS |
| 4 | V3 verify-3 | 출력 불일치 1 (new-style 뒤 main 복귀 누락) → 상한 3회 도달, 중단 |
| 5 | Phase 5 보고서 | "자동 검증 미통과" 1건 + 사람 판단 5건으로 표시 |

관찰
- verify 를 돌릴 때마다 lab-verifier 가 다른 결함을 찾는다 (verify-2 는 old-style, verify-3 는 new-style 의 같은 유형 결함). 보정 방식이 실행마다 달라 탐색 경로가 바뀌기 때문이다. 루프 상한이 없으면 끝나지 않는다.
- 같은 유형(지시 누락)인데 한 번은 사람 판단 항목, 한 번은 그 결과로 생긴 출력 불일치가 루프 대상이 됐다. 루프 조건을 "유형" 으로만 나누면 원인과 증상이 다른 경로로 처리된다.
- 비용: lab-verifier 1회 약 10만 토큰, reviser 반복 1회 약 7만 토큰.

## 루프 보완 후 (2026-11-12)
| 순서 | 작업 | 결과 |
|---|---|---|
| 1 | 보완: reviser "출력 불일치는 원인(지시 누락)부터", lab-verifier 재검증 모드(바뀐 페이지만 읽기), SKILL "같은 실패 반복 시 조기 중단" | — |
| 2 | 저자 feedback R4: 브랜치 생성·전환·main 복귀 명령 블록, 컨테이너 22.04 + `git --version` 확인 | 2개 파일 +38/-3 |
| 3 | V3 verify-4 (재검증 모드, prev=verify-3) | 대조 단계 5개, 실행 실패·출력 불일치 0 → 통과 |

토큰: 전체 재검증 약 10만 → 재검증 모드 약 8.3만, 시간 90초 → 37초. 토큰 절감은 약 20% 에 그친다 — 에이전트 정의·시스템 프롬프트 같은 고정 비용이 크고, plan.sh 와 run.log 를 읽는 비용은 남기 때문이다.

## 마무리 반복 (2026-11-12)
| 순서 | 작업 | 결과 |
|---|---|---|
| 1 | 실습 환경 레포: basic ubuntu 이미지 22.04, `version` 제거 4개 파일 (미커밋) | — |
| 2 | 저자 feedback R5: version.md 표현, L06·L12·L13 | 4개 파일 6줄 |
| 3 | V3 생략 판정 `book_sync.py code` | CODE=2 (branch.md 의 README 내용 블록 표 헤더) → 생략 불가 |
| 4 | V3 verify-5 (재검증 모드, 대조 3단계) | 결함 0, 그러나 check_report FAIL — 게이트 버그 |
| 5 | check_report 수정: 행 0개 + "결함 없음" 이면 PASS (메시지와 동작 불일치였음) | PASS |

관찰
- lab-verifier 는 게이트를 통과하려고 가짜 결함 행을 만들지 않고 게이트와 메시지의 모순을 보고했다. 게이트 스크립트도 테스트 대상이다 (결함 0 인 경우를 테스트하지 않았음).

