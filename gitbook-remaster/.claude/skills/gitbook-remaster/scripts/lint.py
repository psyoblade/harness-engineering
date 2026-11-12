#!/usr/bin/env python3
"""GitBook 실습서 구조 검사 (결정적 규칙만).

사용법: python3 lint.py <책 루트 디렉토리>
출력:   <LEVEL>\t<RULE>\t<파일>:<줄>\t<메시지>  (LEVEL = ERROR | WARN)
        마지막 줄 RESULT: PASS | FAIL  (ERROR 가 하나라도 있으면 FAIL)
"""
import os
import re
import sys
from urllib.parse import unquote

IMG_EXT = ('.png', '.jpg', '.jpeg', '.gif', '.svg')
LINK_RE = re.compile(r'!?\[[^\]]*\]\(([^)\s]+)')
SRC_RE = re.compile(r'<img[^>]*\ssrc="([^"]+)"')
HEAD_RE = re.compile(r'^ {0,3}(#{1,6})\s+(.*)$')
SECNUM_RE = re.compile(r'^(\d+(?:[-.]\d+)*)\.?\s')

findings = []


def report(level, rule, path, line, msg):
    findings.append((level, rule, f'{path}:{line}', msg))


def scan(root, rel):
    """코드 블록 밖의 (줄번호, 줄) 과 닫히지 않은 블록 여부를 돌려준다."""
    lines, in_fence, fence_line = [], False, 0
    with open(os.path.join(root, rel), encoding='utf-8') as f:
        for no, line in enumerate(f, 1):
            line = line.rstrip('\r\n')
            if line.lstrip().startswith('```'):
                in_fence, fence_line = not in_fence, no
                continue
            if not in_fence:
                lines.append((no, line))
    return lines, (fence_line if in_fence else 0)


def targets(line):
    for m in LINK_RE.finditer(line):
        yield m.group(1)
    for m in SRC_RE.finditer(line):
        yield m.group(1)


def main(root):
    md_files, img_files = [], []
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if not x.startswith('.')]
        for name in files:
            rel = os.path.relpath(os.path.join(d, name), root).replace(os.sep, '/')
            if name.endswith('.md'):
                md_files.append(rel)
            elif name.lower().endswith(IMG_EXT):
                img_files.append(rel)

    referenced, summary_pages = set(), set()
    for rel in sorted(md_files):
        lines, open_fence = scan(root, rel)
        base = os.path.dirname(rel)
        text = open(os.path.join(root, rel), encoding='utf-8').read()

        if open_fence:
            report('ERROR', 'FENCE', rel, open_fence, '닫히지 않은 코드 블록')

        if rel != 'SUMMARY.md' and not re.match(r'---\s*\ndescription:', text):
            report('WARN', 'FRONTMATTER', rel, 1, 'description frontmatter 없음')

        h1, prev_level, seen = 0, 0, {}
        for no, line in lines:
            for url in targets(line):
                if re.match(r'^(https?:|mailto:|#)', url):
                    continue
                path = os.path.normpath(os.path.join(base, unquote(url.split('#')[0]))).replace(os.sep, '/')
                referenced.add(path)
                if rel == 'SUMMARY.md':
                    summary_pages.add(path)
                if not os.path.exists(os.path.join(root, path)):
                    report('ERROR', 'LINK', rel, no, f'없는 대상 {url}')

            m = HEAD_RE.match(line)
            if not m or rel == 'SUMMARY.md':
                continue
            level, title = len(m.group(1)), m.group(2).strip()
            if level == 1:
                h1 += 1
            elif prev_level and level > prev_level + 1:
                report('WARN', 'HEADING', rel, no, f'제목 단계 건너뜀 h{prev_level} -> h{level}')
            prev_level = level
            n = SECNUM_RE.match(title)
            if n and level in (2, 3):
                if n.group(1) in seen:
                    report('ERROR', 'SECNUM', rel, no, f'섹션 번호 {n.group(1)} 중복 (첫 등장 {seen[n.group(1)]}행)')
                else:
                    seen[n.group(1)] = no
        if rel != 'SUMMARY.md' and h1 != 1:
            report('WARN', 'HEADING', rel, 1, f'h1 개수 {h1} (1개여야 함)')

    if 'SUMMARY.md' in md_files:
        for rel in md_files:
            if rel not in summary_pages and rel != 'SUMMARY.md':
                report('WARN', 'ORPHAN-PAGE', rel, 1, 'SUMMARY.md 에 없는 페이지')

    for rel in img_files:
        if rel not in referenced:
            report('WARN', 'ORPHAN-IMAGE', rel, 0, '어떤 페이지에서도 참조하지 않는 이미지')

    for f in findings:
        print('\t'.join(f))
    errors = sum(1 for f in findings if f[0] == 'ERROR')
    print(f'SUMMARY: ERROR={errors} WARN={len(findings) - errors}')
    print('RESULT: ' + ('FAIL' if errors else 'PASS'))
    return 1 if errors else 0


if __name__ == '__main__':
    if len(sys.argv) != 2 or not os.path.isdir(sys.argv[1]):
        print('사용법: python3 lint.py <책 루트 디렉토리>', file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
