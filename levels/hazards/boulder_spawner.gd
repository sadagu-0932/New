class_name BoulderSpawner
extends Node2D
## 바위 발사기. 고정 주기로 아래쪽으로 바위를 굴린다 (맵 글자 'O').
## 주기는 게임 틱 기준이라 매 판 같다 → 경로·타이밍을 외울 수 있다.

var direction: Vector2 = Vector2.DOWN
## 칸 x 좌표 (발사기마다 시작 시점을 어긋나게)
var column: int = 0
var data: BoulderData


func setup_from_map(_ch: String, cell: Vector2i) -> void:
	column = cell.x


func _ready() -> void:
	data = DB.boulder


func _physics_process(_delta: float) -> void:
	if posmod(Game.tick + column * data.phase_per_column, data.interval_ticks) != 0:
		return
	var b := Boulder.new()
	b.data = data
	b.velocity = direction * data.speed
	b.position = position
	get_parent().add_child(b)
