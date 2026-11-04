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
var advanced: AdvancedTechData = preload("res://data/advanced_tech.tres")
var target_dummy: TargetDummyData = preload("res://data/props/target_dummy.tres")
var test_turret: TestTurretData = preload("res://data/props/test_turret.tres")
var crystal_switch: CrystalSwitchData = preload("res://data/props/crystal_switch.tres")
var spike: SpikeData = preload("res://data/hazards/spike.tres")
var boulder: BoulderData = preload("res://data/hazards/boulder.tres")
## 적 종류 이름 → 데이터 (맵 글자와의 연결은 Level.SPAWNS)
var enemies: Dictionary = {
	"charger": preload("res://data/enemies/charger.tres"),
	"charger_weak": preload("res://data/enemies/charger_weak.tres"),
	"shooter": preload("res://data/enemies/shooter.tres"),
	"spreader": preload("res://data/enemies/spreader.tres"),
	"golem": preload("res://data/bosses/golem.tres"),
}
## 스킬 목록 (스킬 설정 창에 이 순서로 나온다)
var skills: Array[SkillData] = [
	preload("res://data/skills/blink.tres"),
	preload("res://data/skills/absorb.tres"),
	preload("res://data/skills/decoy.tres"),
	preload("res://data/skills/shockwave.tres"),
	preload("res://data/skills/mark.tres"),
]
var audio: AudioData = preload("res://data/audio.tres")
var feel: FeelData = preload("res://data/feel.tres")
var theme: ThemeData = preload("res://data/theme.tres")


func skill_by_id(skill_id: String) -> SkillData:
	for s in skills:
		if s.id == skill_id:
			return s
	return skills[0] if not skills.is_empty() else null
