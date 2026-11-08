#!/usr/bin/env bash
# 최종 리뷰 md(stdin 또는 파일)가 Bitbucket 에 그대로 붙여 넣을 수 있는지 검사한다.
# 사용법: lint-md.sh [파일]
# 출력:   FAIL:/WARN: 줄 + 마지막 줄 RESULT: PASS|FAIL
set -u
md=$(cat "${1:-/dev/stdin}")
fail=0
f() { echo "FAIL: $*"; fail=1; }

# 1. 코드 펜스 짝
fences=$(printf '%s\n' "$md" | grep -cE '^ *```')
[ $((fences % 2)) -ne 0 ] && f "코드 펜스(\`\`\`) 개수가 홀수 ($fences)"

# 2. 백틱 4개 이상 금지 (출력 시 바깥 펜스로 쓴다)
printf '%s\n' "$md" | grep -qE '````' && f "백틱 4개 이상 사용 — 바깥 펜스와 충돌"

# 3. xml / yml 코드 블록 금지 (Bitbucket 에서 깨짐)
for n in $(printf '%s\n' "$md" | grep -nE '^ *```(xml|ya?ml)\b' | cut -d: -f1); do
  f "xml/yml 코드 블록 사용 (${n}행) — 백틱 없이 들여쓰기로 쓴다"
done

# 4. 필수 섹션
for s in "1. 목적" "2. 의도" "3. 변경 사항" "4. 검증 결과" "5. AI 사용 범위" "6. 리뷰 기한" \
         "7. 이번 변경으로 발생할 수 있는 치명적 오류" "8. 기존에 존재하던 심각한 오류" \
         "9. 개선하면 좋은 항목 제안" "10. 설계 원칙 점검" "11. 작성자 확인 질문"; do
  printf '%s\n' "$md" | grep -qF "### $s" || f "섹션 누락: ### $s"
done

# 5. 표의 열 개수 일치 (연속된 | 줄을 한 표로 본다)
tbl=$(printf '%s\n' "$md" | awk '
  /^ *\|/ { line=$0; gsub(/\\\|/,"",line); n=gsub(/\|/,"|",line)
            if (cols && n!=cols) printf "FAIL: 표 열 개수 불일치 (%d행: %d, 기대 %d)\n", NR, n, cols
            if (!cols) cols=n; next }
  { cols=0 }')
[ -n "$tbl" ] && { echo "$tbl"; fail=1; }

# 6. 도구 부재 안내 문구 금지
printf '%s\n' "$md" | grep -nE '찾을 수 없|설치되어 있지 않|도구가 없|CLI 없음' | while read -r l; do echo "WARN: 도구 부재 안내로 보이는 문구 (${l%%:*}행)"; done

if [ "$fail" -eq 0 ]; then echo "RESULT: PASS"; else echo "RESULT: FAIL"; fi
