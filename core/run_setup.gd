class_name RunSetup
extends RefCounted
## 한 판(런)의 시작 조건. 런은 이것만 받아 독립적으로 돌아간다.
## 결과는 RunController 가 RunResult 로 만들어 Events.run_finished 로 내보낸다

var seed_value: int = 0
var map_path: String = ""
## 있으면 튜토리얼로 시작 (map_path 무시)
var tutorial: TutorialData
## 장착 스킬 (재시작해도 유지)
var skill: SkillData


static func from_config(config: GameConfig) -> RunSetup:
	var s := RunSetup.new()
	s.seed_value = config.run_seed
	s.map_path = config.start_map_path
	s.skill = DB.skill_by_id(config.default_skill_id)
	if config.use_tutorial:
		s.tutorial = config.tutorial
	return s
