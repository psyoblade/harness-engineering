---
name: code-review
description: "source 브랜치를 target 브랜치에 머지하는 PR 을 4인 팀(lexical, platform, advisor, chair)으로 리뷰하고 Bitbucket 에 붙여 넣을 md 를 만든다. /code-review 로 직접 호출할 때만 사용."
disable-model-invocation: true
argument-hint: "[source-branch] [target-branch] [--deep]"
allowed-tools: Bash Agent Read Write AskUserQuestion
---

# Code Review Skill
리뷰 대상을 스크립트로 SHA 고정하고, 리뷰어 3명이 병렬로 리뷰한 뒤 chair 가 판정·종합한다. 리뷰 결과 제시까지만 하며 PR 코멘트 게시, 커밋, 푸시, 머지, 브랜치 이동은 하지 않는다.

인자: `$ARGUMENTS`
- 첫 번째 = source (리뷰할 브랜치), 두 번째 = target (머지될 브랜치). PR 화면의 from → to 순서다.
- `--deep` 이 있으면 변경 규모와 관계없이 advisor 를 실행한다. 순서 인자에서는 뺀다.

## 경로
스킬이 로드될 때 알려 주는 Base directory 로 절대 경로를 만들고, 이하 `<scripts>`, `<refs>` 로 표기한다.
- `<scripts>/resolve-target.sh` — 대상 확정·프로파일 판정. 종료 코드 0 = OK, 2 = ASK, 1 = ERROR
- `<scripts>/verify-locations.sh <SOURCE_SHA>` — 지적 위치(stdin) 검사. 마지막 줄 `RESULT: PASS|FAIL`
- `<scripts>/lint-md.sh <파일>` — 최종 md 검사. 마지막 줄 `RESULT: PASS|FAIL`
- `<refs>/finding-format.md`, `output-template.md`, `platform-guide.md`, `general-guide.md`

## Workflow
1. 대상 확정.
   `bash "<scripts>/resolve-target.sh" <source> <target>` 를 실행한다 (인자가 없으면 빈 채로 실행).
   - 0 → `SUMMARY` 줄을 사용자에게 보여 주고 2단계로 간다.
   - 2 → `ASK` 사유와 `CANDIDATE` 후보로 AskUserQuestion 을 한 번 한다 (선택지: 그대로 진행 / 후보 브랜치 / 직접 입력). 답으로 스크립트를 다시 실행한다. 사용자가 "그대로 진행"을 고르면 ASK 여도 진행한다. 확인은 최대 2회, 그래도 확정되지 않으면 종료한다.
   - 1 → `ERROR` 를 한 줄로 알리고 종료한다.
   이후 모든 단계는 출력된 KEY=VALUE 블록(이하 "리뷰 컨텍스트")을 그대로 쓴다. 브랜치 이름이 아니라 SHA 로 읽는다.
2. 리뷰어 병렬 호출.
   한 메시지에서 Agent 도구를 동시에 호출한다. 각 프롬프트에 리뷰 컨텍스트와 `<refs>/finding-format.md` 절대 경로를 넣는다.
   - `code-review-lexical` — 항상
   - `code-review-platform` — 항상. PROFILE 이 `general` 이면 `<refs>/general-guide.md`, 아니면 `<refs>/platform-guide.md` 경로를 함께 넣는다
   - `code-review-advisor` — SIZE=LARGE 이거나 `--deep` 일 때만. 아니면 SKIPPED
3. 위치 검증.
   리뷰어 결과마다 `bash "<scripts>/verify-locations.sh" <SOURCE_SHA> <<'EOF'` heredoc 으로 검사해 INVALID 줄을 모은다.
4. chair 판정.
   `code-review-chair` 를 모드 `judge` 로 호출한다. 프롬프트에 리뷰 컨텍스트, 리뷰어 결과 전체, 3단계 결과, `<refs>/output-template.md` 경로를 넣는다.
   - REDO 가 없으면 `## 최종 리뷰` 아래 본문을 최종 md 로 받고 6단계로 간다.
   - REDO 가 있으면 5단계로 간다.
5. REDO 처리 (리뷰어별 최대 1회).
   REDO 받은 리뷰어만 `재실행 지시` 를 프롬프트에 더해 병렬로 다시 호출하고, 3단계 검증을 다시 한 뒤, chair 를 모드 `final` 로 호출한다 (final 은 REDO 를 낼 수 없다).
6. md 검사.
   최종 md 를 `<git-dir>/code-review/<source 의 / 를 - 로 바꾼 이름>-<SOURCE_SHA 앞 7자리>.md` 에 Write 로 저장한다 (`<git-dir>` = `git rev-parse --absolute-git-dir`, 추적되지 않는 위치다).
   `bash "<scripts>/lint-md.sh" <저장 경로>` 로 검사한다. FAIL 이면 FAIL 줄을 넣어 chair 를 모드 `final` 로 한 번 더 호출해 고친 md 로 덮어쓴다. 그래도 FAIL 이면 경고를 붙여 그대로 낸다.
7. 출력.
   아래 순서로만 출력한다. md 를 렌더링된 형태로 다시 쓰지 않는다.
   1. `SUMMARY` 한 줄
   2. 백틱 4개 펜스(````markdown … ````) 안에 최종 md 원문
   3. 저장 경로 한 줄
   4. 클립보드 복사 명령 한 줄: `Get-Content -Raw -Encoding UTF8 "<저장 경로>" | Set-Clipboard`
   REDO 후에도 미검증 관점이 남았거나 lint 가 FAIL 이면 "자동 검토 한계 도달 — 수동 검토 권장" 을 마지막 줄에 덧붙인다.

## 호출 상한
리뷰어 각 최대 2회, chair 최대 3회 (judge 1 + final 1 + lint 재작성 1). 보통은 리뷰어 2~3회 + chair 1회로 끝난다.
