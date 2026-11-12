# 정답지 (알려진 결함 목록)

`git-for-oneday` main@5b2cb5a 기준. 오케스트레이터의 탐지 재현율을 측정하는 기준이다.
- 담당: `lint`(gitbook-linter, 결정적 검사) / `lab`(lab-verifier, 실습 실행) / `learner`(learner-sim, 학습자 관점·사실 오류)
- 심각도: `P0` 실습 진행 불가·사실 오류 / `P1` 혼란 유발 / `P2` 표기·오탈자
- 검증: `확인` = 파일·줄 대조 또는 sandbox 실행(git 2.43)으로 재현함

| ID | 파일:줄 | 담당 | 심각도 | 결함 | 검증 |
|---|---|---|---|---|---|
| L01 | core/README.md:23 | lint | P1 | 링크 `env/setup.md` 는 삭제된 파일이며 상대경로 기준도 틀림 (`../env/README.md`) | 확인 |
| L02 | core/README.md:149,163 | lint | P2 | 섹션 번호 `2-2` 중복 (add/status, commit) | 확인 |
| L03 | core/README.md:83 | lint | P2 | nano 표 헤더가 `최상위 유형 \| 중간 유형` — 내용과 불일치 (`단축키 \| 설명`) | 확인 |
| L04 | core/README.md:168-169 | lint | P2 | `'[태그] 메시지]'` 닫는 대괄호 중복 | 확인 |
| L05 | core/README.md:190 | lint | P2 | 오탈자 `학장자` → `확장자` | 확인 |
| L06 | core/README.md:146,184, version.md:19, env/README.md:142 | lint | P2 | 코드 블록 언어 오용 — 파일 내용(md, .gitignore, csv)을 `bash` 블록에, 셸 명령을 언어 없는 블록에 | 확인 |
| L07 | core/branch.md:108 | lint | P2 | 오탈자 `--no-commmit` → `--no-commit` | 확인 |
| L08 | core/version.md:27 | lint | P2 | csv 구분자 오류 `3.스위트홈` → `3,스위트홈` | 확인 |
| L09 | core/intro.md:30 | lint | P2 | 오탈자 `Mecurial, Bazzar` → `Mercurial, Bazaar` | 확인 |
| L10 | env/run.md:9- | lint | P2 | `##` 없이 `###` 로 시작 (페이지 구조 규칙 위반) | 확인 |
| L11 | core/images/nano.jpg | lint | P2 | 어떤 페이지에서도 참조하지 않는 이미지 | 확인 |
| L12 | core/branch.md:47,68 | lint | P2 | 예제는 드라마 목록인데 설명·표 헤더는 `영화` | 확인 (2단계 agent 발견) |
| L13 | core/intro.md:24 | lint | P2 | `CVCS<탭>(Centralized VCS)` 탭 문자 | 확인 (2단계 agent 발견) |
| L14 | core/branch.md:10 | lint | P2 | "그림에서와 같이" 라고 하지만 페이지에 그림이 없음 | 확인 (haiku linter 발견) |
| B01 | env/README.md:24 | lab | P0 | 최소 버전 git 2.17.1 안내 — `git switch`(branch.md 1-2)는 2.23, `init.defaultBranch` 는 2.28 이상 필요 | 확인(릴리스 노트) |
| B02 | env/README.md:23,63 | lab | P1 | 요구 버전은 Compose v1(1.29.1)인데 출력 예시는 v2 형식(`[+] Running`, `⠿`) | 확인 |
| B03 | env/run.md:30 | lab | P1 | `docker-compose logs $SERVICE notebook` — `SERVICE=ubuntu` 라 ubuntu 로그까지 출력 | 확인 |
| B04 | core/README.md:35,58 | lab | P1 | `init.defaultBranch main` 을 `git init` 이후에 설정 → 저장소는 `master` 로 생성됨. 이후 master/main 혼재(version.md:45, branch.md:38,82)의 원인 | 확인(sandbox) |
| B05 | core/version.md:88-100 | lab | P1 | 코드 블록을 순서대로 실행하면 마지막 `git revert --continue` 가 `no cherry-pick or revert in progress` 로 실패 | 확인(sandbox) |
| B06 | core/version.md:45 vs 69 | lab | P2 | 기대 출력 커밋 메시지 `[2022] 넷플릭스` 와 지시된 형식 `[2022] 작품` 불일치 | 확인 |
| B07 | core/branch.md:172-187 | lab | P1 | 리베이스 전/후 기대 출력에 지시한 적 없는 커밋 `[원본] 수정`, `[충돌] 리베이스 재개` 등장 | 확인 |
| B08 | core/README.md:208 | lab | P1 | `.gitignore` 를 만들라는 지시 없이 `git add .gitignore` 실행 → `pathspec did not match` | 확인 |
| B09 | core/branch.md:163 | lab | P1 | rebase 충돌 후 편집 지시 없이 `git add README.md` — 그대로 하면 충돌 표시가 커밋됨 | 확인 (3단계 agent 발견, sandbox) |
| B10 | core/branch.md:124 | lab | P2 | 병합 충돌 해소 후 README.md 최종 내용이 제시되지 않음 (`nano` + `...`) | 확인 (3단계 agent 발견) |
| B11 | env/README.md:40 | lab | P1 | 이미 클론된 경우 `git pull` 을 `cd` 전에 `$WORK_DIR` 에서 실행 → `not a git repository` | 확인 (3단계 agent 발견, 정적) |
| R01 | core/version.md:25,86 | learner | P0 | revert 의 목적이 "인간교실 오타 수정"이라 했지만 2020 커밋을 revert 하면 `2020.csv` 가 통째로 삭제됨 | 확인(sandbox) |
| R02 | core/branch.md:146,161 | learner | P0 | rebase 설명 오류 — 변경되는 것은 대상 브랜치가 아니라 현재 브랜치 | 확인 |
| R03 | core/branch.md:30 | learner | P1 | `slave -> trunk` 대체 주장 — 근거 링크 내용과 다르며 일반적 용례 아님 | 링크 재확인 필요 |
| R04 | core/branch.md:40-41 vs 50 | learner | P2 | `switch -c` 를 지양하라면서 바로 앞 실습에서 사용 | 확인 |
| R05 | core/README.md:40 | learner | P2 | "`1-1` 방식으로" — 두 방식 모두 1-1 아래에 있어 지칭이 모호 (첫 번째 방식) | 확인 |
| R07 | core/branch.md:87 | learner | P1 | main 수정을 "어떤 수정사항도 좋으니" 로 지시 — 충돌이 안 날 수 있어 뒤의 충돌 해소 실습이 성립하지 않음 | 확인 (4단계 agent 발견) |
| R08 | core/intro.md:40 | learner | P1 | delta/스냅샷 문장의 주어가 꼬여 "기존 VCS 가 delta 방식이 아니다"로 읽힘 | 확인 (4단계 agent 발견) |
| R09 | core/README.md:78 | learner | P2 | vi 표에 `p`(붙여넣기)만 있고 복사(`yy`)·잘라내기 설명 없음 | 확인 (4단계 agent 발견) |
| R06 | core/intro.md:40 | lint | P2 | 문체 혼용 `~특징이다` (경어체 규칙 위반) | 확인 |

