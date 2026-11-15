class_name TeleportFx
extends Node2D
## 웨이스톤 순간이동 연출 (화면 표시 전용, 시간은 게임 틱으로 센다). 위치 = 주인공 발밑.
##  떠날 때 (DEPART): 발밑에 캐릭터 크기의 작은 마법진이 그려진다 → 마법진이 몸을 따라 위로 올라가며 잔상을 남기고
##                    빛의 원통이 생긴다 (주인공은 빛에 물들며 원통 속으로 흐려진다, 불티가 떠오름)
##                    → 원통이 가늘어져 세로 빛줄기가 되어 위로 사라진다 (끝에 섬광)
##  도착할 때 (ARRIVE): 발밑에 마법진이 그려진다 → 세로 빛줄기가 위에서 내리꽂힌다 (땅에 닿을 때 빛 물결)
##                    → 원통으로 넓어지며 주인공이 나타난다 → 원통이 가루처럼 흩뿌려지며 사라진다
## 빛은 더하기 합성(겹칠수록 밝아짐) + 부드러운 후광. 단계별 길이·크기는 data/story.tres 의 teleport_* (색은 팔레트 색)

signal finished()

enum Mode { DEPART, ARRIVE }
enum Stage { CIRCLE, RISE, NARROW, LINE, WIDEN, SCATTER, DONE }

const COLOR_GLOW := Color("2f5f9a")
const COLOR_MID := Color("4fa3d8")
const COLOR_LIGHT := Color("9fe3f0")
const COLOR_CORE := Color("f2eff5")
## 마법진 둘레의 눈금 수 · 안쪽 별 꼭짓점 수
const TICKS := 12
const STAR_POINTS := 6
## 잔상을 남기는 간격 (틱)
const AFTERIMAGE_EVERY := 3
## 원통을 아래에서 위로 칠하는 띠 수 (위로 갈수록 옅어짐)
const BANDS := 8
## 원통 속을 흐르는 빛결 수
const STREAKS := 4

var mode: Mode = Mode.DEPART
var stage: Stage = Stage.CIRCLE
## 주인공 (떠날 때 빛에 물들며 흐려지고, 도착할 때 나타난다). 없어도 연출은 된다
var player: Node2D

var _t: int = 0
var _age: int = 0
var _len: int = 1
## 마법진이 지금 있는 높이 (발밑 0 → 머리 위 -height)
var _ring_y: float = 0.0
var _afterimages: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
## 연출용 랜덤 (게임 RNG 와 분리, 고정 시드)
var _rng := RandomNumberGenerator.new()

## 그리기 도우미가 그릴 층 (앞 층 = 자기 자신, 바닥 층 = _ground)
var _ci: CanvasItem = self
## 바닥 층 (레벨의 소품 층에 넣어 주인공보다 먼저 그린다)
var _ground: Node2D

## 부드러운 후광 그림 (가운데가 밝고 가장자리로 사라지는 원)
static var _glow_tex: GradientTexture2D


static func depart(who: Node2D) -> TeleportFx:
	var fx := TeleportFx.new()
	fx.mode = Mode.DEPART
	fx.player = who
	return fx


static func arrive(who: Node2D) -> TeleportFx:
	var fx := TeleportFx.new()
	fx.mode = Mode.ARRIVE
	fx.player = who
	return fx


static func glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 64
		_glow_tex.height = 64
	return _glow_tex


func _ready() -> void:
	_rng.seed = 7
	z_index = 20
	# 빛은 겹칠수록 밝아지게 (더하기 합성)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_make_ground(mat)
	if mode == Mode.ARRIVE:
		_set_player_look(0.0, 1.0)
	Audio.play("teleport_out" if mode == Mode.DEPART else "teleport_in")
	_enter(Stage.CIRCLE)


## 바닥 층: 레벨의 소품 층(주인공보다 먼저 그려짐)에 붙인다. 레벨 밖이면 자기 아래에 둔다
func _make_ground(mat: Material) -> void:
	_ground = GroundLayer.new()
	_ground.fx = self
	_ground.material = mat
	var level := get_parent().get_parent() as Level if get_parent() != null else null
	if level != null and level.props != null:
		level.props.add_child(_ground)
		_ground.global_position = global_position
	else:
		_ground.z_index = -1
		add_child(_ground)


