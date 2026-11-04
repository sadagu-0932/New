# Tutorial Demo (가제)

2D 픽셀아트 탑다운 액션 슈팅 데모. 동아리 부스 시연·스피드런용 튜토리얼 구간.
전체 설계는 [CLAUDE.md](CLAUDE.md) 참고.

> 현재 진행: **M1** (이동·회피, 픽셀 렌더링, 임시 스프라이트, 디버그 키)

## 실행 방법

1. [Godot 4.7.x](https://godotengine.org/download) 표준판(.NET 아님)을 받는다.
2. 이 저장소를 받는다: `git clone <저장소 주소>`
3. Godot 프로젝트 매니저 → **가져오기** → 저장소 폴더의 `project.godot` 선택.
   처음 열 때 이미지 가져오기(import)가 자동으로 진행된다.
4. **F5**(프로젝트 실행)로 실행.

## 조작 (현재 구현된 것)

| 입력 | 동작 |
|---|---|
| WASD | 이동 |
| 마우스 | 조준 |
| Space | 회피 (이동 입력이 없으면 조준 방향) |

사격·근접·스킬·상호작용·재시작 등은 이후 마일스톤에서 추가된다.

### 디버그 키 (에디터 실행·디버그 빌드에서만)

| 키 | 동작 |
|---|---|
| F1 | 히트박스 표시 (하늘색 몸통 / 초록 피격 / 빨강 공격) |
| F2 | 무적 |
| F3 / F4 | 이전 / 다음 구간 시작 지점으로 이동 |

## 수치 바꾸기

모든 수치는 `data/*.tres`에 있다. 에디터 파일 시스템에서 더블클릭해 인스펙터로 고치거나, 텍스트로 직접 고쳐도 된다.

| 파일 | 내용 |
|---|---|
| `data/game_config.tres` | 틱 수, 데모 모드, 시드, 시작 맵 |
| `data/player.tres` | 이동 속도, 충돌·피격 크기 |
| `data/dodge.tres` | 회피 속도·지속·무적·쿨타임 (틱 단위, 60틱 = 1초) |
| `data/theme.tres` | 아트 테마 폴더 |

## 스프라이트 다시 만들기

```
pip install pillow
python3 tools/sprite_gen.py
```

`art/themes/dungeon/`에 PNG·JSON이 다시 생성된다 (같은 코드면 항상 같은 결과).
팔레트는 `palette.gpl`(Aseprite·GIMP에서 불러오기 가능).

## 자동 테스트 (헤드리스)

```
godot --headless --path . --import
godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn
```

스크립트로 입력을 흘려 넣어 이동·회피·충돌·결정론을 검사한다. 실패가 있으면 종료 코드 1.

## Windows exe 빌드

M10에서 정리 예정.
