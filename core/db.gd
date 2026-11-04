extends Node
## 데이터 저장소 (오토로드 DB).
## 모든 수치는 res://data/*.tres 에 있고, 코드는 여기서만 꺼내 쓴다.
## 수치를 바꿀 때는 data/ 파일만 고치면 된다.

var game_config: GameConfig = preload("res://data/game_config.tres")
var player: PlayerData = preload("res://data/player.tres")
var dodge: DodgeData = preload("res://data/dodge.tres")
var gun: GunData = preload("res://data/gun.tres")
var melee: MeleeData = preload("res://data/melee.tres")
var parry: ParryData = preload("res://data/parry.tres")
var stealth: StealthData = preload("res://data/stealth.tres")
var target_dummy: TargetDummyData = preload("res://data/props/target_dummy.tres")
var test_turret: TestTurretData = preload("res://data/props/test_turret.tres")
var theme: ThemeData = preload("res://data/theme.tres")
