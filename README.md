# harness-engineering
harness engineering tutorial

## 모듈 한눈에 보기

| 모듈 | 종류 | 구성 | 설치 | 사용 |
|---|---|---|---|---|
| [code-review](code-review/) | 스킬 + 에이전트 4 | lexical, platform, advisor, chair | `./install-claude-skill.bat code-review` | `/code-review <source> <target> [--deep]` |
| [commit-message](commit-message/) | 스킬 + 에이전트 2 | author, reviewer | `./install-claude-skill.bat commit-message` | `git add` 후 "커밋 메시지 만들어줘" |
| [gitbook-remaster](gitbook-remaster/) | 스킬 + 에이전트 4 | gitbook-linter, lab-verifier, learner-sim, reviser | 설치하지 않음 (폴더에서 실행) | `gitbook-remaster/` 에서 "git 책 리마스터 해줘" |
| [learning-mode](learning-mode/) | 훅 | UserPromptSubmit, SessionStart | `./install-claude-hook.bat learning-mode` | "학습 모드 온" / "학습 모드 오프" |
| [git-guard](git-guard/) | 훅 | PreToolUse(Bash) | `./install-claude-hook.bat git-guard` | 자동 (에이전트 정의의 `denyGit` 집행) |

## 설치

저장소 루트에서 실행한다. 모두 전역 `~/.claude/` 에 설치되고, Claude Code 를 재시작하면 반영된다.

### 설치 순서 (PowerShell)

PowerShell 은 현재 폴더의 실행 파일을 이름만으로 실행하지 않으므로 앞에 `./` 를 붙인다 (cmd 에서는 없어도 된다).

```powershell
cd D:\git\psyoblade\harness-engineering
./install-claude-hook.bat git-guard          # 1. 에이전트 git 명령 차단 훅 (스킬보다 먼저)
./install-claude-skill.bat code-review       # 2. PR 리뷰 스킬과 에이전트 4개
./install-claude-skill.bat commit-message    # 3. 커밋 메시지 스킬과 에이전트 2개
./install-claude-hook.bat learning-mode      # 4. 학습 모드 훅 (선택)
```

5. Claude Code 를 재시작한다. 훅 등록은 재시작해야 반영된다.
6. 확인: Claude Code 에서 `/hooks` 로 `PreToolUse`(git-guard), `UserPromptSubmit`·`SessionStart`(learning-mode) 등록을 본다.

gitbook-remaster 는 설치하지 않는다 (아래 사용법 참고).

### 설치기가 하는 일

- **git-guard 를 먼저 설치한다.** code-review, commit-message 에이전트는 git 상태를 바꾸는 명령(commit, push 등)을 실행하지 않도록 정의 파일에 `denyGit` 을 적어 두었고, 이 규칙은 git-guard 훅이 있어야 동작한다. 없으면 스킬 설치기가 안내를 출력한다.
- **`install-claude-skill.bat <모듈>`** 은 `<모듈>/.claude/agents/*.md` 를 `~/.claude/agents/` 에, `skills/` 아래(SKILL.md, scripts, references)를 `~/.claude/skills/` 에 복사한다. `settings.json` 은 건드리지 않는다.
- **`install-claude-hook.bat <모듈>`** 은 `<모듈>/.claude/hooks/` 를 `~/.claude/hooks/` 에 복사하고, `<모듈>/.claude/hooks.json` 의 등록 내용을 `~/.claude/settings.json` 에 병합한다 (`merge-claude-hooks.ps1`).
  - 다른 훅과 설정은 유지한다. 같은 명령이 이미 등록돼 있으면 새 내용으로 교체한다 (경로 표기가 달라도 같은 명령으로 본다).
  - 바뀐 것이 있을 때만 `settings.json.bak-<시각>` 으로 백업한다.
  - PowerShell 7(pwsh)을 권장한다. 없으면 Windows PowerShell 5.1 로 병합하는데, 내용은 같지만 settings.json 전체의 들여쓰기가 바뀐다.
- **업그레이드** 는 같은 명령으로 다시 설치하면 된다. 저장소에서 지운 파일(예: 이름을 바꾼 스크립트)은 설치 폴더에 남으니 필요하면 직접 지운다.

## 사용법

### code-review — PR 리뷰
```
/code-review feature/my-branch main
/code-review feature/my-branch main --deep
```
- 인자는 PR 화면의 순서대로 source(리뷰할 브랜치), target(머지될 브랜치)이다. 생략하면 현재 브랜치와 기본 브랜치로 추정하고 확인을 묻는다.
- 리뷰 대상을 SHA 로 고정한 뒤 lexical(런타임 오류·범위·테스트), platform(설계·보안)이 병렬로 리뷰하고, chair 가 판정해 최종 md 를 만든다. 변경이 크거나 `--deep` 이면 advisor(커밋 분리·장황한 코드·대안)도 돈다. 문서만 바뀐 PR 은 platform 을 생략한다.
- 결과는 `<git-dir>/code-review/<브랜치>-<SHA7>.md` 에 저장되고, 화면에 원문과 클립보드 복사 명령이 출력된다. PR 코멘트 게시·커밋·푸시는 하지 않는다.
- 모델이 스스로 부르지 않는다 (`/code-review` 로만 실행).

