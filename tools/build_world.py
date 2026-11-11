#!/usr/bin/env python3
"""스토리판의 바깥 세상(한 장으로 이어진 맵)을 만든다.

  levels/world/*.txt  (조각 맵: 연구소·광산촌·숲·골렘 터)  +  이 파일의 배치·설정
      →  levels/areas/world.txt   (이어 붙인 큰 맵)
      →  data/areas/world.tres    (구역·웨이스톤·획득물·주민·표지판 데이터)

조각 사이의 땅은 들판(풀밭 + 나무 무리)으로 채우고 길을 터 준다. 랜덤은 고정 시드 → 다시 실행하면 같은 결과.
world.txt·world.tres 는 직접 고치지 말고 조각 맵이나 이 파일을 고친 뒤 다시 실행한다:  python3 tools/build_world.py
"""
from __future__ import annotations

import collections
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
W, H = 164, 44
SEED = 20261111

# 조각: 이름 → (왼쪽 위 칸, 테두리 벽을 걷어낼지)
PIECES = {
    "lab": ((4, 4), False),        # 건물이라 벽을 그대로 둔다 (부서진 벽 = 출구)
    "village": ((48, 14), True),   # 열린 마을: 테두리를 걷어낸다
    "forest": ((94, 20), False),   # 나무는 벨 수 있으니 그대로
    "golem_lair": ((140, 8), False),
}

# 구역 설정 (rect 는 조각 크기에서 자동으로 채운다)
ZONES = {
    "lab": dict(name="연구소", tileset="tiles_lab", breakable=False, enter="lab_wake",
                floor="Color(0.5, 0.52, 0.62, 1)", wall="Color(0.22, 0.22, 0.32, 1)"),
    "village": dict(name="마석 광산촌", tileset="tiles_village", breakable=False, enter="village_enter",
                    floor="Color(0.62, 0.45, 0.3, 1)", wall="Color(0.48, 0.17, 0.27, 1)"),
    "forest": dict(name="외곽 숲", tileset="tiles_forest", breakable=True, enter="forest_enter",
                   floor="Color(0.3, 0.52, 0.32, 1)", wall="Color(0.13, 0.27, 0.2, 1)",
                   overrides={"C": "charger_forest", "S": "shooter_forest", "B": "spreader_forest"}),
    "golem_lair": dict(name="골렘 터", tileset="tiles_forest", breakable=True, enter="lair_enter",
                       floor="Color(0.36, 0.5, 0.34, 1)", wall="Color(0.13, 0.27, 0.2, 1)",
                       boss=True, boss_flag="golem_destroyed", overrides={"Z": "golem_worn"}),
}

