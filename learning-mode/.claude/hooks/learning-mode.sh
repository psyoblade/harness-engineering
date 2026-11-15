#!/usr/bin/env bash
# Claude Code UserPromptSubmit 훅: 학습 모드 토글 + 켜져 있으면 지침 주입
# 프롬프트가 "학습 모드 온/오프"로 시작할 때만 토글한다 (띄어쓰기 생략 허용)
FLAG="$HOME/.claude/learning-mode.on"
RULES="$(dirname "$0")/learning-mode.md"

input=$(cat)

if grep -Eq '"prompt": *"학습 ?모드 ?온' <<<"$input"; then
  touch "$FLAG"
  echo "[학습 모드가 ON으로 전환되었다. 사용자에게 전환되었음을 한 줄로 알려라.]"
elif grep -Eq '"prompt": *"학습 ?모드 ?오프' <<<"$input"; then
  rm -f "$FLAG"
  echo "[학습 모드가 OFF로 전환되었다. 사용자에게 알리고, 이후로는 학습 모드 지침을 따르지 말고 일반 모드로 응답하라.]"
  exit 0
fi

if [ -f "$FLAG" ]; then
  cat "$RULES"
fi
exit 0