func _exit_tree() -> void:
	if is_instance_valid(_ground) and _ground.get_parent() != self:
		_ground.queue_free()


## 바닥 층 그리기 노드
class GroundLayer extends Node2D:
	var fx: TeleportFx

	func _draw() -> void:
		if not is_instance_valid(fx):
			return
		fx._ci = self
		fx._draw_ground()
		fx._ci = fx


func _d() -> StoryData:
	return DB.story


func _enter(s: Stage) -> void:
	stage = s
	_t = 0
	match s:
		Stage.CIRCLE:
			_len = _d().teleport_circle_ticks
		Stage.RISE:
			_len = _d().teleport_rise_ticks
		Stage.NARROW:
			_len = _d().teleport_narrow_ticks
		Stage.LINE:
			_len = _d().teleport_line_ticks
		Stage.WIDEN:
			_len = _d().teleport_widen_ticks
		Stage.SCATTER:
			_len = _d().teleport_scatter_ticks
			_spawn_particles()
		Stage.DONE:
			_len = 1
	_len = maxi(_len, 1)


## 0~1 진행도
func _p() -> float:
	return clampf(float(_t) / float(_len), 0.0, 1.0)


func _physics_process(_delta: float) -> void:
	if stage == Stage.DONE:
		return
	_t += 1
	_age += 1
	var p := _p()
	match stage:
		Stage.RISE:
			_ring_y = -_d().teleport_height * _ease(p)
			if _t % AFTERIMAGE_EVERY == 0:
				_afterimages.append({"y": _ring_y, "a": 0.8})
			# 주인공은 빛에 물들며 원통 속으로 흐려진다
			_set_player_look(1.0 - p * 0.85, p)
			_spawn_sparks(2)
		Stage.NARROW:
			_set_player_look(0.15 * (1.0 - p), 1.0)
			_spawn_sparks(1)
		Stage.WIDEN:
			_set_player_look(p, 1.0 - p * 0.6)
			_spawn_sparks(2)
		Stage.SCATTER:
			_set_player_look(1.0, 0.4 * (1.0 - p))
			for pt in _particles:
				var v: Vector2 = pt["vel"]
				pt["prev"] = pt["pos"]
				pt["pos"] = (pt["pos"] as Vector2) + v
				v *= 0.93
				v.y -= 0.035
				pt["vel"] = v
	_tick_sparks()
	for a in _afterimages:
		a["a"] -= 0.035
	_afterimages = _afterimages.filter(func(a: Dictionary) -> bool: return a["a"] > 0.0)
	if _t >= _len:
		_next()
	queue_redraw()
	if is_instance_valid(_ground):
		_ground.queue_redraw()


func _next() -> void:
	match stage:
		Stage.CIRCLE:
			_enter(Stage.RISE if mode == Mode.DEPART else Stage.LINE)
		Stage.RISE:
			_enter(Stage.NARROW)
		Stage.NARROW:
			_set_player_look(0.0, 1.0)
			_finish()
		Stage.LINE:
			_enter(Stage.WIDEN)
		Stage.WIDEN:
			_enter(Stage.SCATTER)
		Stage.SCATTER:
			_finish()


func _finish() -> void:
	stage = Stage.DONE
	finished.emit()
	queue_free()


## 주인공 모습: alpha = 보이는 정도, glow = 빛에 물든 정도 (0 = 원래 색)
func _set_player_look(alpha: float, glow: float) -> void:
	if is_instance_valid(player):
		player.modulate = Color(1.0 + glow * 0.5, 1.0 + glow * 0.9, 1.0 + glow * 1.1, alpha)


static func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - x, 2.0)


func _spawn_particles() -> void:
	var r := _d().teleport_ring_radius
	var h := _d().teleport_height
	for i in _d().teleport_particles:
		var pos := Vector2(_rng.randf_range(-r, r), -_rng.randf_range(0.0, h))
		# 바깥으로 흩뿌려지고 조금 떠오른다
		var out := Vector2(signf(pos.x) if absf(pos.x) > 0.5 else _rng.randf_range(-1.0, 1.0), 0.0)
		var vel := (out * _rng.randf_range(0.3, 1.2) + Vector2(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.9, 0.1)))
		var colors := [COLOR_LIGHT, COLOR_CORE, COLOR_MID]
		_particles.append({"pos": pos, "prev": pos, "vel": vel, "c": colors[i % 3], "s": 2.0 if i % 4 == 0 else 1.0,
			"tw": _rng.randi_range(0, 7)})


