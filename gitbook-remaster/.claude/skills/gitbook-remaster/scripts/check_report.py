#!/usr/bin/env python3
"""리뷰 리포트 형식 게이트. 에이전트 정의의 '리포트 형식'을 지켰는지 검사한다.

사용법: python3 check_report.py <lint|lab|learner|revise> <책 루트> <리포트.md> [<이전 lab 리포트.md>]
검사:   표 헤더, 행마다 파일 참조·심각도, 필수 섹션, 줄 번호 범위(check_refs)
        lab 은 유형 이름과, 리포트의 steps/failed 가 같은 디렉토리의 lab/run.log 와 같은지도 검사한다.
출력:   BAD\t<사유> 줄들, 마지막 줄 RESULT: PASS | FAIL
        lab 은 TYPES: <유형>=<행 수> ... 줄을 함께 출력한다 (재검증 게이트는 실행 실패·출력 불일치가 0 인지 본다).
        이전 lab 리포트를 주면 REPEAT: <n> 줄을 출력한다 (같은 파일·step·유형의 실행 실패·출력 불일치가 다시 나온 수).
"""
import os
import re
import sys

from check_refs import REF_RE

HEADERS = {
    'lint': '| # | 파일:줄 | 출처 | 규칙 | 심각도 | 내용 | 수정 제안 |',
    'lab': '| # | 파일:줄 | 유형 | 심각도 | 근거 | 수정 제안 |',
    'learner': '| # | 파일:줄 | 유형 | 심각도 | 근거 | 수정 제안 |',
    'revise': '| # | 출처 | 파일:줄 | 조치 | 내용 |',
}
SEV_COL = {'lint': 4, 'lab': 3, 'learner': 3}
REF_COL = {'lint': 1, 'lab': 1, 'learner': 1, 'revise': 2}
REQUIRED = {
    'lint': [r'^lint\.py: ERROR=\d+ WARN=\d+'],
    'lab': [r'^실행: steps=\d+ failed=\d+', r'^## 보정 목록'],
    'learner': [r'^읽은 페이지: \d+/\d+'],
    'revise': [r'^결함: \d+건 \(수정 \d+ / 보류 \d+ / 거부 \d+\)'],
}
FILE_REF = re.compile(r'[\w./-]+\.(md|png|jpe?g|gif|svg)(:\d+)?')
GATE_TYPES = ('실행 실패', '출력 불일치')
LAB_TYPES = GATE_TYPES + ('설명 불일치', '지시 누락', '버전·환경')


def cells(line):
    return [c.strip() for c in re.split(r'(?<!\\)\|', line.strip().strip('|'))]


def table_rows(lines, header):
    """헤더 아래의 표 행들. 헤더가 없으면 None."""
    if header not in lines:
        return None
    rows = []
    for l in lines[lines.index(header) + 2:]:
        if not l.startswith('|'):
            break
        rows.append(cells(l))
    return rows


def gate_keys(rows):
    """lab 리포트에서 실행 실패·출력 불일치 행의 (파일, step id, 유형)."""
    keys = set()
    for r in rows or []:
        if len(r) == 6 and r[2] in GATE_TYPES:
            ref, step = FILE_REF.search(r[1]), re.search(r'step (\S+)', r[4])
            keys.add((ref.group(0).split(':')[0] if ref else r[1], step.group(1) if step else '-', r[2]))
    return keys


