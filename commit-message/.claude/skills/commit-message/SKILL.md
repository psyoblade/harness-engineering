---
name: commit-message
description: "스테이지된 변경을 바탕으로 Conventional Commits 형식의 커밋 메시지를 2인 팀(author·reviewer)으로 생성. '커밋 메시지', 'commit message', '커밋 메시지 만들어줘' 같은 자연어 요청 시 반드시 사용. 단, 이미 메시지가 작성된 `git commit -m` 대체는 아니다."
allowed-tools: Bash Agent
---

# Commit Message Skill
author가 초안을 쓰고, 검증 스크립트가 형식을 검사하며, 변경이 클 때만 reviewer가 사실 일치를 검증해 Conventional Commits 형식의 커밋 메시지를 생성한다. 메시지 제시까지만 하며 `git commit`·`git push`는 실행하지 않는다 (커밋은 사용자가 직접 한다).

## 스크립트
이 스킬 폴더의 `scripts/`에 있다. 스킬이 로드될 때 알려 주는 Base directory로 절대 경로를 만들어 쓰고, 이하 `<scripts>`로 표기한다.
- `diff-size.sh`. 스테이지된 변경 규모를 판정한다. 첫 줄이 `SMALL`(파일 3개 이하, 변경 100줄 이하) 또는 `LARGE`.
- `validate.sh`. 커밋 메시지(stdin)의 형식을 검사한다. 마지막 줄이 `RESULT: PASS` 또는 `RESULT: FAIL`이고, `WARN:` 줄은 경고다.

## Workflow
1. Precondition 체크.
   `git diff --cached --quiet` 를 실행한다.
   exit code 1(변경 있음)이면 통과, exit code 0(변경 없음)이면 "먼저 `git add`" 안내 후 종료.
2. 규모 판정.
   `bash "<scripts>/diff-size.sh"` 를 실행해 첫 줄(SMALL | LARGE)을 기억한다.
3. author 호출.
   `commit-message-author` 에이전트를 Agent 도구로 호출. 프롬프트에 `<scripts>/validate.sh` 의 절대 경로를 넣는다 (재호출이면 수정 지시도 함께).
   초안은 author의 최종 응답으로 받는다 (파일을 쓰지 않는다).
4. 형식 게이트.
   초안을 `bash "<scripts>/validate.sh" <<'EOF'` heredoc 으로 검사한다.
   - `RESULT: FAIL` 이면 `FAIL:` 사유를 수정 지시로 삼아 6단계로 간다.
   - `WARN:` 줄은 기억해 두었다가 마지막에 초안과 함께 사용자에게 보여 준다.
5. 판정 분기.
   - SMALL. reviewer를 생략하고 초안을 제시한 뒤 완료.
   - LARGE. `commit-message-reviewer` 에이전트를 Agent 도구로 호출 (프롬프트에 초안 전체를 포함하고, diff는 reviewer가 직접 읽는다).
     - PASS. 초안을 제시하고 완료.
     - REDO. 6단계로 간다.
6. REDO 처리.
   재작성 횟수가 1회 미만이면 수정 지시(게이트 FAIL 사유 또는 reviewer 수정 지시)를 프롬프트에 포함해 author를 재호출하고 4단계로 돌아간다.
7. 루프 종료.
   PASS이거나, 재작성 1회를 마친 뒤에도 REDO이면 종료 (author 호출은 최초 1회 + 재작성 최대 1회 = 총 2회, reviewer도 최대 2회).
   REDO인 채로 종료하면 "자동 승인 한계 도달 — 수동 검토 권장" 경고와 함께 마지막 초안 반환.
