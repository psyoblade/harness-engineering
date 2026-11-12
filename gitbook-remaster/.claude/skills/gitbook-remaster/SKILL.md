---
name: gitbook-remaster
description: "GitBook 실습서(oneday 시리즈) 한 권 또는 지정한 페이지를 에이전트 팀(gitbook-linter, lab-verifier, learner-sim, reviser)으로 리뷰·수정하고, 사람의 diff 승인 후 원본 레포에 review 브랜치와 PR 을 만든다. '깃북 리마스터', 'gitbook remaster', '<책> 리마스터 해줘', '리마스터 재실행' 요청 시 사용. merge 는 하지 않는다."
allowed-tools: Bash Read Write Glob Grep Agent TaskCreate TaskUpdate TaskList TaskGet SendMessage AskUserQuestion
---

# GitBook Remaster Skill
리더(이 세션)는 팀을 구성하고 태스크를 배정하며, 게이트(스크립트)를 직접 실행해 통과 여부를 판정한다. 리더는 리뷰 내용과 책 수정을 직접 쓰지 않는다. 원본 책은 Phase 5 승인 전까지 읽기 전용이다.

## 경로
- `<scripts>`: 이 스킬 폴더의 `scripts/` (스킬 로드 시 알려 주는 Base directory 기준 절대 경로)
- `<project>`: 현재 작업 디렉토리. `docs/style-guide.md`, `docs/remaster-policy.md` 가 있어야 한다.
- `<book>`: 사용자가 지정한 책 루트 절대 경로. 이름만 주면 `~/git/psyoblade/oneday/<이름>`
- `<ws>`: `<project>/_workspace/<book 디렉토리 이름>`

## 팀 구성
| 팀원 이름 | agent type | 태스크 |
|---|---|---|
| `linter` | gitbook-linter | T1 → `<ws>/01_lint.md` |
| `lab` | lab-verifier | T2 → `<ws>/02_lab.md`, 재검증 V<n> |
| `learner` | learner-sim | T3 → `<ws>/03_learner.md` |
| `reviser` | reviser | T5 (수정), R<n> (feedback 반복) |

## Workflow