def main(kind, root, report, prev=None):
    text = open(report, encoding='utf-8').read()
    lines = text.splitlines()
    bad = []

    for pat in REQUIRED[kind]:
        if not any(re.match(pat, l) for l in lines):
            bad.append(f'필수 줄 없음: {pat}')

    header = HEADERS[kind]
    rows = table_rows(lines, header)
    if rows is None:
        bad.append(f'표 헤더 불일치 (기대: {header})')
        rows = []
    elif not rows and '결함 없음' not in text:
        bad.append('결함 행 0개 — 결함이 없으면 표 아래에 "결함 없음" 이라고 쓴다')
    for r in rows:
        if len(r) != len(cells(header)):
            bad.append(f'열 개수 불일치: | {" | ".join(r)[:60]}')
            continue
        if not FILE_REF.search(r[REF_COL[kind]]):
            bad.append(f'#{r[0]} 파일:줄 형식 아님: {r[REF_COL[kind]]}')
        if kind in SEV_COL and not re.match(r'^P[012]$', r[SEV_COL[kind]]):
            bad.append(f'#{r[0]} 심각도 형식 아님: {r[SEV_COL[kind]]}')
        if kind == 'lab' and r[2] not in LAB_TYPES:
            bad.append(f'#{r[0]} 유형은 {" / ".join(LAB_TYPES)} 중 하나: {r[2]}')
        if kind == 'revise' and r[3] not in ('수정', '보류', '거부'):
            bad.append(f'#{r[0]} 조치는 수정/보류/거부 중 하나: {r[3]}')
        if kind == 'revise' and not re.match(r'^((lint|lab|learner)#\d+(, ?)?)+$|^policy$', r[1]):
            bad.append(f'#{r[0]} 출처 형식 아님: {r[1]}')
    if kind == 'lint' and rows and not any(r[2] == 'agent' for r in rows if len(r) > 2) \
            and '의미 검사: 결함 없음' not in text:
        bad.append('의미 검사(출처 agent) 행 없음 — 수행했다면 "의미 검사: 결함 없음" 이라고 쓴다')

    sizes = {}
    for m in REF_RE.finditer(text):
        path = m.group(1)
        full = os.path.join(root, path)
        if not os.path.isfile(full):
            continue
        if path not in sizes:
            with open(full, encoding='utf-8') as f:
                sizes[path] = sum(1 for _ in f)
        nums = [int(n) for n in re.findall(r'\d+', m.group(0)[len(path):])]
        if any(n < 1 or n > sizes[path] for n in nums):
            bad.append(f'줄 번호 범위 밖: {m.group(0)} ({path} 은 {sizes[path]}줄)')

    if kind == 'lab':
        m = next(filter(None, (re.match(REQUIRED['lab'][0], l) for l in lines)), None)
        claimed = m.group(0) if m else None
        log = os.path.join(os.path.dirname(os.path.abspath(report)), 'lab', 'run.log')
        if os.path.isfile(log):
            with open(log, encoding='utf-8') as f:
                actual = next((l.strip() for l in reversed(f.read().splitlines()) if l.startswith('SUMMARY: ')), '')
            if claimed and claimed.replace('실행: ', 'SUMMARY: ') != actual:
                bad.append(f'리포트의 "{claimed}" 가 lab/run.log 의 "{actual}" 와 다름')
        elif claimed and not claimed.startswith('실행: steps=0 '):
            bad.append(f'lab/run.log 없음 ({log}) — lab_run.py run --log 로 만든다')

    for b in bad:
        print(f'BAD\t{b}')
    if kind == 'lab':
        print('TYPES: ' + ' '.join(f'{t}={sum(1 for r in rows if len(r) == 6 and r[2] == t)}' for t in LAB_TYPES))
    if prev:
        with open(prev, encoding='utf-8') as f:
            again = sorted(gate_keys(rows) & gate_keys(table_rows(f.read().splitlines(), header)))
        print(f'REPEAT: {len(again)}' + ''.join(f'\t{"|".join(k)}' for k in again))
    print(f'SUMMARY: rows={len(rows)} bad={len(bad)}')
    print('RESULT: ' + ('FAIL' if bad else 'PASS'))
    return 1 if bad else 0


if __name__ == '__main__':
    n = len(sys.argv)
    if n not in (4, 5) or sys.argv[1] not in HEADERS or (n == 5 and sys.argv[1] != 'lab'):
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(main(*sys.argv[1:]))
