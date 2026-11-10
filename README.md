# demo

2D 픽셀 탑다운 액션 슈팅 데모

## 플레이

- **웹:** https://sadagu-0932.github.io/New/
- **다운로드 (Windows · Linux · Android):** [Releases](https://github.com/sadagu-0932/New/releases/latest)

## 조작

| 입력 | 동작 |
|---|---|
| WASD | 이동 |
| 마우스 | 조준 |
| 좌클릭 | 사격 |
| 우클릭 | 근접 공격 · 패링 |
| Space | 회피 |
| Q | 스킬 |
| Tab | 스킬 설정 (출발 전에만) |
| E | 상호작용 |
| R (길게) | 재시작 |
| Esc | 일시정지 |

## 개발

- Godot 4.7, 설계 문서는 [CLAUDE.md](CLAUDE.md)
- 테스트: `godot --headless --path . res://tests/test_runner.tscn`
- 스프라이트 다시 만들기: `python3 tools/sprite_gen.py`
- 배포 (main 푸시 + 웹 + Releases): `tools/publish.sh`
