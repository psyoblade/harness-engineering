#!/usr/bin/env python3
"""실습 코드 블록 추출, 실행 계획 골격 생성, sandbox 실행, 실행 로그 비교.

사용법:
  python3 lab_run.py extract <책 루트> [페이지 ...]
      페이지 순서(SUMMARY.md 순, 또는 지정 순)대로 코드 블록 목록을 출력한다.
      <파일>:<줄>\t<언어>\t<추정 유형>\t<첫 줄>
      추정 유형: cmd(실행 명령) | output(기대 출력) | file(파일 내용) — 참고용이며 최종 판단은 에이전트가 한다.

  python3 lab_run.py plan <책 루트> [페이지 ...]
      plan.sh 골격을 출력한다. cmd 로 추정한 블록은 '#@ step <id> <파일:줄>' 단계로 책의 내용 그대로 넣고,
      나머지 블록은 '# skip <파일:줄> <추정 유형> <첫 줄>' 주석으로 남긴다.
      단계 id 는 <페이지 경로의 / 를 - 로 바꾼 이름>-<페이지 안 순번> (예: core-version-03).

  python3 lab_run.py run <plan.sh> [--sandbox <디렉토리>] [--log <파일>]
      plan.sh 의 단계를 하나의 bash 세션에서 순서대로 실행한다 (상태 공유, 실패해도 계속).
      단계 구분: '#@ step <id> <출처 파일:줄>' 줄. 그 아래 줄들이 해당 단계 명령이다.
      sandbox: HOME, WORK_DIR 을 임시 디렉토리로 격리하고 GIT_CONFIG_NOSYSTEM=1, 편집기는 no-op.
      출력: 단계별 '=== step <id> (<출처>) rc=<n> err=<n>' 과 출력 (단계당 40줄까지). 단계 안에서 실패한 명령은 '@@ERR rc=<n> : <명령>' 줄로 표시.
      마지막 줄 SUMMARY: steps=<n> failed=<n>  (rc != 0 이거나 err > 0 인 단계)
      --log 를 주면 전체 출력을 그 파일에 쓰고, 화면에는 실패한 단계와 SUMMARY 만 출력한다.

  python3 lab_run.py compare <이전 run.log> <현재 run.log>
      단계 id 로 두 로그를 맞춰 rc, err, 출력이 달라진 단계를 출력한다 (해시, 날짜, 시각, sandbox 경로 차이는 무시).
      CHANGED\t<id>\t<출처>\t<달라진 것>  /  ADDED\t<id>\t<출처>  /  REMOVED\t<id>
      마지막 줄 SUMMARY: steps=<n> changed=<n> added=<n> removed=<n>
"""
import os
import re
import subprocess
import sys
import tempfile

FENCE_RE = re.compile(r'^\s*```(\S*)')
SUMMARY_RE = re.compile(r'\]\(([^)\s#]+\.md)')
STEP_RE = re.compile(r'^#@ step (\S+)\s*(.*)$')
LOG_STEP_RE = re.compile(r'^=== step (\S+) \((.*)\) rc=(-?\d+) err=(\d+)$')
MAX_STEP_LINES = 40


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


def blocks(root, page):
    """페이지의 코드 블록을 (시작 줄, 언어, 추정 유형, 본문 줄들) 로 돌려준다."""
    lang, start, body = None, 0, []
    with open(os.path.join(root, page), encoding='utf-8') as f:
        for no, line in enumerate(f, 1):
            m = FENCE_RE.match(line)
            if m and lang is None:
                lang, start, body = m.group(1), no, []
            elif m:
                yield start, lang, guess_kind(lang, body), body
                lang = None
            elif lang is not None:
                body.append(line.rstrip('\r\n'))


def first_line(body):
    return next((l for l in body if l.strip()), '').strip()[:60]


def extract(root, pages):
    for page in pages or pages_in_order(root):
        for start, lang, kind, body in blocks(root, page):
            print(f'{page}:{start}\t{lang or "-"}\t{kind}\t{first_line(body)}')


def plan(root, pages):
    for page in pages or pages_in_order(root):
        slug, n = page[:-len('.md')].replace('/', '-'), 0
        for start, _, kind, body in blocks(root, page):
            if kind != 'cmd':
                print(f'# skip {page}:{start} {kind} {first_line(body)}')
                continue
            n += 1
            print(f'#@ step {slug}-{n:02d} {page}:{start}')
            print('\n'.join(body))


