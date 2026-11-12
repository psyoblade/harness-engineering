# oneday 깃북 현황

로컬 경로 `~/git/psyoblade/oneday/` 의 6권 조사 결과 (2026-11-09).

| 책 | md | 줄 | 이미지 | 마지막 커밋 | 실습 런타임 | 특이 형식 |
|---|---|---|---|---|---|---|
| git | 8 | 826 | 10 | 2022-09 | bash (ubuntu) | `#### **<실습>**`, 명령어 표 |
| linux | 28 | 3,294 | 5 | 2022-11 | bash (ubuntu) | `<details>` 정답 접기 19, `<br>` 46 |
| python | 23 | 2,679 | 3 | 2022-06 | python (notebook) | `python` 블록 위주 |
| mysql | 14 | 1,138 | 4 | 2022-06 | sql (mysql) | `sql` 블록, 구문 표 |
| hadoop | 10 | 900 | 6 | 2022-06 | hdfs/yarn (datanode) | `python` 맵리듀스 예제 |
| docker | 6 | 315 | 26 | 2024-06 | 없음 (설치 가이드) | `env/` 없음, 스크린샷 위주 |

## 공통점
- `SUMMARY.md` + 디렉토리 단위 파트 + `README.md` 파트 대표 페이지
- 거의 모든 페이지에 `description` frontmatter
- `## N.` / `### N-M.` 번호 체계, `>` 인용 부연 설명
- docker 를 제외한 5권은 `env/README.md`, `env/run.md` 를 복사해 사용 (`data-engineer-basic-training` 레포, `SERVICE` 값만 다름)
- `{% %}` GitBook 전용 블록은 어느 책도 사용하지 않음

## 공통 결함 (한 번 고치면 5권에 반영)
- `env/run.md:30` `docker-compose logs $SERVICE notebook` (git·linux·hadoop·mysql·python)
- `env/README.md:23-24` Compose v1·git 2.17.1 요구 버전 (5권 동일)

## 결정
- 넓게 조사하고, 좁게 만들고, 순서대로 확장한다.
  - 구조·형식 규칙(style-guide, linter)은 6권 전체를 기준으로 일반화한다.
  - 실행 검증(lab-verifier)은 git(bash)으로 먼저 완성한 뒤 런타임 어댑터를 추가한다: bash → python → sql → hdfs. docker 는 실행 검증 대상에서 제외.
  - 정밀 정답지는 git 만 유지하고, 다른 책은 결정적으로 확인된 항목만 교차 검증 세트로 둔다.
- 리마스터 순서: env 공통 → git → linux → python → mysql → hadoop → docker
