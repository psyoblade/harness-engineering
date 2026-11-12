#!/usr/bin/env python3
"""실습 코드 블록 추출과 sandbox 실행.

사용법:
  python3 lab_run.py extract <책 루트> [페이지 ...]
      페이지 순서(SUMMARY.md 순, 또는 지정 순)대로 코드 블록 목록을 출력한다.
      <파일>:<줄>\t<언어>\t<추정 유형>\t<첫 줄>
      추정 유형: cmd(실행 명령) | output(기대 출력) | file(파일 내용) — 참고용이며 최종 판단은 에이전트가 한다.

  python3 lab_run.py run <plan.sh> [--sandbox <디렉토리>]
      plan.sh 의 단계를 하나의 bash 세션에서 순서대로 실행한다 (상태 공유, 실패해도 계속).
      단계 구분: '#@ step <id> <출처 파일:줄>' 줄. 그 아래 줄들이 해당 단계 명령이다.
      sandbox: HOME, WORK_DIR 을 임시 디렉토리로 격리하고 GIT_CONFIG_NOSYSTEM=1, 편집기는 no-op.
      출력: 단계별 '=== step <id> (<출처>) rc=<n> err=<n>' 과 출력. 단계 안에서 실패한 명령은 '@@ERR rc=<n> : <명령>' 줄로 표시.
      마지막 줄 SUMMARY: steps=<n> failed=<n>  (rc != 0 이거나 err > 0 인 단계)
"""
import os
import re
import subprocess
import sys
import tempfile

FENCE_RE = re.compile(r'^\s*```(\S*)')
SUMMARY_RE = re.compile(r'\]\(([^)\s#]+\.md)')
STEP_RE = re.compile(r'^#@ step (\S+)\s*(.*)$')


def pages_in_order(root):
    with open(os.path.join(root, 'SUMMARY.md'), encoding='utf-8') as f:
        return SUMMARY_RE.findall(f.read())


def guess_kind(lang, body):
    first = next((l for l in body if l.strip()), '')
    if re.match(r'^\s*(\$ |\* [0-9a-f]{7}|\[\+\]|NAME\s|[a-z]+@[0-9a-f]+:)', first):
        return 'output'
    if lang in ('bash', 'sh', 'shell'):
        return 'cmd'
    return 'file' if lang == '' else 'cmd'


def extract(root, pages):
    for page in pages or pages_in_order(root):
        lang, start, body = None, 0, []
        with open(os.path.join(root, page), encoding='utf-8') as f:
            for no, line in enumerate(f, 1):
                m = FENCE_RE.match(line)
                if m and lang is None:
                    lang, start, body = m.group(1), no, []
                elif m:
                    first = next((l for l in body if l.strip()), '').strip()
                    print(f'{page}:{start}\t{lang or "-"}\t{guess_kind(lang, body)}\t{first[:60]}')
                    lang = None
                elif lang is not None:
                    body.append(line.rstrip('\r\n'))


def run(plan, sandbox):
    sandbox = sandbox or tempfile.mkdtemp(prefix='lab-')
    home, work = os.path.join(sandbox, 'home'), os.path.join(sandbox, 'work')
    os.makedirs(home, exist_ok=True)
    os.makedirs(work, exist_ok=True)

    steps, cur = [], None
    with open(plan, encoding='utf-8') as f:
        for line in f:
            m = STEP_RE.match(line.rstrip('\r\n'))
            if m:
                cur = [m.group(1), m.group(2), []]
                steps.append(cur)
            elif cur is not None:
                cur[2].append(line.rstrip('\r\n'))

    script = ['set +e', 'trap \'echo "@@ERR rc=$? : $BASH_COMMAND"\' ERR', f'cd "{work}"']
    for sid, src, cmds in steps:
        script.append(f'echo "@@STEP {sid}"')
        script.append('{\n' + '\n'.join(cmds or [':']) + '\n} 2>&1')
        script.append(f'echo "@@RC {sid} $?"')

    env = dict(os.environ, HOME=home, WORK_DIR=work, GIT_CONFIG_NOSYSTEM='1',
               GIT_TERMINAL_PROMPT='0', EDITOR='true', GIT_EDITOR='true',
               GIT_PAGER='cat', PAGER='cat', LANG='C.UTF-8', LC_ALL='C.UTF-8')
    proc = subprocess.run(['bash'], input='\n'.join(script) + '\n', text=True,
                          capture_output=True, env=env, timeout=300)

    out, rc, buf = {}, {}, None
    for line in proc.stdout.splitlines():
        if line.startswith('@@STEP '):
            buf = out.setdefault(line.split()[1], [])
        elif line.startswith('@@RC '):
            _, sid, code = line.split()
            rc[sid] = int(code)
        elif buf is not None:
            buf.append(line)

    print(f'sandbox: {sandbox}')
    print(f'git: {subprocess.run(["git", "--version"], capture_output=True, text=True).stdout.strip()}')
    failed = 0
    for sid, src, _ in steps:
        code = rc.get(sid, -1)
        errs = sum(1 for l in out.get(sid, []) if l.startswith('@@ERR '))
        failed += code != 0 or errs > 0
        print(f'=== step {sid} ({src}) rc={code} err={errs}')
        for line in out.get(sid, [])[:40]:
            print(line)
    if proc.stderr.strip():
        print('=== bash stderr\n' + proc.stderr.strip())
    print(f'SUMMARY: steps={len(steps)} failed={failed}')


if __name__ == '__main__':
    a = sys.argv[1:]
    if len(a) >= 2 and a[0] == 'extract' and os.path.isdir(a[1]):
        extract(a[1], a[2:])
    elif len(a) >= 2 and a[0] == 'run' and os.path.isfile(a[1]):
        run(a[1], a[3] if len(a) == 4 and a[2] == '--sandbox' else None)
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
