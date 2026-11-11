# 효과음

`python3 tools/sound_gen.py` 가 여기에 `<슬롯 이름>.wav` 를 만든다 (다시 실행하면 같은 결과).
소리를 바꾸려면 `tools/sound_gen.py` 의 수치를, 크기는 `data/audio.tres` 를 고친다.
직접 만든 소리로 바꾸려면 같은 이름의 wav 로 덮어쓰면 된다. 파일이 없는 슬롯은 무음.

슬롯 목록과 울리는 때는 `core/audio_manager.gd` 참고.
