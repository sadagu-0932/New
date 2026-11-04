extends Node
## 이벤트 버스 (오토로드 Events).
## 시스템끼리 서로를 직접 참조하지 않고 여기 시그널로만 연결한다.

@warning_ignore_start("unused_signal")

## 플레이어가 회피를 시작함
signal player_dodged(player: Node2D)

## 디버그: 구간 이동 요청 (delta = -1 이전 구간, +1 다음 구간)
signal debug_section_step(delta: int)

## 디버그: 히트박스 표시·무적 등 플래그가 바뀜
signal debug_flags_changed()

@warning_ignore_restore("unused_signal")