## 오탐 기록 (결함 아님)
| 파일:줄 | 내용 | 이유 |
|---|---|---|
| core/branch.md:38 | `git branch main` 이 rc=128 로 실패 (learner 4단계) | learner 의 sandbox 가 책 흐름(master 시작)을 따르지 않고 main 이 이미 있는 상태에서 재현 |
| core/version.md:25 | `인간교실` 오타 | revert 실습용으로 의도한 오류 (86행) — R01 참고 |
| images/git-small.png | 참조 없는 이미지 | GitBook 로고 등 외부 설정에서 쓰일 수 있음 — 확인 필요 |

## 측정 방법
- 재현율 = 탐지한 ID 수 / 전체 ID 수 (담당별로도 집계)
- 위 목록에 없는 탐지는 사람이 검토해 정답지에 추가하거나 오탐으로 분류한다.

## 교차 검증 세트 (다른 책, 결정적 항목만)
linter 의 범용성과 오탐 측정용. 모두 파일 존재·문자열 대조로 확인함.

| ID | 파일:줄 | 담당 | 심각도 | 결함 |
|---|---|---|---|---|
| X01 | {git,linux,hadoop,mysql,python}/env/run.md:30 | lab | P1 | B03 과 동일 (`logs $SERVICE notebook`) |
| X02 | {git,linux,hadoop,mysql,python}/env/README.md:23-24 | lab | P0 | B01·B02 와 동일 (요구 버전) |
| X03 | linux/shell/README.md:33,35,36,37 | lint | P1 | 없는 파일 링크 `control.md`, `logical.md`, `function.md`, `etc.md` (실제: ctrl, logic, func, util) |
| X04 | mysql/dml/README.md:11-15 | lint | P1 | 상대경로 중복 `dml/select.md` 등 (같은 디렉토리 기준이어야 함) |
| X05 | mysql/ddl/README.md:11-13 | lint | P1 | `ddl/create.md`, `alter.md`, `drop.md` — 경로 중복이며 파일 자체도 없음 (실제: types, cud) |
| X06 | linux/utils/file.md:82, mysql/dml/cud.md:66, python/core/dict.md:74, python/core/list.md:144, python/stmt/README.md:99, hadoop/hdfs/faq.md:129, docker/install/windows.md:134 | lint | P1 | 섹션 번호 중복 (2단계 lint.py 발견) |
| X07 | python/env/setup.md, python/terminal/terminal-env.md | lint | P2 | SUMMARY.md 에 없는 페이지 |
| X08 | hadoop/yarn/images/yarn-app.png | lint | P2 | 참조 없는 이미지 |
| X09 | docker/install/README.md | lint | P1 | frontmatter 만 있고 본문 없음 |