## 원통 안에서 떠오르는 불티
func _spawn_sparks(n: int) -> void:
	var r := _d().teleport_ring_radius
	for i in n:
		_sparks.append({"pos": Vector2(_rng.randf_range(-r * 0.9, r * 0.9), _rng.randf_range(-3.0, 1.0)),
			"vy": -_rng.randf_range(0.6, 1.4), "life": _rng.randi_range(16, 28), "max": 28})


func _tick_sparks() -> void:
	for s in _sparks:
		s["pos"] = (s["pos"] as Vector2) + Vector2(sin(float(_age + int(s["life"])) * 0.4) * 0.15, float(s["vy"]))
		s["life"] = int(s["life"]) - 1
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return int(s["life"]) > 0)


# ---------------------------------------------------------------------------
# 그리기 (더하기 합성: 어두운 색은 옅게, 밝은 색은 빛나게 보인다)

## 바닥 층 (마법진·바닥 후광·빛 물결): 주인공보다 먼저(아래에) 그려진다 → 주인공이 마법진 위에 올라선다
func _draw_ground() -> void:
	var r := _d().teleport_ring_radius
	var p := _p()
	match stage:
		Stage.CIRCLE:
			# 발밑에 마법진이 한 바퀴 그려진다 (바닥이 먼저 은은하게 밝아짐)
			_draw_glow(Vector2.ZERO, Vector2(r * 2.6, r * 1.1), COLOR_MID, 0.5 * p)
			_draw_circle(Vector2.ZERO, r, p, 1.0)
		Stage.RISE:
			_draw_glow(Vector2.ZERO, Vector2(r * 2.8, r * 1.2), COLOR_MID, 0.55)
			_draw_circle(Vector2.ZERO, r, 1.0, 1.0 - p * 0.5)
		Stage.NARROW:
			_draw_glow(Vector2.ZERO, Vector2(r * 2.8, r * 1.2), COLOR_MID, 0.55 * (1.0 - p))
			_draw_circle(Vector2.ZERO, r, 1.0, 0.5 * (1.0 - p))
		Stage.LINE:
			_draw_glow(Vector2.ZERO, Vector2(r * 2.6, r * 1.1), COLOR_MID, 0.5)
			_draw_circle(Vector2.ZERO, r, 1.0, 1.0)
		Stage.WIDEN:
			_draw_glow(Vector2.ZERO, Vector2(r * 2.8, r * 1.2), COLOR_MID, 0.6)
			_draw_circle(Vector2.ZERO, r, 1.0, 1.0)
			_draw_shockwave(p)
		Stage.SCATTER:
			_draw_glow(Vector2.ZERO, Vector2(r * 2.8, r * 1.2), COLOR_MID, 0.6 * (1.0 - p))
			_draw_circle(Vector2.ZERO, r, 1.0, 1.0 - p)


