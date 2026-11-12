#!/usr/bin/env python3
"""리포트의 `파일:줄` 참조가 실제 책 파일 범위 안에 있는지 검사한다.

사용법: python3 check_refs.py <책 루트> <리포트.md>
출력:   BAD\t<참조>\t<사유>  /  마지막 줄 RESULT: PASS | FAIL
"""
import os
import re
import sys

REF_RE = re.compile(r'([\w./-]+\.md):(\d+)(?:-(\d+))?((?:,\s*\d+)*)')


def main(root, report):
    sizes, bad, total = {}, 0, 0
    text = open(report, encoding='utf-8').read()
    for m in REF_RE.finditer(text):
        path = m.group(1)
        full = os.path.join(root, path)
        if not os.path.isfile(full):
            continue  # 책 밖 파일(리포트 경로 등)은 검사하지 않는다
        if path not in sizes:
            with open(full, encoding='utf-8') as f:
                sizes[path] = sum(1 for _ in f)
        nums = [int(m.group(2))] + ([int(m.group(3))] if m.group(3) else [])
        nums += [int(n) for n in re.findall(r'\d+', m.group(4))]
        total += 1
        over = [n for n in nums if n < 1 or n > sizes[path]]
        if over:
            bad += 1
            print(f'BAD\t{m.group(0)}\t{path} 은 {sizes[path]}줄, 범위 밖 {over}')
    print(f'SUMMARY: refs={total} bad={bad}')
    print('RESULT: ' + ('FAIL' if bad else 'PASS'))
    return 1 if bad else 0


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2]))
