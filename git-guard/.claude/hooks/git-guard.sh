#!/usr/bin/env bash
# Claude Code PreToolUse(Bash) 훅: 서브에이전트가 정의 파일의 denyGit 에 적힌 git 하위 명령을 실행하지 못하게 막는다.
# 에이전트 정의(.claude/agents/<이름>.md) frontmatter 예: denyGit: commit, push
# 메인 세션의 호출(agent_type 없음)과 denyGit 이 없는 에이전트는 그대로 통과한다.
input=$(cat)

agent=$(grep -oE '"agent_type": *"[^"]+"' <<<"$input" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')
[ -z "$agent" ] && exit 0
case $agent in */* | *..* | *:*) exit 0 ;; esac

def=""
for d in "${CLAUDE_PROJECT_DIR:-.}/.claude/agents" "$HOME/.claude/agents"; do
  [ -f "$d/$agent.md" ] && { def="$d/$agent.md"; break; }
done
[ -z "$def" ] && exit 0
deny=$(awk 'NR == 1 && !/^---/ { exit } NR > 1 && /^---/ { exit }
            /^denyGit:/ { sub(/^denyGit:[ \t]*/, ""); gsub(/[",]/, " "); print; exit }' "$def" | tr -d '\r')
[ -z "$deny" ] && exit 0

# tool_input.command 를 꺼내 JSON 이스케이프를 푼다
cmd=$(grep -oE '"command": *"(\\.|[^"\\])*"' <<<"$input" | head -1 | sed -E 's/^"command": *"//; s/"$//')
cmd=$(printf '%s' "$cmd" | sed -e 's/\\n/\n/g' -e 's/\\t/ /g' -e 's/\\"/"/g' -e 's/\\\\/\\/g')

# 명령을 &&, ||, ;, |, 괄호, 백틱, 줄바꿈으로 나눠 조각마다 git 하위 명령을 찾는다
while IFS= read -r seg; do
  read -ra w <<<"$seg"
  i=0
  while [ $i -lt ${#w[@]} ] && [[ ${w[$i]} == *=* && ${w[$i]} != -* ]]; do i=$((i + 1)); done  # 앞쪽 VAR=값
  case ${w[$i]:-} in git | */git | git.exe | */git.exe) ;; *) continue ;; esac
  i=$((i + 1))
  while [ $i -lt ${#w[@]} ]; do
    case ${w[$i]} in
      -C | -c | --git-dir | --work-tree | --namespace | --exec-path | --config-env) i=$((i + 2)) ;;
      -*) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  sub=${w[$i]:-}
  for x in $deny; do
    if [ "$sub" = "$x" ]; then
      echo "[git-guard] $agent 에이전트는 git $sub 를 실행할 수 없습니다 (정의 파일의 denyGit)." >&2
      exit 2
    fi
  done
done < <(printf '%s\n' "$cmd" | sed -E 's/(&&|\|\||[;|()`]|\$\()/\n/g')
exit 0
