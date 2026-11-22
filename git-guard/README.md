# git-guard

서브에이전트가 정해진 git 명령(commit, push 등)을 실행하지 못하게 막는 훅.
막을 명령은 각 에이전트 정의에 적고, 이 훅이 그 규칙을 집행한다. code-review, commit-message 에이전트가 이 훅을 전제로 한다.

## 설치

저장소 루트에서 실행한다 (PowerShell 기준. cmd 에서는 `./` 없이 실행한다).

```powershell
./install-claude-hook.bat git-guard
```

- `~/.claude/hooks/git-guard.sh` 를 복사하고 `~/.claude/settings.json` 의 `PreToolUse`(matcher `Bash`)에 등록한다.
- Claude Code 를 재시작하면 반영된다.
- 설치하지 않으면 에이전트 정의의 `denyGit` 은 아무 효과가 없다.

## 규칙 쓰는 법

에이전트 정의(`.claude/agents/<이름>.md`)의 frontmatter 에 막을 git 하위 명령을 쉼표로 적는다.

```
---
name: code-review-lexical
tools: Read, Grep, Glob, Bash
denyGit: commit, push, merge, rebase, reset, checkout, switch, stash
---
```

- Claude Code 는 모르는 frontmatter 필드를 무시하므로 `denyGit` 은 이 훅만 읽는다.
- 정의 파일은 프로젝트의 `.claude/agents/` 를 먼저 보고, 없으면 `~/.claude/agents/` 를 본다.

## 동작

- 훅 입력의 `agent_type` 이 없으면(메인 세션의 호출) 바로 통과한다. 사용자와 메인 세션의 git 명령은 막지 않는다.
- `agent_type` 으로 정의 파일을 찾아 `denyGit` 을 읽는다. 정의가 없거나 `denyGit` 이 없으면 통과한다.
- 명령을 `&&`, `||`, `;`, `|`, 괄호, 백틱, 줄바꿈으로 나눠 조각마다 git 하위 명령을 찾는다. `git -C <경로>`, `git -c <키=값>` 같은 전역 옵션과 앞쪽 `VAR=값` 은 건너뛴다.
- 막을 명령이면 exit 2 로 차단하고, 이유를 에이전트에게 알린다.

## 이렇게 만든 이유

- `settings.json` 의 `permissions.deny` 는 세션 전체에 적용된다. 전역에 넣으면 사용자 본인과 다른 프로젝트의 커밋·푸시까지 막힌다.
- 에이전트 frontmatter 의 `disallowedTools` 는 `Bash(git push *)` 처럼 명령을 지정해도 Bash 도구 전체를 뺀다. 리뷰 에이전트는 `git diff`, `git show` 를 써야 해서 쓸 수 없다.
- 에이전트 frontmatter 의 `hooks` 는 문서에 있지만 Claude Code 2.1.316(Windows)에서 실행되지 않았다. 동작하는 버전이 되면 이 훅 대신 그쪽으로 옮길 수 있다.

## 한계

- 문자열 분석이라 `bash -c "git commit"`, `eval`, 변수에 담은 명령처럼 감싼 형태는 잡지 못한다. 실수로 실행하는 것을 막는 장치이지 보안 경계가 아니다.
- 모든 세션의 Bash 호출마다 실행된다. 메인 세션 호출은 첫 검사에서 바로 끝난다.
- Windows 에서는 Claude Code 가 훅을 Git Bash 로 실행한다. jq, python 은 쓰지 않는다.

## 제거

- `settings.json` 의 `PreToolUse` 에서 `git-guard.sh` 항목을 지우고 `~/.claude/hooks/git-guard.sh` 를 지운다.