## 앞 층 (오르는 마법진·잔상·원통·빛줄기·섬광·가루·불티): 주인공 앞에 그려진다
func _draw() -> void:
	var r := _d().teleport_ring_radius
	var h := _d().teleport_height
	var p := _p()
	match stage:
		Stage.RISE:
			_draw_cylinder(r, -_ring_y, p * 0.6)
			for a in _afterimages:
				_draw_ellipse_arc(Vector2(0, a["y"]), r, r * 0.4, 0.0, TAU, _with_a(COLOR_LIGHT, a["a"] * 0.5), 1.0)
			_draw_glow(Vector2(0, _ring_y), Vector2(r * 2.4, r * 1.0), COLOR_LIGHT, 0.45)
			_draw_circle(Vector2(0, _ring_y), r, 1.0, 1.0)
		Stage.NARROW:
			# 원통이 가늘어져 세로 빛줄기가 되고, 위로 길게 뻗으며 사라진다 (끝에 섬광)
			var w := lerpf(r, 0.6, _ease(p))
			var top := h + p * h * 2.0
			var fade := 1.0 - maxf(0.0, p - 0.75) / 0.25
			_draw_glow(Vector2(0, -top * 0.5), Vector2(w * 6.0 + 4.0, top * 1.1), COLOR_MID, 0.35 * fade)
			_draw_cylinder(w, top, 0.6 + 0.4 * p, fade)
			if p > 0.7:
				var f := (p - 0.7) / 0.3
				_draw_glow(Vector2(0, -h * 0.5), Vector2(r * 5.0, r * 5.0) * (0.6 + f), COLOR_CORE, 0.6 * (1.0 - f))
		Stage.LINE:
			# 도착: 세로 빛줄기가 위에서 내리꽂힌다 (밝은 머리)
			var head := -h * 3.0 * (1.0 - _ease(p))
			_draw_beam(head - h * 1.5, head, 1.0)
			_draw_glow(Vector2(0, head), Vector2(10, 10), COLOR_CORE, 0.8)
		Stage.WIDEN:
			# 빛줄기가 원통으로 넓어지며 주인공이 나타난다
			_draw_cylinder(lerpf(0.6, r, _ease(p)), h, 1.0 - p * 0.4)
		Stage.SCATTER:
			# 원통이 가루처럼 흩어진다
			_draw_cylinder(r, h, 0.6 * (1.0 - minf(p * 3.0, 1.0)))
			for pt in _particles:
				var c: Color = pt["c"]
				var twinkle := 0.6 + 0.4 * float((_age + int(pt["tw"])) % 4 < 2)
				var a := (1.0 - p) * twinkle
				var pos: Vector2 = pt["pos"]
				draw_line(pt["prev"], pos, _with_a(c, a * 0.4), 1.0)
				draw_rect(Rect2(pos.round(), Vector2.ONE * float(pt["s"])), _with_a(c, a))
	for s in _sparks:
		var life := float(s["life"]) / float(s["max"])
		draw_rect(Rect2((s["pos"] as Vector2).round(), Vector2.ONE), _with_a(COLOR_CORE, life))


## 부드러운 후광 (size = 지름)
func _draw_glow(center: Vector2, size: Vector2, color: Color, alpha: float) -> void:
	if alpha <= 0.0:
		return
	_ci.draw_texture_rect(glow_texture(), Rect2(center - size * 0.5, size), false, _with_a(color, alpha))


## 마법진: 바깥 고리 + 눈금 + 안쪽 고리 + 별(육각) + 가운데 점. fill 0~1 = 그려진 정도 (한 바퀴)
func _draw_circle(center: Vector2, r: float, fill: float, alpha: float) -> void:
	if alpha <= 0.0 or fill <= 0.0:
		return
	var spin := float(_age) * 0.06
	var pulse := 1.0 + 0.06 * sin(float(_age) * 0.35)
	var ro := r * pulse
	_draw_ellipse_arc(center, ro, ro * 0.4, spin, TAU * fill, _with_a(COLOR_MID, alpha), 1.0)
	_draw_ellipse_arc(center, ro * 1.12, ro * 0.45, spin, TAU * fill, _with_a(COLOR_GLOW, alpha * 0.7), 1.0)
	_draw_ellipse_arc(center, ro * 0.6, ro * 0.24, -spin * 1.5, TAU * fill, _with_a(COLOR_LIGHT, alpha), 1.0)
	# 바깥 고리의 눈금 (그려진 만큼만)
	for i in TICKS:
		var ang := spin + TAU * i / TICKS
		if ang - spin > TAU * fill:
			continue
		var a1 := _on_ellipse(center, ro * 0.88, ang)
		var a2 := _on_ellipse(center, ro * 1.0, ang)
		_ci.draw_line(a1, a2, _with_a(COLOR_LIGHT, alpha * 0.9), 1.0)
	# 안쪽 별 (반쯤 그려진 뒤부터 떠오른다)
	var star_a := alpha * clampf((fill - 0.4) / 0.6, 0.0, 1.0)
	if star_a > 0.0:
		var pts: Array[Vector2] = []
		for i in STAR_POINTS:
			pts.append(_on_ellipse(center, ro * 0.6, -spin * 1.5 + TAU * i / STAR_POINTS))
		for i in STAR_POINTS:
			_ci.draw_line(pts[i], pts[(i + 2) % STAR_POINTS], _with_a(COLOR_MID, star_a * 0.8), 1.0)
		_ci.draw_rect(Rect2(center.round() - Vector2(0.5, 0.5), Vector2.ONE), _with_a(COLOR_CORE, star_a))


