extends Node
## 데이터 저장소 (오토로드 DB).
## 모든 수치는 res://data/*.tres 에 있고, 코드는 여기서만 꺼내 쓴다.
## 수치를 바꿀 때는 data/ 파일만 고치면 된다.

var game_config: GameConfig = preload("res://data/game_config.tres")
var player: PlayerData = preload("res://data/player.tres")
var dodge: DodgeData = preload("res://data/dodge.tres")
var theme: ThemeData = preload("res://data/theme.tres")
