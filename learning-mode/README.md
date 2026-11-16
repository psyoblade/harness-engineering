# learning-mode

AI 를 쓰면서도 학습 능력을 잃지 않도록, Claude 가 답 대신 질문과 힌트로 이끌게 하는 모드.
"학습 모드 온" / "학습 모드 오프" 로 켜고 끈다.

## 설치

```
install-claude-hook.bat learning-mode
```

- `~/.claude/hooks/` 에 `learning-mode.sh`, `learning-mode.md` 를 복사한다.
- `~/.claude/settings.json` 의 `UserPromptSubmit`, `SessionStart` 에 훅을 추가한다. 기존 훅은 유지되고, 이미 등록돼 있으면 건너뛴다. 변경이 있을 때만 원본을 `settings.json.bak` 으로 백업하고 저장한다.
- Claude Code 를 재시작하면 반영된다. `/hooks` 에서 등록 여부를 확인할 수 있다.

## 사용법

| 입력 | 동작 |
|---|---|
| `학습 모드 온` | 켠다. 세션마다 첫 프롬프트에 `learning-mode.md` 지침 전문이, 그 뒤로는 한 줄 리마인더가 주입된다 |
| `학습 모드 오프` | 끈다 |

- 프롬프트가 이 문구로 **시작**할 때만 토글된다. 문장 중간에 나오는 건 무시한다.
- 문구 뒤에는 공백, 줄바꿈, 문장부호만 올 수 있다 (`학습 모드 온전히 이해하고 싶어` 는 토글하지 않는다).
- 띄어쓰기는 생략해도 된다 (`학습모드온`).
- 상태는 `~/.claude/learning-mode.on` 파일 유무로 저장된다. 전역 상태라 모든 프로젝트와 세션이 공유한다. 파일 안에는 지침 전문을 이미 받은 세션 id 가 기록된다.
- 대화가 압축(compact)되거나 `/clear` 되면 다음 프롬프트에 전문을 다시 넣는다.
- `/` 로 시작하는 프롬프트(슬래시 명령)에는 주입하지 않는다. 스킬 실행이 학습 모드 지침의 영향을 받지 않게 하기 위해서다.
- 지침을 바꾸려면 `~/.claude/hooks/learning-mode.md` 를 고치면 된다. 새 세션부터 반영되고, 쓰던 세션에는 `학습 모드 온` 을 다시 입력하면 반영된다.

## 상태 표시 (statusLine, 수동 설정)

설치기는 statusLine 을 건드리지 않는다. statusLine 은 하나만 지정할 수 있어서 사용자마다 설정이 다르기 때문이다.
켜져 있을 때 상태줄 맨 위에 `📚 학습 모드 ON` 을 띄우려면 아래 래퍼를 `~/.claude/statusline-learning-mode.sh` 로 저장한다.

```bash
#!/usr/bin/env bash
# statusLine 래퍼: 학습 모드가 켜져 있으면 표시하고, 기존 statusLine 출력을 이어 붙인다
input=$(cat)
[ -f "$HOME/.claude/learning-mode.on" ] && printf '\033[1;33m📚 학습 모드 ON\033[0m\n'
printf '%s' "$input" | D:/claude/claude-buddy/statusline/buddy-status.sh
```

- 마지막 줄은 **원래 쓰던 statusLine 명령**으로 바꾼다. 기존 statusLine 이 없으면 마지막 줄을 지운다.
- 그다음 `settings.json` 의 `statusLine.command` 를 래퍼 경로로 바꾼다.

```json
"statusLine": {
  "type": "command",
  "command": "C:/Users/<사용자>/.claude/statusline-learning-mode.sh",
  "refreshInterval": 1
}
```

- 기존 statusLine 스크립트를 직접 고치지 않는 이유: 외부 플러그인(예: claude-buddy)이면 업데이트 때 수정이 사라지고, 스크립트가 중간에 종료하면 표시도 같이 사라진다.
- `refreshInterval` 이 없으면 다음 상태줄 갱신 때(보통 다음 메시지 이후) 반영된다.

## 제거

- `settings.json` 의 `UserPromptSubmit`, `SessionStart` 에서 `learning-mode.sh` 항목을 지운다. statusLine 을 바꿨다면 원래 명령으로 되돌린다.
- `~/.claude/hooks/learning-mode.*`, `~/.claude/learning-mode.on`, `~/.claude/statusline-learning-mode.sh` 를 지운다.

## 참고

- Windows 에서는 Claude Code 가 훅을 Git Bash 로 실행한다. WSL 의 Claude Code 에는 따로 설치해야 한다.
- VS Code 확장에서는 `UserPromptSubmit` 훅의 컨텍스트가 모델에 전달되지 않는다는 보고가 있다 ([#49063](https://github.com/anthropics/claude-code/issues/49063)). 지침이 반영되지 않으면 CLI 에서 확인한다.
