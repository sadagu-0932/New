class_name Ladder
extends Node2D
## 사다리 (맵 글자 'H'). 프롤로그(연구소 지하)와 바깥 세상의 연구소를 잇는다.
## - 프롤로그: 골렘 방 위쪽 벽에 걸린 쇠사다리. 골렘에게 쓰러졌다가 깨어난 뒤에만 오를 수 있다
##   (가까이서 E → Events.ladder_climbed → StoryMain 이 화면을 어둡게 했다가 바깥 세상 연구소에서 밝힌다)
##   그 전에는 오르라는 표시가 없다 (시험 중에는 그냥 벽의 사다리)
## - 바깥 세상: 연구소 바닥의 승강구 (지하에서 올라온 자리, 장식)

## 16×32 그림의 아래 칸이 이 칸에 오도록 위로 올리는 높이
const SPRITE_OFFSET := Vector2(0, -8)

## 오를 수 있는지 (프롤로그에서 깨어난 뒤 StoryMain 이 켠다)
var usable: bool = false

var _prompt: Label
var _is_hatch: bool = false


func _ready() -> void:
	var level := get_parent().get_parent() as Level
	_is_hatch = level != null and level.tutorial == null
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = DB.theme.load_sheet("basement_props")
	sprite.play(&"hatch" if _is_hatch else &"ladder")
	sprite.position = SPRITE_OFFSET
	add_child(sprite)
	_prompt = UiText.make_label()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-40, 4)
	_prompt.size = Vector2(80, 12)
	_prompt.z_index = 50
	_prompt.visible = false
	add_child(_prompt)


func _physics_process(_delta: float) -> void:
	if _is_hatch:
		return
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	var near := usable and player != null and not player.is_dead() and not player.cutscene_lock \
		and player.global_position.distance_to(global_position) <= DB.story.talk_radius
	if near != _prompt.visible:
		var key: String = str(DB.touch.text_map.get("E", "[사용]")) if TouchControls.is_enabled() else Settings.key_name(&"interact")
		_prompt.text = DB.story.text_climb % key
		_prompt.visible = near
	if near and PlayerInput.current.is_pressed(InputFrame.INTERACT):
		usable = false
		_prompt.visible = false
		player.set_cutscene_lock(true)
		Events.ladder_climbed.emit()