# 조각 안의 소품 설정 (조각 맵에서 읽는 순서대로)
WAYSTONES = {
    "lab": [dict(id="lab_exit", name="연구소 탑")],
    "village": [dict(id="village", name="광산촌 탑")],
    "forest": [dict(id="forest_gate", name="숲 입구 탑"),
               dict(id="boss_gate", name="골렘 터 앞 탑", reveals=["forest", "golem_lair"])],
}
PICKUPS = {
    "lab": ["rapid_gun", "lab_memo"],
    "village": ["light_wrap", "mana_shard", "plated_coat"],
    "forest": ["scrap", "heavy_gun"],
}
SIGNS = {
    "lab": ["실험동 B · 격리 구역\n출입 금지"],
    "village": ["동쪽 숲길 — 갱도 가는 길"],
    "forest": ["이 앞, 큰 것이 지나간 자리"],
}
NPCS = {
    "village": [
        dict(id="miner", name="늙은 광부", sprite="npc_a",
             lines=["…거기 서라.", "그 옷. 언덕 위 연구소 것이지.", "뭘 하는 곳인지는 모른다. 알고 싶지도 않고.",
                    "볼일 없으면 마을에 오래 머물지 마라."],
             alt_flag="golem_destroyed", alt=["숲이 조용해졌더군.", "…네가 한 거냐. 고맙다는 말은 해 두지."]),
        dict(id="homeless", name="집 잃은 주민", sprite="npc_c",
             lines=["지붕째 뜯겨 나갔어.", "돌덩이 같은 게 걸어가더라고. 숲 쪽으로.", "지나간 자리마다 저 꼴이야."]),
        dict(id="child", name="아이", sprite="npc_b",
             lines=["우와, 총이다! 진짜야?", "어디서 왔어? 위쪽 큰 건물?", "거기 뭐가 있어? 어른들은 아무도 안 알려 줘."],
             alt_flag="golem_destroyed", alt=["큰 돌덩이 이제 안 와? 진짜?", "…고마워. 근데 조금 무서워."]),
        dict(id="afraid", name="겁먹은 주민", sprite="npc_a",
             lines=["가, 가까이 오지 마…!", "어젯밤 그 커다란 것도 그쪽에서 내려왔어.",
                    "집이 세 채나… 그건 숲으로 갔어. 따라가지 마."]),
    ],
}
# 들판에 따로 놓는 획득물 (칸, 아이템 id)
FIELD_PICKUPS = [((62, 9), "miner_cap"), ((44, 30), "work_pants"), ((112, 37), "sight_band"), ((127, 12), "padded_pants")]
# 세계의 끝: 3지역으로 가는 길 (북쪽 테두리). 골렘의 자료를 읽어야 열린다
END_EXIT = dict(cell=(149, 0), flag="read:golem_record", locked="아직 떠날 수 없다. 저것을 그냥 두고는.",
                end="3지역으로 가는 길\n\n이번 이야기는 여기까지")
# 나무를 치워 길을 터 줄 곳 (꺾이는 점들을 잇는다, 폭 3칸)
PATHS = [
    [(40, 15), (46, 15), (46, 23), (48, 23)],          # 연구소의 부서진 벽 → 광산촌
    [(87, 23), (91, 23), (91, 25), (94, 25)],          # 광산촌 → 숲
    [(137, 25), (138, 25), (138, 19), (140, 19)],      # 숲 → 골렘 터
    [(149, 9), (149, 1)],                              # 골렘 터 → 북쪽 길
]


def read_piece(name: str) -> list[str]:
    rows = []
    for line in (ROOT / "levels" / "world" / f"{name}.txt").read_text(encoding="utf-8").split("\n"):
        if line.startswith(";") or not line.strip():
            continue
        rows.append(line)
    assert len({len(r) for r in rows}) == 1, f"{name}: 줄 길이가 다름"
    return rows


