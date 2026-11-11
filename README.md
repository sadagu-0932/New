# demo-story

2D 픽셀 탑다운 액션 슈팅 — 스토리판 (`story-mode` 브랜치). 스피드런판은 `main` 브랜치의 별개 게임이다.

## 플레이

- 스토리판은 Windows 판만 만든다 (안드로이드용은 나중에 추가). 아직 올려 둔 다운로드는 없다 → `tools/build_story.sh` 로 exe 를 만들거나 Godot 4.7 로 프로젝트를 열어 실행
- 스피드런판은 `main` 브랜치의 README 참고

## 조작

| 입력 | 동작 |
|---|---|
| WASD | 이동 |
| 마우스 | 조준 |
| 좌클릭 | 사격 |
| 우클릭 | 근접 공격(총으로 후려치기) · 패링 |
| Space | 회피 |
| Q / F | 스킬1 / 스킬2 (스킬2 는 프롤로그가 끝나면 열림) |
| Tab | 인벤토리 (스킬 지정 · 무기 · 갑옷 · 아이템) |
| M | 지도 · 웨이스톤 순간이동 |
| E | 상호작용 (대화) |
| Esc | 일시정지 메뉴 (저장 · 불러오기 · 키 설정 · 타이틀로) |

## 개발

- Godot 4.7, 설계 문서는 [CLAUDE.md](CLAUDE.md)
- 테스트: `godot --headless --path . res://tests/test_runner.tscn`
- 스프라이트 다시 만들기: `python3 tools/sprite_gen.py`
- 바깥 세상 맵 다시 만들기: `python3 tools/build_world.py` (조각 맵 `levels/world/*.txt` + 스크립트 안의 배치 → `levels/areas/world.txt`, `data/areas/world.tres`)
- 효과음 다시 만들기: `python3 tools/sound_gen.py`
- Windows exe 만들기: `tools/build_story.sh` → `export/demo-story.exe` (Godot 4.7 과 Windows 내보내기 템플릿 필요. 내보내기만 하고 어디에도 올리지 않는다)
- `tools/publish.sh` 등 배포 스크립트는 main(스피드런판) 전용이라 이 브랜치에서는 실행되지 않는다
