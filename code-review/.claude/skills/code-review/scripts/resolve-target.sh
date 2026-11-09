#!/usr/bin/env bash
# 리뷰 대상(source → target)을 SHA로 고정하고 프로파일을 판정한다.
# 사용법: resolve-target.sh [source] [target]
# 출력:   KEY=VALUE 줄 (stdout). ASK 사유는 ASK= 줄, 후보는 CANDIDATE= 줄로 여러 개 나올 수 있다.
# 종료:   0 = OK(바로 진행), 2 = ASK(사용자 확인 필요), 1 = ERROR
set -u

# ---- 설정 ----------------------------------------------------------------
MAX_FILES_SMALL=5          # 이하이면 SIZE=SMALL (advisor 생략 기준)
MAX_LINES_SMALL=200
MAX_COMMITS_SANE=50        # 초과하면 target 오지정 의심 → ASK
MAX_FILES_SANE=100
PLATFORM_DEP_RE='bigbrother-(flow|common)'                         # gradle 의존성 표지
SHARED_LIB_NAME_RE="rootProject\.name *= *['\"]bigbrother-(flow|common)"  # 공유 라이브러리 자신
PY_FLOW_PKG_RE='flow-client-python'   # Python flow 클라이언트 패키지 (setup.py name, requirements)
SPARK_RE='org\.apache\.spark|spark-(core|sql|streaming)|pyspark'
# bash(build.sh) 프로젝트는 항상 general (플랫폼 표지 방식 미정)
# --------------------------------------------------------------------------

