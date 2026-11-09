#!/usr/bin/env bash
# 리뷰 결과(stdin)의 [파일:라인] 위치가 source 버전에 실제로 있는지 검사한다.
# 사용법: verify-locations.sh <source-sha> < findings.md
# 출력:   INVALID: 줄 + 마지막 줄 RESULT: PASS|FAIL (checked=N invalid=M)
set -u
sha=${1:?source-sha 필요}
checked=0; invalid=0

while read -r loc; do
  inner=${loc#[}; inner=${inner%]}
  path=${inner%:*}; range=${inner##*:}
  start=${range%-*}; end=${range#*-}
  checked=$((checked + 1))
  if ! git cat-file -e "$sha:$path" 2>/dev/null; then
    echo "INVALID: $loc 파일 없음"; invalid=$((invalid + 1)); continue
  fi
  lines=$(git show "$sha:$path" | wc -l)
  if [ "$start" -lt 1 ] || [ "$end" -gt "$lines" ] || [ "$start" -gt "$end" ]; then
    echo "INVALID: $loc 라인 범위 밖 (파일 $lines줄)"; invalid=$((invalid + 1))
  fi
done < <(grep -oE '\[[^][:space:]]+:[0-9]+(-[0-9]+)?\]' | sort -u)

if [ "$invalid" -eq 0 ]; then echo "RESULT: PASS (checked=$checked invalid=0)"; else echo "RESULT: FAIL (checked=$checked invalid=$invalid)"; fi
