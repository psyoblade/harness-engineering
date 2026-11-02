#!/usr/bin/env bash
# 스테이지된 변경 규모 판정.
# 첫 줄: SMALL (파일 3개 이하 + 변경 100줄 이하) | LARGE. 둘째 줄: 실제 수치.

MAX_FILES=3
MAX_LINES=100

read -r files lines < <(git diff --cached --numstat | awk '
  { f++; if ($1 ~ /^[0-9]+$/) l += $1; if ($2 ~ /^[0-9]+$/) l += $2 }
  END { print f + 0, l + 0 }')

if (( files <= MAX_FILES && lines <= MAX_LINES )); then
  echo "SMALL"
else
  echo "LARGE"
fi
echo "files=$files lines=$lines"
