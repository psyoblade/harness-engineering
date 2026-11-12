# 6단계 실행 가이드: Claude Code 에서 에이전트 팀 실제 실행

목적: SKILL.md 의 팀 동작(팀원 생성, 태스크 의존성, 리더 게이트, 승인 대기)이 실제로 동작하는지 확인하고, 클라우드 dry-run 결과와 비교한다.

## 1. 사전 준비
1. harness-engineering 정리
   - `gitbook-remaster/`, `.gitattributes`, `.gitignore` 커밋 (`_workspace/` 는 ignore 됨)
2. training 레포의 미커밋 변경(basic, advanced compose 파일) 커밋 여부 결정
3. 원본 책이 깨끗한지 확인: `git -C ~/git/psyoblade/oneday/git status` → 변경 없음, `main` 브랜치
4. 세션 시작
   ```bash
   cd ~/git/psyoblade/harness-engineering/gitbook-remaster
   claude
   ```
   - `.claude/settings.json` 이 팀 기능 env, 책 폴더 접근(additionalDirectories), 권한 규칙을 적용한다.

## 2. 실행
```
/gitbook-remaster git
```
(또는 "git 책 리마스터 해줘")
- Phase 0 에서 기존 `_workspace/git` 은 `_workspace/git.bak-<시각>` 으로 보관된다 (클라우드 결과, 비교 기준).

## 3. 관찰 체크리스트
| Phase | 확인할 것 | 기록 |
|---|---|---|
| 0 | 사전 점검 4개 통과, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` | |
| 1 | 팀원 4명이 agent type(gitbook-linter 등)으로 생성되는가 | |
| 2 | T5(reviser)가 G1 완료 전에 시작하지 않는가 | |
| 3 | 리더가 `check_report.py` 를 직접 실행하는가, FAIL 시 팀원에게 되돌리는가 | |
| 4 | `book.prev` 스냅샷, V3 생략 판정(`book_sync.py code`), 재검증 모드 사용 | |
| 5 | 승인 질문에서 멈추는가 | |
| 전체 | 권한 프롬프트 횟수 (allow 규칙이 먹는지), `/cost` 토큰 | |

## 4. Phase 5 승인 선택
- 첫 실행 권장: **승인** → review 브랜치 생성과 커밋까지 진행 → `git push` 확인 프롬프트에서 **거절** → 로컬에서 브랜치를 직접 검토
- PR 까지 가려면 push 와 `gh pr create` 를 각각 허용

## 5. 결과 비교 (실행 후 알려 주면 분석)
- `_workspace/git/remaster_report.md` vs `_workspace/git.bak-*/remaster_report.md`
- 리뷰 행 수, 조치 건수(수정/보류/거부), 반복 횟수, 정답지(`fixtures/answer-key.md`) 재현율
- 예상 비용: 리뷰 3 × 약 10만 + reviser 약 11만 + 재검증 약 8만 → 약 50만 토큰 (클라우드 실측 기준 추정)