## 빛의 원통: 반지름 w, 높이 top (발밑에서 위로). glow = 진하기, fade = 전체 보임 정도
func _draw_cylinder(w: float, top: float, glow: float, fade: float = 1.0) -> void:
	if glow <= 0.0 or top <= 0.0 or fade <= 0.0:
		return
	var a := glow * fade
	# 아래가 밝고 위로 갈수록 옅어지는 띠
	for i in BANDS:
		var y0 := -top * float(i) / BANDS
		var y1 := -top * float(i + 1) / BANDS
		var k := 1.0 - float(i) / BANDS
		_ci.draw_rect(Rect2(-w, y1, w * 2.0, y0 - y1), _with_a(COLOR_GLOW, a * 0.45 * k))
	# 위로 흐르는 빛결
	for i in STREAKS:
		var x := lerpf(-w * 0.7, w * 0.7, (float(i) + 0.5) / STREAKS)
		var flick := 0.5 + 0.5 * sin(float(_age) * 0.5 + i * 1.7)
		var seg := top * 0.35
		var off := fmod(float(_age) * 1.6 + i * 9.0, top + seg) - seg
		_ci.draw_line(Vector2(x, -off), Vector2(x, -minf(off + seg, top)), _with_a(COLOR_LIGHT, a * 0.5 * flick), 1.0)
	# 가운데 심
	_ci.draw_rect(Rect2(-maxf(w * 0.3, 0.5), -top, maxf(w * 0.6, 1.0), top), _with_a(COLOR_MID, a * 0.5))
	_ci.draw_rect(Rect2(-0.5, -top, 1.0, top), _with_a(COLOR_CORE, a * 0.9))
	if w > 1.5:
		# 원통 테두리 + 위로 훑어 올라가는 고리
		_ci.draw_line(Vector2(-w, 0), Vector2(-w, -top), _with_a(COLOR_LIGHT, a * 0.6), 1.0)
		_ci.draw_line(Vector2(w, 0), Vector2(w, -top), _with_a(COLOR_LIGHT, a * 0.6), 1.0)
		var scan := fmod(float(_age) * 1.2, top)
		_draw_ellipse_arc(Vector2(0, -scan), w, w * 0.4, 0.0, TAU, _with_a(COLOR_LIGHT, a * 0.5 * (1.0 - scan / top)), 1.0)
		_draw_ellipse_arc(Vector2(0, -top), w, w * 0.4, 0.0, TAU, _with_a(COLOR_MID, a * 0.4), 1.0)


## 내리꽂히는 빛줄기 (y_top ~ y_bottom)
func _draw_beam(y_top: float, y_bottom: float, alpha: float) -> void:
	var len := y_bottom - y_top
	_ci.draw_texture_rect(glow_texture(), Rect2(-4, y_top, 8, len), false, _with_a(COLOR_MID, alpha * 0.6))
	_ci.draw_rect(Rect2(-0.5, y_top, 1.0, len), _with_a(COLOR_CORE, alpha))


## 빛줄기가 땅에 닿을 때 퍼지는 빛 물결 (넓어지는 단계의 앞쪽)
func _draw_shockwave(p: float) -> void:
	var f := clampf(p / 0.7, 0.0, 1.0)
	if f >= 1.0:
		return
	var r := _d().teleport_ring_radius * (1.0 + f * 1.8)
	_draw_ellipse_arc(Vector2.ZERO, r, r * 0.4, 0.0, TAU, _with_a(COLOR_CORE, 1.0 - f), 1.0)
	_draw_glow(Vector2.ZERO, Vector2(r * 2.2, r), COLOR_LIGHT, 0.5 * (1.0 - f))


func _on_ellipse(center: Vector2, r: float, ang: float) -> Vector2:
	return center + Vector2(cos(ang) * r, sin(ang) * r * 0.4)


func _draw_ellipse_arc(center: Vector2, rx: float, ry: float, start: float, sweep: float, color: Color, width: float) -> void:
	if color.a <= 0.0:
		return
	var steps := maxi(int(28.0 * sweep / TAU), 2)
	var pts := PackedVector2Array()
	for i in steps + 1:
		var ang := start + sweep * float(i) / float(steps)
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	_ci.draw_polyline(pts, color, width)


static func _with_a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0))
