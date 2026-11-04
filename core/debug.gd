extends Node
## 디버그 기능 (오토로드 Debug). 디버그 빌드에서만 켜진다 (부스용 릴리스 exe에서는 꺼짐).
## F1 히트박스 표시 / F2 무적 / F3·F4 이전·다음 구간으로 이동

var enabled: bool = false
var show_hitboxes: bool = false
var god_mode: bool = false


func _ready() -> void:
	enabled = OS.is_debug_build()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event.is_action_pressed("debug_hitboxes"):
		show_hitboxes = not show_hitboxes
		Events.debug_flags_changed.emit()
	elif event.is_action_pressed("debug_god"):
		god_mode = not god_mode
		Events.debug_flags_changed.emit()
	elif event.is_action_pressed("debug_prev_section"):
		Events.debug_section_step.emit(-1)
	elif event.is_action_pressed("debug_next_section"):
		Events.debug_section_step.emit(1)
