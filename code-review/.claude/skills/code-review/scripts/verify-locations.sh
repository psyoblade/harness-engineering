#!/usr/bin/env bash
# 리뷰 결과(stdin)의 [파일:라인] 위치가 source 버전에 실제로 있는지, 신규 지적이 변경 범위에 닿는지 검사한다.
# 사용법: verify-locations.sh <source-sha> [merge-base] < findings.md
#         stdin 은 리뷰어 결과 전문이어도 되고, 지적의 `위치:` `도달 경로:` `구분:` 줄만 모은 것이어도 된다.
#         merge-base 를 주면 `구분: 신규` 지적의 위치·도달 경로가 변경 범위(±MARGIN 줄)에 닿는지도 검사한다.
# 출력:   INVALID: / MISMATCH: 줄 + 마지막 줄 RESULT: PASS|FAIL (checked=N invalid=M mismatch=K)
set -u
sha=${1:?source-sha 필요}
base=${2:-}
MARGIN=3
LOC_RE='\[[^][:space:]]+:[0-9]+(-[0-9]+)?\]'
checked=0; invalid=0; mismatch=0
input=$(cat)

while read -r loc; do
  [ -z "$loc" ] && continue
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
done < <(grep -oE "$LOC_RE" <<<"$input" | sort -u)

if [ -n "$base" ]; then
  # 변경 범위: "경로<TAB>시작<TAB>끝" (source 버전 줄 번호). 삭제만 있는 hunk 는 삭제 지점 앞뒤 줄로 본다.
  ranges=$(git -c core.quotepath=false diff -U0 --no-color "$base" "$sha" | awk '
    /^\+\+\+ / { p = $0; sub(/^\+\+\+ (b\/)?/, "", p); sub(/\t.*$/, "", p); next }
    /^@@ /     { split($3, a, ","); s = substr(a[1], 2) + 0; n = (a[2] == "" ? 1 : a[2] + 0)
                 if (n == 0) { e = s + 1; if (s < 1) s = 1 } else e = s + n - 1
                 print p "\t" s "\t" e }')
  touches() {  # $1=[경로:범위] → 변경 범위에 닿으면 0
    local inner=${1#[}; inner=${inner%]}
    local range=${inner##*:}
    awk -F'\t' -v p="${inner%:*}" -v s="${range%-*}" -v e="${range#*-}" -v m="$MARGIN" \
      '$1 == p && s <= $3 + m && e >= $2 - m { f = 1 } END { exit !f }' <<<"$ranges"
  }
  flush() {  # 지적 하나를 판정한다
    [ "$kind" = 신규 ] && [ -n "$locs" ] || return 0
    local l
    for l in $locs $reach; do touches "$l" && return 0; done
    echo "MISMATCH: ${locs% } 신규인데 위치·도달 경로가 변경 범위 밖"; mismatch=$((mismatch + 1))
  }
  locs=""; reach=""; kind=""
  while IFS= read -r line; do
    case $line in
      *"위치:"*)      flush; locs=$(grep -oE "$LOC_RE" <<<"$line" | tr '\n' ' '); reach=""; kind="" ;;
      *"도달 경로:"*) reach=$(grep -oE "$LOC_RE" <<<"$line" | tr '\n' ' ') ;;
      *"구분:"*)      case $line in *신규*) kind=신규 ;; *) kind=기존 ;; esac ;;
    esac
  done <<<"$input"
  flush
fi

if [ "$invalid" -eq 0 ] && [ "$mismatch" -eq 0 ]; then res=PASS; else res=FAIL; fi
echo "RESULT: $res (checked=$checked invalid=$invalid mismatch=$mismatch)"
