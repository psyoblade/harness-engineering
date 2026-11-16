#!/usr/bin/env bash
# 스테이지된 변경의 규모를 판정하고, author·reviewer 가 읽을 컨텍스트 파일을 만든다.
# 첫 줄: EMPTY (스테이지된 변경 없음) | SMALL | LARGE. 둘째 줄: 실제 수치. 셋째 줄: CONTEXT=<컨텍스트 파일 경로>.
# SMALL 은 author 가 diff 전체를 읽는 규모다 — 컨텍스트 파일에 diff 전문을 넣는다.
# LARGE 는 변경 파일 목록만 넣는다 — author 가 필요한 파일만 읽으므로 reviewer 가 사실 일치를 검증한다.

MAX_FILES=20
MAX_LINES=300

if git diff --cached --quiet; then
  echo "EMPTY"
  exit 0
fi

read -r files lines < <(git diff --cached --numstat | awk '
  { f++; if ($1 ~ /^[0-9]+$/) l += $1; if ($2 ~ /^[0-9]+$/) l += $2 }
  END { print f + 0, l + 0 }')

if (( files <= MAX_FILES && lines <= MAX_LINES )); then size=SMALL; else size=LARGE; fi

dir="$(git rev-parse --absolute-git-dir)/commit-message"
mkdir -p "$dir"
ctx="$dir/context.txt"
{
  echo "규모: $size (files=$files lines=$lines)"
  echo
  echo "## 변경 파일 (git diff --cached --stat)"
  git -c core.quotepath=false diff --cached --stat
  echo
  echo "## 최근 커밋 (scope 이름 참고용)"
  git log -10 --oneline 2>/dev/null
  echo
  if [ "$size" = SMALL ]; then
    echo "## diff 전문 (git diff --cached)"
    git -c core.quotepath=false diff --cached
  else
    echo "## diff 생략"
    echo "변경이 커서 넣지 않았다. 필요한 파일만 \`git diff --cached -- <파일>\` 로 확인한다."
  fi
} > "$ctx"

echo "$size"
echo "files=$files lines=$lines"
echo "CONTEXT=$ctx"