def run(plan, sandbox, log):
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
        # 주석만 남은 단계도 문법 오류가 나지 않게 ':' 로 시작한다
        script.append('{\n:\n' + '\n'.join(cmds) + '\n} 2>&1')
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

    head = [f'sandbox: {sandbox}',
            f'git: {subprocess.run(["git", "--version"], capture_output=True, text=True).stdout.strip()}']
    full, failed_only, failed = [], [], 0
    for sid, src, _ in steps:
        code, lines = rc.get(sid, -1), out.get(sid, [])
        errs = sum(1 for l in lines if l.startswith('@@ERR '))
        block = [f'=== step {sid} ({src}) rc={code} err={errs}'] + lines[:MAX_STEP_LINES]
        if len(lines) > MAX_STEP_LINES:
            block.append(f'... ({len(lines) - MAX_STEP_LINES}줄 생략)')
        full += block
        if code != 0 or errs > 0:
            failed += 1
            failed_only += block
    tail = ['=== bash stderr', proc.stderr.strip()] if proc.stderr.strip() else []
    tail.append(f'SUMMARY: steps={len(steps)} failed={failed}')

    if log:
        with open(log, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(head + full + tail) + '\n')
        print('\n'.join(head + failed_only + tail + [f'log: {log}']))
    else:
        print('\n'.join(head + full + tail))


def load_log(path):
    """run 로그를 {단계 id: (출처, rc, err, 정규화한 출력)} 로 읽는다."""
    steps, cur, sandbox = {}, None, None
    with open(path, encoding='utf-8') as f:
        for line in f.read().splitlines():
            m = LOG_STEP_RE.match(line)
            if line.startswith('sandbox: '):
                sandbox = line[len('sandbox: '):]
            elif m:
                cur = []
                steps[m.group(1)] = (m.group(2), m.group(3), m.group(4), cur)
            elif line.startswith(('=== bash stderr', 'SUMMARY: ')):
                cur = None
            elif cur is not None:
                if sandbox:
                    line = line.replace(sandbox, '<sandbox>')
                line = re.sub(r'lab-\w{8}', '<sandbox>', line)
                line = re.sub(r'\b[0-9a-f]{7,40}\b', '<hash>', line)
                line = re.sub(r'^Date:.*', 'Date: <date>', line)
                line = re.sub(r'\d{4}-\d{2}-\d{2}', '<date>', line)
                cur.append(re.sub(r'\d{2}:\d{2}:\d{2}', '<time>', line))
    return steps


def compare(prev_log, cur_log):
    prev, cur = load_log(prev_log), load_log(cur_log)
    changed = added = 0
    for sid, (src, code, errs, lines) in cur.items():
        if sid not in prev:
            added += 1
            print(f'ADDED\t{sid}\t{src}')
            continue
        _, pcode, perrs, plines = prev[sid]
        diff = []
        if code != pcode:
            diff.append(f'rc {pcode}->{code}')
        if errs != perrs:
            diff.append(f'err {perrs}->{errs}')
        if lines != plines:
            diff.append('output')
        if diff:
            changed += 1
            print(f'CHANGED\t{sid}\t{src}\t{", ".join(diff)}')
    removed = [sid for sid in prev if sid not in cur]
    for sid in removed:
        print(f'REMOVED\t{sid}')
    print(f'SUMMARY: steps={len(cur)} changed={changed} added={added} removed={len(removed)}')


if __name__ == '__main__':
    a, opts = sys.argv[1:], {}
    for name in ('--sandbox', '--log'):
        if name in a[:-1]:
            i = a.index(name)
            opts[name] = a[i + 1]
            del a[i:i + 2]
    if len(a) >= 2 and a[0] == 'extract' and os.path.isdir(a[1]):
        extract(a[1], a[2:])
    elif len(a) >= 2 and a[0] == 'plan' and os.path.isdir(a[1]):
        plan(a[1], a[2:])
    elif len(a) == 2 and a[0] == 'run' and os.path.isfile(a[1]):
        run(a[1], opts.get('--sandbox'), opts.get('--log'))
    elif len(a) == 3 and a[0] == 'compare' and os.path.isfile(a[1]) and os.path.isfile(a[2]):
        compare(a[1], a[2])
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
