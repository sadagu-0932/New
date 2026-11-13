extends Node
## 이벤트 버스 (오토로드 Events).
## 시스템끼리 서로를 직접 참조하지 않고 여기 시그널로만 연결한다.

@warning_ignore_start("unused_signal")

# --- 런 ---
## 새 런(판) 시작 (처음 시작·재시작 모두)
signal run_started()
## 일시정지 켜짐/꺼짐
signal pause_changed(paused: bool)
## 출발: 런 시작 후 첫 조작 입력 = 타이머 시작. 이후 스킬 변경 불가
signal clock_started()

# --- 플레이어 ---
## 플레이어가 생성됨 (재시작하면 새 플레이어)
signal player_spawned(player: Node2D)
## 플레이어가 회피를 시작함
signal player_dodged(player: Node2D)
## 탄약 수가 바뀜
signal ammo_changed(current: int, maximum: int)
## 체력이 바뀜
signal player_hp_changed(current: int, maximum: int)
## 플레이어가 쐈음
signal player_shot()
## 탄약이 없는데 사격을 눌렀음
signal ammo_empty()
## 근접 공격 시작
signal melee_started()
## 근접으로 적을 맞힘 (맞힌 수)
signal melee_hit(count: int)
## 패링 성공 (perfect = 완벽 패링)
signal parried(perfect: bool)
## 완벽 회피 성공
signal perfect_dodge()
## 투명 상태 시작/끝
signal stealth_changed(active: bool)
## 플레이어가 맞음 (데미지가 들어간 경우만)
signal player_hit(hit: HitInfo)
## 플레이어 사망
signal player_died()
## (숨은 테크) 은신 처형 / 반사탄 재패링(단계) / 돌진 베기 / 콤보 단계 변화 — UI 에 숫자·문구로 보이지 않는다
signal executed()
signal reparried(chain: int)
signal dash_slashed()
signal combo_changed(stage: int)
## 스킬 사용 (스킬 id)
signal skill_used(skill_id: String)
## 장착 스킬이 바뀜 (출발 전 Tab 설정)
signal skill_changed(skill_id: String)

# --- 튜토리얼·레벨 ---
## 구간 입장 (1~7). 스플릿 지점
signal section_entered(index: int)
## 하단 안내 문구 바뀜 (빈 문자열 = 숨김)
signal hint_changed(text: String)
## 구간의 문이 열림
signal gate_opened(section: int)
## 수정 스위치가 켜짐
signal switch_activated(switch: Node2D)
## 스토리 트리거 발동 (데모에서는 비활성이라 발생하지 않음)
signal story_triggered(story_id: String)

# --- 보스 ---
## 보스가 깨어남
signal boss_started(boss: Node2D)
signal boss_hp_changed(current: int, maximum: int)
## 보스가 다음 페이즈로 넘어감 (페이즈 번호)
signal boss_phase_changed(phase: int)
## 보스 그로기 시작
signal boss_groggy()
## 보스 1페이즈 격파 (타이머 정지)
signal boss_defeated(boss: Node2D)
## 스토리판: 골렘이 2페이즈에서 완전히 무너짐
signal boss_collapsed(boss: Node2D)
## 데모 끝 (2페이즈 시작 컷씬 종료) → 기록 화면
signal demo_finished()
## 스토리판: 프롤로그 끝 (골렘 컷씬의 "한나절 뒤" 암전까지 끝남) → 1지역으로
signal prologue_finished()
## 스토리판: 죽은 뒤 마지막 저장 지점에서 부활 요청
signal story_respawn_requested()
## 스토리 지역에 들어옴 (지역 id)
signal area_entered(area_id: String)
## 구역에 들어섬 (구역 id, 들판이면 "")
signal zone_entered(zone_id: String)
## 지역 출입구를 밟음 (AreaExitData)
signal area_exit_entered(exit: Resource)
## 비활성 웨이스톤에 닿음 (Waystone 노드)
signal waystone_touched(waystone: Node2D)
## 아이템을 주움
signal item_picked(item_id: String)
## 대사창 요청 (말하는 이, 대사 목록) / 대사가 끝남
signal dialogue_requested(speaker: String, lines: Array)
signal dialogue_finished()
## 자료(문서)를 읽음
signal document_read(item_id: String)
## 벽(나무)을 베어 냄 (칸)
signal wall_broken(cell: Vector2i)
## 인벤토리 내용이 바뀜 (획득·사용·장착·스킬 지정)
signal inventory_changed()
## 장착 무기·갑옷이나 지정 스킬이 바뀜 → 플레이어가 전투 수치를 다시 읽는다
signal loadout_changed()
## 화면 오른쪽 위에 잠깐 뜨는 알림 글 (저장됨 등)
signal toast(text: String)
## 리플레이(어트랙트) 재생이 끝남 → 타이틀로
signal replay_finished()
## 타이틀로 돌아가기 요청
signal return_to_title()
## 런 결과 확정 (기록 화면이 받아서 보여준다)
signal run_finished(result: RefCounted)
## 구간 스플릿 (구간 k 입장 시점의 누적 틱)
signal split_recorded(section: int, ticks: int)

# --- 적 ---
## 적이 맞음
signal enemy_damaged(enemy: Node2D, hit: HitInfo)
## 적이 죽음
signal enemy_died(enemy: Node2D)

# --- 디버그 ---
## 디버그: 구간 이동 요청 (delta = -1 이전 구간, +1 다음 구간)
signal debug_section_step(delta: int)
## 디버그: 히트박스 표시·무적 등 플래그가 바뀜
signal debug_flags_changed()

@warning_ignore_restore("unused_signal")