ask=()
cands=()
out() { printf '%s=%s\n' "$1" "$2"; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { out STATUS ERROR; out ERROR "git 저장소가 아님"; exit 1; }

if ! git fetch origin --prune --quiet 2>/dev/null; then
  out WARN "git fetch 실패 — 로컬에 있는 origin 참조 기준으로 판정"
fi

# 기본 브랜치: origin/HEAD → master → main
default=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
if [ -z "$default" ]; then
  for b in master main; do
    git show-ref --verify --quiet "refs/remotes/origin/$b" && { default=$b; break; }
  done
fi

src=${1:-}; tgt=${2:-}
src=${src#origin/}; tgt=${tgt#origin/}
if [ -z "$src" ]; then
  src=$(git branch --show-current)
  [ -n "$src" ] && ask+=("source 미지정 — 현재 브랜치 $src 로 추정")
fi
if [ -z "$tgt" ]; then
  tgt=$default
  [ -n "$tgt" ] && ask+=("target 미지정 — 기본 브랜치 $tgt 로 추정")
fi
[ -z "$src" ] && { out STATUS ERROR; out ERROR "source 를 정할 수 없음 (detached HEAD)"; exit 1; }
[ -z "$tgt" ] && { out STATUS ERROR; out ERROR "target 을 정할 수 없음 (기본 브랜치 미확인)"; exit 1; }

# 브랜치 → 참조. 원격 우선, 로컬만 있으면 경고
resolve_ref() {  # $1=이름 $2=역할  → 전역 ref 설정
  local name=$1 role=$2 r l
  r=$(git rev-parse --verify --quiet "refs/remotes/origin/$name^{commit}")
  l=$(git rev-parse --verify --quiet "refs/heads/$name^{commit}")
  if [ -n "$r" ]; then
    ref="origin/$name"
    if [ -n "$l" ] && [ "$l" != "$r" ]; then
      local ahead behind
      ahead=$(git rev-list --count "$r..$l"); behind=$(git rev-list --count "$l..$r")
      ask+=("$role $name: 로컬과 origin 이 다름 (로컬 ahead $ahead, behind $behind) — origin 기준으로 리뷰")
    fi
  elif [ -n "$l" ]; then
    ref="$name"
    ask+=("$role $name: origin 에 없음 (푸시 전) — 로컬 브랜치 기준으로 리뷰")
  else
    ref=""
    ask+=("$role $name: 브랜치를 찾을 수 없음")
    while read -r c; do [ -n "$c" ] && cands+=("$role:$c"); done < <(
      git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin |
        sed 's#^origin/##' | grep -v '^HEAD$' | sort -u | grep -iF "${name##*/}" | head -5)
    [ "$role" = target ] && [ -n "$default" ] && cands+=("target:$default")
  fi
}

resolve_ref "$src" source; src_ref=$ref
resolve_ref "$tgt" target; tgt_ref=$ref

out SOURCE "$src"; out TARGET "$tgt"; out DEFAULT_BRANCH "${default:-unknown}"

if [ -z "$src_ref" ] || [ -z "$tgt_ref" ]; then
  out STATUS ASK
  for a in "${ask[@]}"; do out ASK "$a"; done
  for c in "${cands[@]}"; do out CANDIDATE "$c"; done
  exit 2
fi

src_sha=$(git rev-parse "$src_ref^{commit}"); tgt_sha=$(git rev-parse "$tgt_ref^{commit}")
base=$(git merge-base "$tgt_sha" "$src_sha" 2>/dev/null)
[ -z "$base" ] && { out STATUS ERROR; out ERROR "merge-base 없음 (공통 이력 없음)"; exit 1; }

[ "$src" = "$tgt" ] && ask+=("source 와 target 이 같음")
[ "$base" = "$src_sha" ] && ask+=("source 가 이미 target 에 포함됨 — 리뷰할 변경 없음")
[ -n "$default" ] && [ "$tgt" != "$default" ] && ask+=("target 이 기본 브랜치($default)가 아님")

commits=$(git rev-list --count "$base..$src_sha")
read -r files added deleted < <(git diff --numstat "$base" "$src_sha" |
  awk '{f++; if($1!="-"){a+=$1; d+=$2}} END{printf "%d %d %d\n", f, a, d}')
[ "$commits" -gt "$MAX_COMMITS_SANE" ] && ask+=("커밋 $commits 개 — target 오지정 의심")
[ "$files" -gt "$MAX_FILES_SANE" ] && ask+=("변경 파일 $files 개 — target 오지정 의심")
if [ "$files" -le "$MAX_FILES_SMALL" ] && [ $((added + deleted)) -le "$MAX_LINES_SMALL" ]; then size=SMALL; else size=LARGE; fi

# ---- 프로파일 판정 (source 버전 트리 기준) ----------------------------------
tree_files() { git ls-tree -r --name-only "$1"; }
gradle_files() { tree_files "$1" | grep -E '(^|/)(build|settings)\.gradle(\.kts)?$|(^|/)libs\.versions\.toml$|^buildSrc/'; }
py_files()     { tree_files "$1" | grep -E '(^|/)setup\.py$|(^|/)requirements[^/]*\.txt$|(^|/)pyproject\.toml$'; }
first_hit() {  # $1=sha $2=regex $3..=파일  → "파일:줄 내용"
  local sha=$1 re=$2; shift 2
  [ $# -eq 0 ] && return 1
  git grep -n -E "$re" "$sha" -- "$@" 2>/dev/null | head -1 | sed "s#^$sha:##"
}
detect() {  # $1=sha → "프로파일|근거|빌드도구"
  local sha=$1 builds="" hit g p
  mapfile -t g < <(gradle_files "$sha"); mapfile -t p < <(py_files "$sha")
  [ ${#g[@]} -gt 0 ] && builds+="gradle,"
  [ ${#p[@]} -gt 0 ] && builds+="python,"
  tree_files "$sha" | grep -qE '(^|/)build\.sh$' && builds+="bash,"
  builds=${builds%,}
  if hit=$(first_hit "$sha" "$SHARED_LIB_NAME_RE" "${g[@]}") && [ -n "$hit" ]; then echo "shared-lib|$hit|$builds"; return; fi
  if hit=$(first_hit "$sha" "^ *name *= *['\"][^'\"]*$PY_FLOW_PKG_RE" "${p[@]}") && [ -n "$hit" ]; then echo "shared-lib|$hit|$builds"; return; fi
  if hit=$(first_hit "$sha" "$PLATFORM_DEP_RE" "${g[@]}") && [ -n "$hit" ]; then echo "platform|$hit|$builds"; return; fi
  if hit=$(first_hit "$sha" "^[^#]*$PY_FLOW_PKG_RE" "${p[@]}") && [ -n "$hit" ]; then echo "platform|$hit|$builds"; return; fi
  if [ -n "$builds" ]; then echo "general|빌드 도구 $builds 에서 플랫폼 표지 없음|$builds"; else echo "general|빌드 도구 미감지|"; fi
}

IFS='|' read -r profile evidence builds < <(detect "$src_sha")
IFS='|' read -r base_profile _ _ < <(detect "$base")
note=""
[ "$profile" = platform ] && [ "$base_profile" = general ] && note="이 PR 로 플랫폼 의존성 추가(플랫폼 편입)"
[ "$profile" = general ] && [ "$base_profile" = platform ] && note="이 PR 로 플랫폼 의존성 제거"

spark=no
mapfile -t bf < <(gradle_files "$src_sha"; py_files "$src_sha")
[ ${#bf[@]} -gt 0 ] && git grep -q -E "$SPARK_RE" "$src_sha" -- "${bf[@]}" 2>/dev/null && spark=yes

claude_md=no
git cat-file -e "$src_sha:CLAUDE.md" 2>/dev/null && claude_md=yes

# 공유 라이브러리면 같은 상위 폴더의 다른 저장소 중 이 라이브러리를 쓰는 곳을 찾는다
dependents=""
if [ "$profile" = shared-lib ]; then
  lib=$(printf '%s' "$evidence" | grep -oE "bigbrother-[A-Za-z0-9-]+|[A-Za-z0-9_-]*$PY_FLOW_PKG_RE[A-Za-z0-9_-]*" | head -1)
  top=$(git rev-parse --show-toplevel)
  for d in "$(dirname "$top")"/*/; do
    [ "${d%/}" = "$top" ] && continue
    grep -rqsE --include='*.gradle' --include='*.gradle.kts' --include='*.toml' --include='setup.py' \
      --include='requirements*.txt' "$lib" "$d" 2>/dev/null && dependents+="$(basename "$d"),"
  done
  dependents=${dependents%,}
fi

# ---- 출력 ----------------------------------------------------------------
out SOURCE_REF "$src_ref"; out SOURCE_SHA "$src_sha"
out TARGET_REF "$tgt_ref"; out TARGET_SHA "$tgt_sha"
out MERGE_BASE "$base"
out COMMITS "$commits"; out FILES "$files"; out ADDED "$added"; out DELETED "$deleted"; out SIZE "$size"
out PROFILE "$profile"; out PROFILE_EVIDENCE "$evidence"; out BUILD "${builds:-none}"
[ -n "$note" ] && out PROFILE_NOTE "$note"
out SPARK "$spark"; out REPO_CLAUDE_MD "$claude_md"
[ -n "$dependents" ] && out DEPENDENTS "$dependents"
out SUMMARY "리뷰 대상: $src (${src_sha:0:7}) → $tgt (${tgt_sha:0:7}) | 커밋 $commits개, 파일 $files개 (+$added/-$deleted) | 프로파일: $profile"

if [ ${#ask[@]} -gt 0 ]; then
  out STATUS ASK
  for a in "${ask[@]}"; do out ASK "$a"; done
  exit 2
fi
out STATUS OK
exit 0
