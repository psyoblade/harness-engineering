# code-review
4인 팀(lexical, platform, advisor, chair)으로 PR 을 리뷰하는 하네스 프로젝트

## 규칙
- 리뷰 대상은 resolve-target.sh 가 SHA 로 고정한다. 에이전트는 브랜치 이름이 아니라 SHA 로 코드를 읽는다.
- 에이전트는 읽기 전용이다. 결과는 파일이 아니라 최종 응답으로 넘긴다.
- 에이전트는 `.claude/agents/` 에 `code-review-<기능>.md` 로, 스킬은 `.claude/skills/` 에 정의한다.
- 스크립트(`*.sh`)는 LF, 나머지 파일은 CRLF.
