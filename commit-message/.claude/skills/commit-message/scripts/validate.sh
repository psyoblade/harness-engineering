#!/usr/bin/env bash
# 커밋 메시지 형식 검증. 메시지는 stdin 또는 첫 번째 인자(파일)로 받는다.
# 출력: "FAIL:" / "WARN:" 줄 + 마지막 줄 "RESULT: PASS|FAIL". FAIL이 하나라도 있으면 exit 1.

if [ -n "$1" ]; then msg=$(cat "$1"); else msg=$(cat); fi
msg=$(printf '%s' "$msg" | tr -d '\r')

fail=0
err()  { echo "FAIL: $1"; fail=1; }
warn() { echo "WARN: $1"; }

if [ -z "$msg" ]; then
  echo "FAIL: 메시지가 비어 있다"
  echo "RESULT: FAIL"
  exit 1
fi

header=${msg%%$'\n'*}
rest=""
[[ "$msg" == *$'\n'* ]] && rest=${msg#*$'\n'}

# 1. 제목 형식: type(scope): subject (scope 필수)
types='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'
re="^($types)\([[:lower:][:digit:]._/-]+\)!?: .+"
[[ "$header" =~ $re ]] || err "제목이 'type(scope): subject' 형식이 아니다 (type: ${types//|/, }; scope는 필수, 소문자·숫자·._/- 만 사용)"

# 2. 제목 길이 (문자 수; UTF-8 연속 바이트를 제외해 로케일과 무관하게 센다)
len=$(printf '%s' "$header" | LC_ALL=C tr -d '\200-\277' | wc -c)
if (( len > 72 )); then
  err "제목이 ${len}자로 72자를 넘는다"
elif (( len > 50 )); then
  warn "제목이 ${len}자로 50자를 넘는다 — 더 짧게 줄일 수 있는지 검토"
fi

# 3. 언어: subject에 한글 필수 (UTF-8 한글 음절의 선두 바이트 0xEA~0xED)
subject=${header#*: }
printf '%s' "$subject" | LC_ALL=C grep -q $'[\352-\355]' || err "subject에 한글이 없다 (커밋 메시지 언어는 한국어로 고정)"

# 4. 제목은 핵심 변경 하나만: 접속사·쉼표로 여러 변경을 잇지 않는다
[[ "$subject" == *" 및 "* ]] && err "제목에 '및'이 있다 — 핵심 변경 하나만 제목에 쓰고 나머지는 본문으로 옮긴다"
[[ "$subject" == *" & "* ]]  && err "제목에 '&'가 있다 — 핵심 변경 하나만 제목에 쓰고 나머지는 본문으로 옮긴다"
[[ "$subject" == *", "* ]]   && err "제목에 쉼표가 있다 — 핵심 변경 하나만 제목에 쓰고 나머지는 본문으로 옮긴다"

# 5. 본문: 제목 다음 빈 줄, 3줄 이내 (BREAKING CHANGE·Closes 등 footer는 제외)
if [ -n "$rest" ]; then
  second=${rest%%$'\n'*}
  [ -z "$second" ] || err "제목과 본문 사이에 빈 줄이 없다"
  body_lines=$(printf '%s\n' "$rest" | grep -v '^[[:space:]]*$' | grep -Ecv '^(BREAKING CHANGE:|Closes #|Fixes #|Refs #|Co-Authored-By:)')
  (( body_lines <= 3 )) || err "본문이 ${body_lines}줄로 3줄을 넘는다"
fi

if (( fail )); then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
