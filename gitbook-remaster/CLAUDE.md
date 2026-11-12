# gitbook-remaster
GitBook 실습서를 멀티 에이전트 오케스트레이터로 리뷰·검증·수정하여 리마스터하는 하네스 프로젝트

## 대상
- `~/git/psyoblade/oneday/` 아래 6권 (docker, git, hadoop, linux, mysql, python). 현황은 `docs/book-inventory.md`
- 파일럿 책: `git-for-oneday` — 온라인 https://psyoblade.gitbook.io/git-for-oneday

## 규칙
- 에이전트는 `.claude/agents/`, 스킬은 `.claude/skills/` 에 정의한다.
- 중간 산출물은 `_workspace/` 에 둔다.
- 원본 책의 작성 규칙(`docs/style-guide.md`)을 따른다. 새 문법을 도입하지 않는다.
- 수정 방향은 저자 결정(`docs/remaster-policy.md`)을 따른다. 정책에 없는 판단은 `확인 필요` 로 남긴다.
- `_workspace/` 는 git 에 포함하지 않는다 (루트 `.gitignore`).
- 원본 책 레포에는 `review/YYYYMMDD` 브랜치와 PR 까지만 만든다. merge 는 사람이 한다.
- 줄바꿈은 LF 로 통일한다 (루트 `.gitattributes` 로 강제, `*.bat` 만 CRLF).
- 진행 단계와 상태는 `PROCESS.md` 에 기록한다.
