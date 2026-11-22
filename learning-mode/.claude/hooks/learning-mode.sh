#!/usr/bin/env bash
# Claude Code 훅: 학습 모드 토글 + 켜져 있으면 지침 주입
# UserPromptSubmit: 프롬프트가 "학습 모드 온/오프"로 시작할 때만 토글한다 (띄어쓰기 생략 허용).
#   지침 전문은 세션마다 한 번만 넣고, 그 뒤로는 한 줄 리마인더만 넣는다.
# SessionStart(compact|clear): 앞서 넣은 지침이 컨텍스트에서 사라졌으므로 다음 프롬프트에 전문을 다시 넣게 한다.
# FLAG 파일이 있으면 ON 이다. 내용은 지침 전문을 이미 받은 세션 id 목록이다 (한 줄에 하나).
FLAG="$HOME/.claude/learning-mode.on"
RULES="$(dirname "$0")/learning-mode.md"
END='("|[[:space:].!]|\\)'  # 토글 문구 뒤에 올 수 있는 것: 프롬프트 끝, 공백, 문장부호, 줄바꿈(\n)

input=$(cat)
sid=$(grep -oE '"session_id": *"[^"]+"' <<<"$input" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')

if grep -Eq '"hook_event_name": *"SessionStart"' <<<"$input"; then
  if [ -f "$FLAG" ] && [ -n "$sid" ]; then
    rest=$(grep -vxF "$sid" "$FLAG")
    printf '%s\n' "$rest" > "$FLAG"
  fi
  exit 0
fi

if grep -Eq "\"prompt\": *\"학습 ?모드 ?온$END" <<<"$input"; then
  : > "$FLAG"
  echo "[학습 모드가 ON으로 전환되었다. 사용자에게 전환되었음을 한 줄로 알려라.]"
elif grep -Eq "\"prompt\": *\"학습 ?모드 ?오프$END" <<<"$input"; then
  rm -f "$FLAG"
  echo "[학습 모드가 OFF로 전환되었다. 사용자에게 알리고, 이후로는 학습 모드 지침을 따르지 말고 일반 모드로 응답하라.]"
  exit 0
fi

[ -f "$FLAG" ] || exit 0
# 슬래시 명령(스킬 실행)에는 주입하지 않는다
grep -Eq '"prompt": *"/' <<<"$input" && exit 0

if [ -n "$sid" ] && grep -qxF "$sid" "$FLAG"; then
  echo "[학습 모드 ON — 이 세션 앞에서 받은 '학습 모드 (ON)' 지침을 계속 따른다.]"
else
  cat "$RULES"
  [ -n "$sid" ] && echo "$sid" >> "$FLAG"
fi
exit 0
