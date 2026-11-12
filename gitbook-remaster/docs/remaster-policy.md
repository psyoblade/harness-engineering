# 리마스터 정책 (저자 결정)

reviser 와 리마스터 작업은 이 문서의 결정을 따른다. 여기 없는 판단이 필요하면 수정하지 말고 `확인 필요` 로 남긴다.

## 결정됨
| 항목 | 결정 | 영향 |
|---|---|---|
| git 최소 버전 | 2.28 이상 (`git switch` 2.23, `init.defaultBranch` 2.28) | 5권 `env/README.md` 요구 버전 (B01, X02) |
| Docker Compose | v2 로 전환. 명령은 `docker compose` (하이픈 없음), 출력 예시도 v2 형식. 최소 버전 `v2.5.0` | 5권 `env/` 전체, 본문의 `docker-compose` 명령, alias `d`, docker 책 설치 가이드 (B02, X02) |
| 기본 브랜치 | `master` 로 시작하는 현재 흐름 유지. `git init` 과 `init.defaultBranch` 순서를 바꾸지 않는다 | B04 는 흐름 변경 없이 설명 보완만 허용 |
| revert 실습 (R01) | 예제를 다시 쓴다. **잘못된 커밋**(예: 2020.csv 에 엉뚱한 작품 추가)을 먼저 만들고 그 커밋을 revert 해서 잘못된 변경만 취소한다. 올바른 수정(오타 수정)을 되돌리는 흐름은 금지 — revert 하면 오류가 되살아남 | core/version.md 2절, 이어지는 branch.md 기대 출력 (`Revert ...` 커밋) |
| 실습 환경 | `~/git/psyoblade/training/basic` (= `data-engineer-basic-training`) 이 5권 공통 환경. intermediate·advanced 는 이 책들과 무관 | `env/` 의 `COURSE_NAME` 유지 |
| 실습 컨테이너 | `psyoblade/data-engineer-ubuntu:22.04` 로 고정 (Ubuntu 22.04, `-multi`·`-slim` 태그는 쓰지 않음). 책의 우분투 버전 확인 출력은 22.04 로, 컨테이너 안에서 `git --version` 으로 2.28 이상인지 확인하는 단계를 둔다 | env/README.md 1-5, git 2.28 요구가 호스트·컨테이너 모두에 적용됨 |
| 브랜치 실습 명령 | 브랜치 생성·전환은 본문 지시만 두지 않고 명령 블록(`git switch main`, `git branch <이름>`, `git switch <이름>`)으로 명시한다. 각 브랜치 커밋 후 main 복귀도 명령으로 쓴다 | core/branch.md 1-3 (old-style, new-style) |

## 보류 항목 결정 (2026-11-11, 모두 수정)
| 항목 | 결정 |
|---|---|
| `core/images/nano.jpg` | `core/README.md` nano 단축키 절에 이미지로 참조 추가 |
| `images/git-small.png` | 사용처 없음 — 수정본에서 제거 (원본 PR 에서 삭제) |
| R03 `slave -> trunk` | 근거 없는 `slave -> trunk` 주장 삭제. `master` 대신 `main` 을 쓰는 추세만 설명하고 링크 유지 |
| R04 `switch -c` 권고 | 실습 명령은 유지하고, 권고 문장을 "`switch -c` 는 현재 브랜치에서 파생되므로 1-2 처럼 old-branch 에서 실행하면 new-branch 가 old-branch 에서 파생된다 → 실습 데이터는 main 에서 branch 로 만든다"는 이유 설명으로 바꾼다 |
| R08 intro delta 문장 | "기존 VCS 는 delta 를 저장하지만 Git 은 스냅샷을 저장한다"로 주어를 바로잡고 경어체로 쓴다 |

## 실습 환경 레포 반영 (2026-11-12, 미커밋)
- `training/basic/docker-compose.yml`: ubuntu 이미지 `20.04` → `22.04`, `version: "3"` 제거
- `training/advanced/day2/{ex5,ex10,quiz5}/docker-compose.yml`: `version` 제거
- `ubuntu-server` 이미지(`data-engineer-ubuntu-server:20.04`)는 변경하지 않음

## 미결정