### commit-message — 커밋 메시지 생성
```
git add <파일>
```
그다음 Claude 에게 "커밋 메시지 만들어줘" (또는 `/commit-message`).
- author 가 Conventional Commits 형식(`type(scope): 한국어 제목`, 본문 3줄 이내) 초안을 쓰고, 형식 검사 스크립트가 통과시킨다. 변경이 크면 reviewer 가 diff 와 사실이 맞는지 확인한다.
- 메시지 제시까지만 한다. 커밋은 사용자가 한다.

### gitbook-remaster — GitBook 실습서 리마스터
```
cd gitbook-remaster
claude
```
그다음 "git 책 리마스터 해줘" (또는 `/gitbook-remaster git`).
- 전역에 설치하지 않고 이 폴더에서 실행한다. 폴더의 `.claude/settings.json` 이 에이전트 팀 실험 기능(env), 책 폴더 접근, 권한 규칙을 적용하고, `docs/` 의 스타일 가이드·리마스터 정책을 읽기 때문이다.
- 대상 책은 `~/git/psyoblade/oneday/<이름>` 이다. 실습 sandbox 실행(`lab_run.py`)은 Linux 또는 WSL 의 bash·git·python3 가 필요하다.
- 리뷰 → 수정 → 자동 검증 루프 뒤 사람의 승인을 받고, 원본 레포에 `review/YYYYMMDD` 브랜치와 PR 까지 만든다. merge 는 하지 않는다. 자세한 절차는 [PROCESS.md](gitbook-remaster/PROCESS.md), [stage6-runbook.md](gitbook-remaster/docs/stage6-runbook.md).

### learning-mode — 학습 모드
| 입력 | 동작 |
|---|---|
| `학습 모드 온` | 켠다. 개념·설계 질문에 바로 답하지 않고 가설을 묻고 단계별로 이해도를 확인한 뒤 답한다 |
| `학습 모드 오프` | 끈다 |

- 프롬프트가 이 문구로 시작할 때만 토글된다. 상태는 전역(`~/.claude/learning-mode.on`)이라 모든 세션이 공유한다.
- 실행 요청(커밋, 스킬 실행 등)과 `/` 로 시작하는 명령에는 적용하지 않는다.
- 상태줄 표시, 제거 방법은 [learning-mode/README.md](learning-mode/README.md).

### git-guard — 에이전트 git 명령 차단
- 설치만 하면 된다. 서브에이전트의 Bash 호출마다 정의 파일의 `denyGit` 을 확인해 해당 git 명령을 막는다. 메인 세션과 사용자 본인의 git 명령은 막지 않는다.
- 새 에이전트에 적용하려면 정의 frontmatter 에 한 줄을 추가한다.
  ```
  denyGit: commit, push
  ```
- 동작 방식과 한계는 [git-guard/README.md](git-guard/README.md).

## 회고

### commit-message
* 생각보다 느리고 REDO 비중이 높아서 활용도가 떨어질 것 같고, 커밋 메시지 작성에 REDO 2회로 총 3회가 토큰이 일반적인 케이스 보다 적게 쓰는지도 의심된다
* 프로젝트 별로 설치하기에는 너무 번거롭고, 글로벌로 하기는 부담되지만 요약 결과물이 생각보다 좋아서 속도와 REDO 만 조율하면 쓸만할 듯
* 커밋 메시지 특성상, 숙고하기 보다는 빠른 결과가 더 중요하기 때문에 v1.0 대신 v1.1 버전을 사용하기로 한다

### code-review
* 코드 리뷰가 많은 업무 특성상 아주 활용도가 높고, 기존 방식보다 안정적으로 잘 동작하고 있다
* 물론 기술적인 부분을 좀 덜 파고든다는 느낌은 있지만, 오히려 넓은 범위로 여러 관점에서 안정적인 출력을 뽑아내는 것이 더 좋은 것 같다
* 향후에 좀 더 분야별로 에이전트만 개선하면 된다는 생각이 더 좋은 방향이라 생각이 들었다
* 치명적 오류를 수정 제안하는 케이스가 '확률적으로 얼마나 자주 발생하는지' 혹은 '어떤 경우 문제가 될 수 있는지 재현 가능한 예시를 제시할 수 있는지'를 문의 하는 과정에서 Minor 로 떨어지는 경우도 있었다 

### learning-mode
* [앤드류 응 교수님의 AI가 코딩하면 개발자는 뭘할까?](https://youtu.be/2tEchomcjk4?si=aZgOuA-lcO84Fqtj) 영상을 보고 만들어본 기능
* "학습 모드 온/오프" 명령을 통해서 내가 개념을 어느 정도 설명할 수 있게 된 경우에만 답변을 하도록 글로벌 훅을 통해 대화를 하도록 만들었다
* 기존 코드 채팅의 경우 내가 대화를 주도한다는 생각이 들기에 내가 원하는 답변만 째깍 째깍 받았다면, 학습 모드에서는 최소한 원리와 한계(언제 쓰면 안 되는지)를 내 말로 설명할 수 있어야 답변을 준다
* AI와 대화하면서 내가 병목이 되는 경험을 하게되어 새로운 경험을 하게 되어 재미있었고 좀 더 정확하게 이해할 수 있는 시간을 가질 수 있었다