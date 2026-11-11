class_name Npc
extends StaticBody2D
## NPC (맵 글자 'N'). 가까이 가면 위에 "E 대화" 가 뜨고, 상호작용 키로 말을 건다 → Events.dialogue_requested.

var data: NpcData
var _sprite: AnimatedSprite2D
var _prompt: Label
var _cooldown: int = 0


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = DB.theme.load_sheet("story_props")
	_sprite.play(data.sprite if data != null and _sprite.sprite_frames.has_animation(data.sprite) else &"npc_a")
	add_child(_sprite)
	_prompt = UiText.make_label()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-40, -22)
	_prompt.size = Vector2(80, 12)
	_prompt.z_index = 50
	_prompt.visible = false
	add_child(_prompt)
	Events.dialogue_finished.connect(func() -> void: _cooldown = DB.story.talk_cooldown_ticks)


## 지금 할 말
func current_lines() -> Array[String]:
	if data == null:
		return []
	if not data.alt_flag.is_empty() and Story.has_flag(data.alt_flag) and not data.alt_lines.is_empty():
		return data.alt_lines
	return data.lines


func _physics_process(_delta: float) -> void:
	if _cooldown > 0:
		_cooldown -= 1
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	var near := player != null and not player.is_dead() and not player.cutscene_lock \
		and player.global_position.distance_to(global_position) <= DB.story.talk_radius
	if near != _prompt.visible:
		_prompt.text = "%s 대화" % (DB.touch.text_map.get("E", "[사용]") if TouchControls.is_enabled() else Settings.key_name(&"interact"))
		_prompt.visible = near
	if near:
		_sprite.flip_h = player.global_position.x < global_position.x
		if _cooldown <= 0 and PlayerInput.current.is_pressed(InputFrame.INTERACT) and not player.is_stealthed():
			Events.dialogue_requested.emit(data.display_name, current_lines())
