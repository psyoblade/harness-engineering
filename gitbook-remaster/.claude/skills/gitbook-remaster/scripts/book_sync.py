#!/usr/bin/env python3
"""원본 책(git 저장소)과 수정 사본의 차이 확인·반영.

사용법:
  python3 book_sync.py diff  <원본 책> <사본>   변경 목록 출력 (M 수정 / A 추가 / D 삭제)
  python3 book_sync.py apply <원본 책> <사본>   변경을 원본 작업 트리에 반영 (D 는 git rm)
  python3 book_sync.py code  <이전 사본> <현재 사본>  코드 블록 안(명령·출력) 변경 줄 수. CODE=0 이면 실습 재검증 생략 가능
비교 대상: 원본은 `git ls-files` 의 추적 파일, 사본은 `.git` 을 제외한 모든 파일.
apply 는 원본이 review/ 브랜치이고 미커밋 변경이 없을 때만 동작한다.
"""
import difflib
import filecmp
import os
import shutil
import subprocess
import sys


def git(book, *args):
    return subprocess.run(['git', '-C', book, *args], capture_output=True, text=True, check=True).stdout


def changes(book, copy):
    tracked = set(git(book, 'ls-files').splitlines())
    copied = set()
    for d, dirs, files in os.walk(copy):
        dirs[:] = [x for x in dirs if x != '.git']
        for name in files:
            copied.add(os.path.relpath(os.path.join(d, name), copy).replace(os.sep, '/'))
    out = []
    for p in sorted(tracked | copied):
        if p not in copied:
            out.append(('D', p))
        elif p not in tracked:
            out.append(('A', p))
        elif not filecmp.cmp(os.path.join(book, p), os.path.join(copy, p), shallow=False):
            out.append(('M', p))
    return out


def code_lines(path):
    """코드 블록 안쪽 줄만 (fence 줄 제외) 돌려준다."""
    if not os.path.isfile(path):
        return []
    out, inside = [], False
    with open(path, encoding='utf-8') as f:
        for line in f:
            if line.lstrip().startswith('```'):
                inside = not inside
            elif inside:
                out.append(line.rstrip('\r\n'))
    return out


def code_changes(prev, cur):
    total = 0
    pages = set()
    for base in (prev, cur):
        for d, dirs, files in os.walk(base):
            dirs[:] = [x for x in dirs if x != '.git']
            pages |= {os.path.relpath(os.path.join(d, n), base) for n in files if n.endswith('.md')}
    for p in sorted(pages):
        diff = [l for l in difflib.unified_diff(code_lines(os.path.join(prev, p)), code_lines(os.path.join(cur, p)), lineterm='', n=0)
                if l[:1] in '+-' and not l.startswith(('+++', '---'))]
        if diff:
            print(f'{len(diff)}\t{p}')
            total += len(diff)
    print(f'CODE={total}')
    return 0


def main(cmd, book, copy):
    if cmd == 'code':
        return code_changes(book, copy)
    items = changes(book, copy)
    if cmd == 'apply':
        branch = git(book, 'branch', '--show-current').strip()
        if not branch.startswith('review/'):
            print(f'거부: 현재 브랜치 {branch} — review/ 브랜치에서만 반영한다', file=sys.stderr)
            return 1
        if git(book, 'status', '--porcelain').strip():
            print('거부: 원본에 미커밋 변경이 있다', file=sys.stderr)
            return 1
        for kind, p in items:
            if kind == 'D':
                git(book, 'rm', '-q', '--', p)
            else:
                os.makedirs(os.path.dirname(os.path.join(book, p)) or book, exist_ok=True)
                shutil.copy2(os.path.join(copy, p), os.path.join(book, p))
    for kind, p in items:
        print(f'{kind}\t{p}')
    counts = {k: sum(1 for x, _ in items if x == k) for k in 'MAD'}
    print(f'SUMMARY: M={counts["M"]} A={counts["A"]} D={counts["D"]}')
    return 0


if __name__ == '__main__':
    if len(sys.argv) != 4 or sys.argv[1] not in ('diff', 'apply', 'code'):
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(main(*sys.argv[1:]))