### Phase 0. 입력과 사전 점검
1. `<book>` 과 `pages`(선택)를 확정한다. 모호하면 AskUserQuestion 으로 묻는다.
2. 아래를 모두 확인하고, 하나라도 실패하면 이유를 알리고 종료한다.
   - `git -C <book> status --porcelain` 출력이 비어 있음 (원본에 미커밋 변경 없음)
   - `<project>/docs/remaster-policy.md`, `<project>/docs/style-guide.md` 존재
   - `python3 --version` 성공
   - `echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 가 `1`
3. `<ws>` 가 이미 있으면 `<ws>.bak-<YYYYMMDD-HHMM>` 으로 이름을 바꾸고 새로 만든다 ("리마스터 재실행" 은 항상 새로 시작).
4. 기준값을 기록한다: `python3 <scripts>/lint.py <book>` 의 SUMMARY 줄 → `<ws>/00_baseline.txt`

### Phase 1. 팀 구성
위 표의 4명을 각 agent type 으로 팀원으로 생성한다. 생성 프롬프트에는 이름, 역할 한 줄, "배정된 태스크만 수행하고 끝나면 태스크를 completed 로 바꾼다" 만 쓴다. 입력 값은 태스크에 쓴다.

### Phase 2. 태스크 생성
TaskCreate 로 아래 태스크를 만든다. 각 태스크 설명에는 해당 에이전트 정의의 "입력" 항목을 모두 절대 경로로 채워 넣는다.

| ID | 제목 | 담당 | 의존 |
|---|---|---|---|
| T1 | lint 리뷰 | linter | - |
| T2 | lab 리뷰 | lab | - |
| T3 | learner 리뷰 | learner | - |
| G1 | 리뷰 게이트 (리더) | 리더 | T1, T2, T3 |
| T5 | 수정 | reviser | G1 |

reviser 는 G1 이 끝나기 전에는 시작할 수 없다. 팀원이 끝낸 리포트를 리더가 검사하기 전에 수정이 시작되는 것을 막기 위해서다.

### Phase 3. Fan-out 과 리뷰 게이트 (G1)
1. T1~T3 는 병렬로 진행된다. 리더는 완료 알림을 기다린다 (폴링하지 않는다).
2. 리포트가 도착할 때마다 `python3 <scripts>/check_report.py <lint|lab|learner> <book> <리포트>` 를 실행한다.
   - FAIL 이면 `BAD` 줄을 그대로 SendMessage 로 해당 팀원에게 보내 리포트를 고치게 한다. 팀원당 최대 2회.
   - 2회 후에도 FAIL 이면 그 리포트는 제외하고 진행하며, 최종 보고에 "리포트 제외: <이름>" 을 남긴다.
3. 세 리포트 판정이 끝나면 G1 을 completed 로 바꾼다.

### Phase 4. 수정과 검증 루프 (최대 3회)
0. reviser 에게 수정(T5, R<n>)을 맡기기 직전에 `<ws>/book/` 을 `<ws>/book.prev/` 로 복사해 둔다 (첫 회는 원본 사본이 없으므로 생략).
1. T5 가 끝나면(`<ws>/book/`, `04_revise.md`, `04_revise.diff`) 리더가 아래를 검증한다.
   - V1 `python3 <scripts>/check_report.py revise <book> <ws>/04_revise.md` → PASS
   - V2 `python3 <scripts>/lint.py <ws>/book` → ERROR 가 0 이거나 `00_baseline.txt` 보다 적음
   - V3 생략 판정: `python3 <scripts>/book_sync.py code <ws>/book.prev <ws>/book` 가 `CODE=0` 이면 (코드 블록 안 명령·출력이 바뀌지 않았으면) V3 를 생략하고 직전 V3 결과를 그대로 쓴다.
   - V3 lab 재검증: TaskCreate 로 `V<n> lab 재검증` 태스크를 `lab` 에 배정한다. 입력은 `book=<ws>/book`, `output_dir=<ws>/verify-<n>/`, `prev_dir=<ws>`(첫 회) 또는 `<ws>/verify-<n-1>/`, `changes=<book_sync.py diff 결과>` (재검증 모드 — 바뀐 부분만 읽는다). `lab` 이 종료됐으면 같은 agent type 으로 다시 생성한다. 결과 `verify-<n>/02_lab.md` 에서 유형이 `실행 실패`, `출력 불일치` 인 행 → 0 건
   - V4 `python3 <scripts>/book_sync.py diff <book> <ws>/book` → `D`(삭제) 항목은 `04_revise.md` 에 삭제로 기록된 파일만 허용 (복사 누락 방지)
2. 모두 통과하면 Phase 5 로 간다.
3. 실패하면 실패 내용(V1 의 BAD 줄, V2 의 ERROR 줄, V3 의 해당 행, V4 의 기록 없는 D 항목)을 모아 `R<n> 수정 반복` 태스크를 `reviser` 에 배정한다 (입력에 `feedback` 포함). 끝나면 1 로 돌아간다.
4. 직전 반복과 같은 실패(같은 파일:줄·유형)가 다시 나오면 진전이 없는 것이므로 바로 루프를 멈춘다. 3회째에도 실패하면 루프를 멈추고, 남은 실패를 그대로 Phase 5 보고서에 "자동 검증 미통과" 로 표시한다.

### Phase 5. 사람 검토, 반영, 정리
1. `<ws>/remaster_report.md` 를 쓴다.
   - 요약: 리뷰 건수(리포트별), 조치 건수(수정/보류/거부), 반복 횟수, V1~V4 결과
   - 보류 목록 (저자 결정 필요)
   - 변경 파일 목록: `python3 <scripts>/book_sync.py diff <book> <ws>/book`
   - 자동 검증은 통과했지만 V3 리포트에 남은 행(`설명 불일치`, `지시 누락`, `버전·환경`) — 사람이 판단할 후속 항목
2. 보고서 경로와 요약을 보여 주고 AskUserQuestion 으로 묻는다: `승인` / `수정 지시` / `중단`.
   - 수정 지시: 사용자 입력을 feedback 으로 Phase 4 의 3 을 수행한다 (반복 횟수에 포함하지 않음).
   - 중단: 6 으로 간다.
3. 승인 시 원본 레포에 반영한다.
   - `git -C <book> switch -c review/<YYYYMMDD> main`
   - `python3 <scripts>/book_sync.py apply <book> <ws>/book` (review/ 브랜치·깨끗한 작업 트리가 아니면 스크립트가 거부한다)
   - `git -C <book> add -A` 후 `git -C <book> commit -m "[리마스터] <요약 한 줄>"` (책의 `[태그] 메시지` 형식)
4. push 와 PR 은 각각 사용자 확인을 받는다 (settings 의 ask 규칙). `git -C <book> push -u origin review/<YYYYMMDD>` → `gh pr create` (본문은 `remaster_report.md`).
5. PR URL 을 보고한다. merge 는 하지 않는다.
6. 팀원들에게 종료를 요청한다. `_workspace/` 는 지우지 않는다.

## 주의
- 리더는 리포트와 책 사본을 직접 고치지 않는다. 고칠 것은 반드시 팀원에게 태스크나 메시지로 보낸다.
- 게이트 판정은 스크립트 결과로만 한다. 팀원이 "PASS 했다" 고 보고해도 리더가 다시 실행한다.
- 원본 `<book>` 은 Phase 5-3 전까지 어떤 명령으로도 수정하지 않는다.
- `git push` 는 `review/` 브랜치에만 한다. `main`, `master` push 와 `gh pr merge` 는 settings 에서 금지되어 있다.