def main() -> None:
    rng = random.Random(SEED)
    grid = [["." for _ in range(W)] for _ in range(H)]
    # 세계 테두리: 두 겹 나무 (맨 바깥은 벨 수 없다)
    for y in range(H):
        for x in range(W):
            if x < 2 or y < 2 or x >= W - 2 or y >= H - 2:
                grid[y][x] = "#"

    rects: dict[str, tuple[int, int, int, int]] = {}
    pieces = {name: read_piece(name) for name in PIECES}
    for name, ((ox, oy), _strip) in PIECES.items():
        rows = pieces[name]
        rects[name] = (ox, oy, len(rows[0]), len(rows))

    def in_any_rect(x: int, y: int, grow: int = 0) -> bool:
        return any(ox - grow <= x < ox + w + grow and oy - grow <= y < oy + h + grow for ox, oy, w, h in rects.values())

    # 들판의 나무 무리 (조각과 2칸 이상 떨어뜨린다)
    for _ in range(150):
        cx, cy = rng.randrange(3, W - 3), rng.randrange(3, H - 3)
        r = rng.choice((1, 1, 2, 2, 3))
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + rng.randrange(0, 2) \
                        and 2 <= x < W - 2 and 2 <= y < H - 2 and not in_any_rect(x, y, 2):
                    grid[y][x] = "#"

    # 소품: (y, x) → (글자, 설정)
    props: dict[tuple[int, int], tuple[str, object]] = {}
    for name, ((ox, oy), strip) in PIECES.items():
        rows = pieces[name]
        h, w = len(rows), len(rows[0])
        counts: collections.Counter = collections.Counter()
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                gx, gy = ox + x, oy + y
                border = x == 0 or y == 0 or x == w - 1 or y == h - 1
                if ch in "E1234567":
                    ch = "."          # 한 장으로 이어지므로 출입구·도착 지점은 그냥 길
                elif ch == "P" and name != "lab":
                    ch = "."
                elif ch == "#" and strip and border:
                    ch = "."
                if ch in "Y$IN":
                    table = {"Y": WAYSTONES, "$": PICKUPS, "I": SIGNS, "N": NPCS}[ch]
                    props[(gy, gx)] = (ch, table[name][counts[ch]])
                    counts[ch] += 1
                grid[gy][gx] = ch

    # 길 트기
    for path in PATHS:
        for (x0, y0), (x1, y1) in zip(path, path[1:]):
            for x in range(min(x0, x1), max(x0, x1) + 1):
                for y in range(min(y0, y1), max(y0, y1) + 1):
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            cx, cy = x + dx, y + dy
                            if 1 <= cx < W - 1 and 1 <= cy < H - 1 and grid[cy][cx] == "#" and not in_any_rect(cx, cy):
                                grid[cy][cx] = "."
                    if grid[y][x] == "#" and 0 < y < H - 1:
                        grid[y][x] = "."
    for (x, y), item in FIELD_PICKUPS:
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if grid[y + dy][x + dx] == "#":
                    grid[y + dy][x + dx] = "."
        grid[y][x] = "$"
        props[(y, x)] = ("$", item)
    ex, ey = END_EXIT["cell"]
    grid[ey][ex] = "E"
    grid[ey + 1][ex] = "."
    props[(ey, ex)] = ("E", END_EXIT)

    rows_out = ["".join(r) for r in grid]
    # 걸어서 닿는지 확인 (나무는 벨 수 있지만, 베지 않고도 주요 지점에 닿아야 한다)
    start = next((x, y) for y, r in enumerate(rows_out) for x, ch in enumerate(r) if ch == "P")
    seen = {start}
    queue = collections.deque([start])
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and (nx, ny) not in seen and rows_out[ny][nx] not in "#RNY~":
                seen.add((nx, ny))
                queue.append((nx, ny))
    for (y, x), (ch, _cfg) in props.items():
        near = [(x, y), (x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
        assert any(p in seen for p in near), f"닿을 수 없는 소품 {ch} @ {(x, y)}"
    for y, r in enumerate(rows_out):
        for x, ch in enumerate(r):
            if ch in "CcSBZ":
                assert (x, y) in seen, f"닿을 수 없는 적 {ch} @ {(x, y)}"

    header = ("; 바깥 세상 — 연구소·광산촌·외곽 숲·골렘 터가 한 장으로 이어진 맵 (tools/build_world.py 가 만든다. 직접 고치지 말 것)\n"
              "; 조각 맵은 levels/world/*.txt, 배치·설정은 tools/build_world.py\n")
    (ROOT / "levels" / "areas" / "world.txt").write_text(header + "\n".join(rows_out) + "\n", encoding="utf-8")

    # ---- world.tres ----
    def esc(t: str) -> str:
        return t.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

    def arr(xs) -> str:
        return ", ".join('"%s"' % esc(x) for x in xs)

    ordered = sorted(props.items())
    subs = ""
    refs: dict[str, list[str]] = {"E": [], "Y": [], "N": [], "zone": []}
    pickups: list[str] = []
    signs: list[str] = []
    for i, ((_y, _x), (ch, cfg)) in enumerate(ordered):
        if ch == "$":
            pickups.append(cfg)
        elif ch == "I":
            signs.append(cfg)
        elif ch == "E":
            subs += (f'[sub_resource type="Resource" id="exit_{i}"]\nscript = ExtResource("exit")\ntarget_area = ""\n'
                     f'target_spawn = 0\nrequired_flag = "{cfg["flag"]}"\nlocked_text = "{esc(cfg["locked"])}"\n'
                     f'end_text = "{esc(cfg["end"])}"\n\n')
            refs["E"].append(f'SubResource("exit_{i}")')
        elif ch == "Y":
            subs += (f'[sub_resource type="Resource" id="way_{i}"]\nscript = ExtResource("way")\nid = "{cfg["id"]}"\n'
                     f'display_name = "{cfg["name"]}"\nreveals = Array[String]([{arr(cfg.get("reveals", []))}])\n\n')
            refs["Y"].append(f'SubResource("way_{i}")')
        elif ch == "N":
            subs += (f'[sub_resource type="Resource" id="npc_{i}"]\nscript = ExtResource("npc")\nid = "{cfg["id"]}"\n'
                     f'display_name = "{cfg["name"]}"\nsprite = &"{cfg["sprite"]}"\n'
                     f'lines = Array[String]([{arr(cfg["lines"])}])\nalt_flag = "{cfg.get("alt_flag", "")}"\n'
                     f'alt_lines = Array[String]([{arr(cfg.get("alt", []))}])\n\n')
            refs["N"].append(f'SubResource("npc_{i}")')
    for name, z in ZONES.items():
        ox, oy, w, h = rects[name]
        ov = z.get("overrides")
        ov_text = "{\n" + ",\n".join(f'"{k}": "{v}"' for k, v in ov.items()) + "\n}" if ov else "{}"
        subs += (f'[sub_resource type="Resource" id="zone_{name}"]\nscript = ExtResource("zone")\nid = "{name}"\n'
                 f'display_name = "{z["name"]}"\nrect = Rect2i({ox}, {oy}, {w}, {h})\ntileset = "{z["tileset"]}"\n'
                 f'breakable_walls = {"true" if z["breakable"] else "false"}\n'
                 f'is_boss_room = {"true" if z.get("boss") else "false"}\nboss_cleared_flag = "{z.get("boss_flag", "")}"\n'
                 f'enter_story_id = "{z["enter"]}"\nenemy_overrides = {ov_text}\n'
                 f'map_floor_color = {z["floor"]}\nmap_wall_color = {z["wall"]}\n\n')
        refs["zone"].append(f'SubResource("zone_{name}")')
    (ROOT / "data" / "areas" / "world.tres").write_text(f'''[gd_resource type="Resource" script_class="AreaData" format=3]

[ext_resource type="Script" path="res://story/area_data.gd" id="area"]
[ext_resource type="Script" path="res://story/area_exit_data.gd" id="exit"]
[ext_resource type="Script" path="res://story/waystone_data.gd" id="way"]
[ext_resource type="Script" path="res://story/npc_data.gd" id="npc"]
[ext_resource type="Script" path="res://story/zone_data.gd" id="zone"]

{subs}[resource]
script = ExtResource("area")
id = "world"
display_name = "들판"
map_file = "res://levels/areas/world.txt"
tileset = "tiles_forest"
on_map = true
zones = Array[ExtResource("zone")]([{", ".join(refs["zone"])}])
map_floor_color = Color(0.36, 0.56, 0.36, 1)
map_wall_color = Color(0.16, 0.32, 0.22, 1)
breakable_walls = true
break_hits = 2
break_drop_item = "wood"
enemy_overrides = {{}}
exits = Array[ExtResource("exit")]([{", ".join(refs["E"])}])
waystones = Array[ExtResource("way")]([{", ".join(refs["Y"])}])
pickups = Array[String]([{arr(pickups)}])
npcs = Array[ExtResource("npc")]([{", ".join(refs["N"])}])
signs = Array[String]([{arr(signs)}])
''', encoding="utf-8")
    print(f"세계 생성 완료: {W}×{H}칸, 소품 {len(props)}개, 구역 {len(ZONES)}개")


if __name__ == "__main__":
    main()
