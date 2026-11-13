#!/usr/bin/env python3
"""스토리판의 바깥 세상(넓은 정사각형 한 장)을 만든다.

세상은 지역마다 땅 모습이 다르다 (숲·초원·호수·바위 언덕). 지역마다 지도를 여는 탑이 하나씩 있고,
탑과 탑은 흙길로 이어지며, 곳곳에 작은 볼거리(적 야영지·폐허·숨겨 둔 물건)가 흩어져 있다.

  levels/world/layout.json (크기·배치)  +  levels/world/*.txt (조각 맵: 연구소·광산촌·골렘 터)  +  이 파일의 설정
      →  levels/areas/world.txt          맵 글자
      →  levels/areas/world_ground.txt   칸마다 땅 종류 (g 숲·풀밭 / l 연구소 / v 마을 흙 / r 철길 / t 쓰러진 나무 길
                                           / w 물가 / m 바위 / p 흙길)
      →  levels/areas/world_regions.txt  칸마다 지역 번호 (0~9)
      →  data/areas/world.tres           지역·웨이스톤·획득물·주민·표지판 데이터

한가운데 연구소가 숲에 싸여 있다. 유일하게 뚫린 길인 철길이 (역시 숲에 싸인) 작고 둥근 광산촌으로 이어지고,
광산촌에서 쓰러진 나무가 이어진 길을 따라가면 골렘이 숨어 있던 터가 나온다.
지역은 네모가 아니라 구불구불한 경계로 나뉜다. 랜덤은 고정 시드 → 다시 실행하면 같은 결과.
결과 파일은 직접 고치지 말고 layout.json·조각 맵·이 파일을 고친 뒤 다시 실행한다:  python3 tools/build_world.py
"""
from __future__ import annotations

import collections
import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LAYOUT_FILE = ROOT / "levels" / "world" / "layout.json"
OUT = ROOT / "levels" / "areas"

# 땅 종류 → 타일 그림, 지도 색 (바닥 / 벽·나무·집)
GROUNDS = {
    "g": dict(tileset="tiles_forest", floor="Color(0.34, 0.55, 0.35, 1)", wall="Color(0.15, 0.3, 0.21, 1)"),
    "l": dict(tileset="tiles_lab", floor="Color(0.5, 0.52, 0.62, 1)", wall="Color(0.22, 0.22, 0.32, 1)"),
    "v": dict(tileset="tiles_village", floor="Color(0.62, 0.45, 0.3, 1)", wall="Color(0.48, 0.17, 0.27, 1)"),
    "r": dict(tileset="tiles_rail", floor="Color(0.55, 0.5, 0.45, 1)", wall="Color(0.15, 0.3, 0.21, 1)"),
    "t": dict(tileset="tiles_trail", floor="Color(0.5, 0.5, 0.3, 1)", wall="Color(0.15, 0.3, 0.21, 1)"),
    "w": dict(tileset="tiles_water", floor="Color(0.34, 0.55, 0.35, 1)", wall="Color(0.2, 0.42, 0.68, 1)"),
    "m": dict(tileset="tiles_rock", floor="Color(0.47, 0.55, 0.42, 1)", wall="Color(0.42, 0.4, 0.46, 1)"),
    "p": dict(tileset="tiles_path", floor="Color(0.74, 0.6, 0.4, 1)", wall="Color(0.15, 0.3, 0.21, 1)"),
}
# 벽(나무)을 벨 수 있는 땅 종류 (바위·연구소 벽·마을 집은 못 벤다)
BREAKABLE = "grtpw"
# 묶음별 설정: 그 묶음의 모든 작은 지역에 적용되는 적 수치
# 골렘 이야기가 벌어지는 연구소 둘레의 세 묶음: 숲용 적 수치 + 다시 만나는 골렘
_GOLEM_STORY = dict(overrides={"C": "charger_forest", "S": "shooter_forest", "B": "spreader_forest", "Z": "golem_return"})
REGION_EXTRA = {"lab": _GOLEM_STORY, "village": _GOLEM_STORY, "golem": _GOLEM_STORY}
# 작은 지역에 처음 들어섰을 때 흘러가는 글 (data/story.tres 의 lines 키)
ZONE_ENTER = {"lab": "lab_wake", "village": "village_enter", "trail": "forest_enter", "golem_lair": "lair_enter"}
# 지역 맵의 글자 (작은 지역 번호 → 글자)
# (줄 맨 앞의 ; 는 주석으로 읽히므로 쓰지 않는다)
ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!@$%^&*()-_=+[]{}<>?/|~"
# 묶음의 주된 땅 모습 → 그 안의 작은 지역들이 가질 수 있는 땅 모습 (섞여서 지형이 다양해진다)
BIOME_MIX = {
    "forest": ["forest", "forest", "forest_thin", "plains"],
    "forest_thin": ["forest_thin", "forest_thin", "plains", "lake"],
    "plains": ["plains", "plains", "forest_thin", "lake"],
    "lake": ["lake", "lake", "plains", "forest_thin"],
    "rocky": ["rocky", "rocky", "plains", "forest_thin"],
}
# 임시 지명: 땅 모습마다 앞말 + 뒷말
NAME_PARTS = {
    "forest": (["이끼", "고요한", "검은", "안개", "늙은", "깊은", "그늘", "속삭이는", "젖은", "가시"], ["숲", "나무골", "숲길", "수풀", "숲터"]),
    "forest_thin": (["성긴", "볕 드는", "자작", "어린", "바람", "노란", "마른", "새소리"], ["숲", "나무밭", "덤불", "숲터", "잡목림"]),
    "plains": (["바람", "너른", "누런", "꽃", "이슬", "새벽", "메마른", "양치기", "긴 풀", "저녁"], ["초원", "들판", "벌", "둔덕", "풀밭"]),
    "lake": (["거울", "잔물결", "갈대", "푸른", "깊은", "낮은", "안개", "달빛", "고요한", "개구리"], ["호수", "못", "물가", "늪", "여울"]),
    "rocky": (["잿빛", "부서진", "매의", "칼날", "붉은", "메아리", "바람", "검은", "늑대", "천둥"], ["고원", "벼랑", "바위골", "언덕", "돌밭"]),
}


def make_name(biome: str, rng: random.Random, used: set[str]) -> str:
    """임시 지명을 하나 만든다 (겹치지 않게)."""
    heads, tails = NAME_PARTS[biome]
    for _ in range(200):
        name = f"{rng.choice(heads)} {rng.choice(tails)}"
        if name not in used:
            used.add(name)
            return name
    raise AssertionError("지명이 모자람")
# 조각 안의 소품 설정 (조각 맵에서 읽는 순서대로)
WAYSTONES = {
    "lab": [dict(id="lab_exit", name="연구소 탑")],
    "village": [dict(id="village", name="광산촌 탑")],
}
TRAIL_TOWER = dict(id="boss_gate", name="골렘 터 앞 탑")
PICKUPS = {
    "lab": ["rapid_gun", "lab_memo"],
    "village": ["light_wrap", "mana_shard", "plated_coat"],
}
SIGNS = {
    "lab": ["실험동 B · 격리 구역\n출입 금지"],
    "village": ["북쪽 숲 — 큰 것이 지나간 길"],
}
# 쓰러진 나무 길의 첫 막힌 곳 앞 표지판: 나무를 벨 수 있다는 것을 여기서 알려준다
CHOP_SIGN = "나무가 길을 막았다\n우클릭 근접 공격으로\n벨 수 있다"
NPCS = {
    "village": [
        dict(id="miner", name="늙은 광부", sprite="npc_miner",
             lines=["…거기 서라.", "그 옷. 숲 너머 연구소 것이지.", "뭘 하는 곳인지는 모른다. 알고 싶지도 않고.",
                    "볼일 없으면 마을에 오래 머물지 마라."],
             alt_flag="golem_destroyed", alt=["숲이 조용해졌더군.", "…네가 한 거냐. 고맙다는 말은 해 두지."]),
        dict(id="homeless", name="집 잃은 주민", sprite="npc_homeless",
             lines=["지붕째 뜯겨 나갔어.", "돌덩이 같은 게 걸어가더라고. 북쪽 숲으로.", "나무를 죄다 쓰러뜨리면서 갔어. 길이 났을 거야."]),
        dict(id="child", name="아이", sprite="npc_child",
             lines=["우와, 총이다! 진짜야?", "철길 따라왔어? 저쪽 큰 건물에서?", "거기 뭐가 있어? 어른들은 아무도 안 알려 줘."],
             alt_flag="golem_destroyed", alt=["큰 돌덩이 이제 안 와? 진짜?", "…고마워. 근데 조금 무서워."]),
        dict(id="afraid", name="겁먹은 주민", sprite="npc_afraid",
             lines=["가, 가까이 오지 마…!", "어젯밤 그 커다란 것도 철길 쪽에서 왔어.",
                    "집이 세 채나… 그건 북쪽 숲으로 갔어. 따라가지 마."]),
    ],
}

def read_piece(name: str) -> list[str]:
    rows = []
    for line in (ROOT / "levels" / "world" / f"{name}.txt").read_text(encoding="utf-8").split("\n"):
        if line.startswith(";") or not line.strip():
            continue
        rows.append(line)
    assert len({len(r) for r in rows}) == 1, f"{name}: 줄 길이가 다름"
    return rows


def _hash01(ix: int, iy: int, seed: int) -> float:
    h = (ix * 374761393 + iy * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def noise(x: float, y: float, scale: float, seed: int) -> float:
    """부드러운 값 잡음 0~1 (격자 랜덤을 매끄럽게 이은 것). 지형 무리를 만드는 데 쓴다."""
    fx, fy = x / scale, y / scale
    ix, iy = math.floor(fx), math.floor(fy)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a, b = _hash01(ix, iy, seed), _hash01(ix + 1, iy, seed)
    c_, d = _hash01(ix, iy + 1, seed), _hash01(ix + 1, iy + 1, seed)
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c_ * (1 - tx) + d * tx) * ty


def main() -> None:
    layout = json.loads(LAYOUT_FILE.read_text(encoding="utf-8"))
    N = int(layout["size"])
    seed = int(layout["seed"])
    rng = random.Random(seed)
    grid = [["."] * N for _ in range(N)]      # 기본은 풀밭
    ground = [["g"] * N for _ in range(N)]

    def cell(frac) -> tuple[int, int]:
        return min(max(round(frac[0] * N), 6), N - 7), min(max(round(frac[1] * N), 6), N - 7)

    def inside(x: int, y: int, edge: int = 2) -> bool:
        return edge <= x < N - edge and edge <= y < N - edge

    def wobble(x: int, y: int) -> float:
        """빈터 가장자리를 들쭉날쭉하게 (칸마다 0~1, 고정)."""
        return (math.sin(x * 0.9 + y * 0.37) + math.sin(y * 1.1 - x * 0.53) + 2.0) / 4.0

    # ---- 지역 나누기: 가장 가까운 지역 중심 + 구불구불하게 휜 경계 ----
    region_cfg = layout["regions"]
    seeds = [cell(r["at"]) for r in region_cfg]
    assert len(seeds) <= 10, "지역은 10개까지 (지역 번호가 한 글자)"
    ids = [r["id"] for r in region_cfg]
    regions = [["0"] * N for _ in range(N)]
    # 묶음(탑이 여는 덩어리)은 다각형에 가까운 단정한 모양이고, 경계만 살짝 구불거린다:
    # 세상 크기에 맞춘 느린 물결 + 몇 칸짜리 잔물결
    amp = N * 0.018
    k = math.tau / N
    for y in range(N):
        for x in range(N):
            ripple_x = (noise(x, y, 14.0, seed + 21) - 0.5) * 7.0
            ripple_y = (noise(x, y, 14.0, seed + 22) - 0.5) * 7.0
            wx = x + amp * math.sin(y * k * 3.0 + 1.3) + amp * 0.5 * math.sin(y * k * 5.0 + x * k * 2.0) + ripple_x
            wy = y + amp * math.sin(x * k * 3.0 + 0.7) + amp * 0.5 * math.sin(x * k * 5.0 + y * k * 2.0 + 2.0) + ripple_y
            regions[y][x] = str(min(range(len(seeds)), key=lambda i: (wx - seeds[i][0]) ** 2 + (wy - seeds[i][1]) ** 2))

    # ---- 조각 자리 ----
    pieces = {name: read_piece(name) for name in layout["pieces"]}
    rects: dict[str, tuple[int, int, int, int]] = {}
    for name, cfg in layout["pieces"].items():
        rows = pieces[name]
        w, h = len(rows[0]), len(rows)
        cx, cy = cell(cfg["center"])
        rects[name] = (min(max(cx - w // 2, 8), N - 8 - w), min(max(cy - h // 2, 8), N - 8 - h), w, h)
    names = list(rects)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            ax, ay, aw, ah = rects[a]
            bx, by, bw, bh = rects[b]
            assert ax + aw + 16 <= bx or bx + bw + 16 <= ax or ay + ah + 16 <= by or by + bh + 16 <= ay, \
                f"조각이 너무 가깝다: {a} · {b} (layout.json 의 center 나 size 를 조정)"

    def in_piece(x: int, y: int, grow: int = 0) -> str | None:
        for name, (ox, oy, w, h) in rects.items():
            if ox - grow <= x < ox + w + grow and oy - grow <= y < oy + h + grow:
                return name
        return None

    # 조각은 통째로 자기 지역에 들게 한다 (경계가 건물·마을과 그 둘레 숲을 가르지 않게)
    for name, region_id in (("lab", "lab"), ("village", "village"), ("golem_lair", "golem")):
        ox, oy, w, h = rects[name]
        key = str(ids.index(region_id))
        for y in range(oy - 14, oy + h + 14):
            for x in range(ox - 14, ox + w + 14):
                if 0 <= x < N and 0 <= y < N:
                    dx = max(ox - x, 0, x - (ox + w - 1))
                    dy = max(oy - y, 0, y - (oy + h - 1))
                    if math.hypot(dx, dy) <= 13:
                        regions[y][x] = key

    # ---- 묶음을 작은 지역들로 다시 나눈다 (탑은 묶음을 통째로 열고, 지도에는 작은 지역 이름이 적힌다) ----
    # zones: 작은 지역 목록, zmap: 칸 → zones 번호
    zones: list[dict] = []
    fixed_seeds = {
        "lab": [("lab", "연구소", (rects["lab"][0] + rects["lab"][2] // 2, rects["lab"][1] + rects["lab"][3] // 2))],
        "village": [("village", "마석 광산촌", (rects["village"][0] + rects["village"][2] // 2, rects["village"][1] + rects["village"][3] // 2))],
        "golem": [("golem_lair", "골렘 터", (rects["golem_lair"][0] + rects["golem_lair"][2] // 2, rects["golem_lair"][1] + rects["golem_lair"][3] // 2)),
                  ("trail", "쓰러진 나무 길", cell(layout["trail"]["bends"][1]))],
    }
    used_names: set[str] = {"연구소", "마석 광산촌", "골렘 터", "쓰러진 나무 길"}
    for i, r in enumerate(region_cfg):
        mine: list[dict] = []
        for zid, zname, zseed in fixed_seeds.get(r["id"], []):
            mine.append(dict(id=zid, name=zname, seed=zseed, biome="forest", fixed=True))
        cells_in = [(x, y) for y in range(4, N - 4, 3) for x in range(4, N - 4, 3) if regions[y][x] == str(i)]
        tries = 0
        while len(mine) < int(r.get("areas", 4)) and tries < 3000:
            tries += 1
            sx, sy = rng.choice(cells_in)
            if any(math.hypot(sx - z["seed"][0], sy - z["seed"][1]) < N * 0.085 for z in mine):
                continue
            b = rng.choice(BIOME_MIX[r.get("biome", "plains")])
            mine.append(dict(id=f"{r['id']}_{len(mine)}", name=make_name(b, rng, used_names), seed=(sx, sy), biome=b, fixed=False))
        for z in mine:
            z.update(group=r["id"], group_name=r["name"], province=i)
            zones.append(z)
    assert len(zones) <= len(ALPHABET), f"작은 지역이 너무 많다 ({len(zones)}개, {len(ALPHABET)}개까지)"
    by_province: dict[int, list[int]] = collections.defaultdict(list)
    for zi, z in enumerate(zones):
        by_province[z["province"]].append(zi)
    zmap = [[0] * N for _ in range(N)]
    amp2 = N * 0.012
    for y in range(N):
        for x in range(N):
            wx = x + amp2 * math.sin(y * k * 7.0 + 0.4) + (noise(x, y, 10.0, seed + 23) - 0.5) * 6.0
            wy = y + amp2 * math.sin(x * k * 7.0 + 2.2) + (noise(x, y, 10.0, seed + 24) - 0.5) * 6.0
            zmap[y][x] = min(by_province[int(regions[y][x])],
                             key=lambda zi: (wx - zones[zi]["seed"][0]) ** 2 + (wy - zones[zi]["seed"][1]) ** 2)
    zone_index = {z["id"]: zi for zi, z in enumerate(zones)}
    # 연구소·광산촌·골렘 터와 그 둘레 숲은 통째로 자기 지역
    for name, zid, reach in (("lab", "lab", 13), ("village", "village", 12), ("golem_lair", "golem_lair", 9)):
        ox, oy, w, h = rects[name]
        for y in range(oy - reach - 1, oy + h + reach + 1):
            for x in range(ox - reach - 1, ox + w + reach + 1):
                if 0 <= x < N and 0 <= y < N and math.hypot(max(ox - x, 0, x - (ox + w - 1)), max(oy - y, 0, y - (oy + h - 1))) <= reach:
                    zmap[y][x] = zone_index[zid]

    def biome(x: int, y: int) -> str:
        return zones[zmap[y][x]]["biome"]

    # ---- 바탕 지형: 지역의 땅 모습에 따라 나무·바위·물을 무리 지어 놓는다 ----
    lake_centers = [z["seed"] for z in zones if z["biome"] == "lake"]
    for y in range(N):
        for x in range(N):
            b = biome(x, y)
            trees = noise(x, y, 7.0, seed + 1) * 0.65 + noise(x, y, 3.0, seed + 2) * 0.35
            rocks = noise(x, y, 9.0, seed + 3) * 0.7 + noise(x, y, 4.0, seed + 4) * 0.3
            ponds = noise(x, y, 11.0, seed + 5)
            if b == "forest":
                if trees > 0.40:
                    grid[y][x] = "#"
            elif b == "forest_thin":
                if trees > 0.56:
                    grid[y][x] = "#"
                elif ponds > 0.80:
                    grid[y][x], ground[y][x] = "~", "w"
            elif b == "plains":
                if trees > 0.70:
                    grid[y][x] = "#"
                elif rocks > 0.80:
                    grid[y][x], ground[y][x] = "#", "m"
                elif ponds > 0.84:
                    grid[y][x], ground[y][x] = "~", "w"
            elif b == "rocky":
                if rocks > 0.52:
                    grid[y][x], ground[y][x] = "#", "m"
                elif rocks > 0.44:
                    ground[y][x] = "m"            # 바위 둘레의 자갈밭
                elif trees > 0.68:
                    grid[y][x] = "#"
            elif b == "lake":
                d = min(math.hypot((x - lx) * 0.8, y - ly) for lx, ly in lake_centers)
                if d < N * 0.055 + (noise(x, y, 6.0, seed + 6) - 0.5) * N * 0.05:
                    grid[y][x], ground[y][x] = "~", "w"
                elif ponds > 0.74:
                    grid[y][x], ground[y][x] = "~", "w"
                elif trees > 0.66:
                    grid[y][x] = "#"

    def set_floor(x: int, y: int, kind: str = "g") -> None:
        grid[y][x] = "."
        ground[y][x] = kind

    def rect_dist(name: str, x: int, y: int) -> float:
        ox, oy, w, h = rects[name]
        return math.hypot(max(ox - x, 0, x - (ox + w - 1)), max(oy - y, 0, y - (oy + h - 1)))

    # ---- 연구소: 풀밭 빈터 + 둘레를 빈틈없이 감싼 숲 ----
    ox, oy, w, h = rects["lab"]
    for y in range(oy - 16, oy + h + 16):
        for x in range(ox - 16, ox + w + 16):
            if not inside(x, y):
                continue
            d = rect_dist("lab", x, y)
            edge = 2.0 + wobble(x, y) * 2.5
            if d <= edge:
                set_floor(x, y)
            elif d <= edge + 8.0 + wobble(y, x) * 3.0:
                grid[y][x], ground[y][x] = "#", "g"
    # ---- 광산촌: 둥그스름한 흙바닥 + 둘레를 감싼 숲 ----
    vx, vy, vw, vh = rects["village"]
    vcx, vcy = vx + vw / 2 - 0.5, vy + vh / 2 - 0.5
    rx, ry = vw / 2 + 2.5, vh / 2 + 2.5

    def village_d(x: int, y: int) -> float:
        """마을 가운데에서의 거리 (1 = 흙바닥 가장자리). 살짝 찌그러진 둥근 모양."""
        ang = math.atan2(y - vcy, x - vcx)
        bump = 1.0 + 0.08 * math.sin(ang * 3 + 0.6) + 0.05 * math.sin(ang * 5 + 2.1)
        return math.hypot((x - vcx) / rx, (y - vcy) / ry) / bump

    for y in range(vy - 16, vy + vh + 16):
        for x in range(vx - 16, vx + vw + 16):
            if not inside(x, y):
                continue
            d = village_d(x, y)
            if d <= 1.0:
                set_floor(x, y, "v")
            elif d <= 1.0 + (7.0 + wobble(x, y) * 3.0) / rx:
                grid[y][x], ground[y][x] = "#", "g"
    # ---- 골렘 터: 빽빽한 숲 속에 숨은 빈터 ----
    gx0, gy0, gw, gh = rects["golem_lair"]
    for y in range(gy0 - 9, gy0 + gh + 9):
        for x in range(gx0 - 9, gx0 + gw + 9):
            if inside(x, y):
                grid[y][x], ground[y][x] = "#", "g"

    props: dict[tuple[int, int], tuple[str, object]] = {}
    gates: dict[tuple[str, str], tuple[int, int]] = {}
    landmarks: dict[str, tuple[int, int]] = {}
    piece_ground = {"lab": "l", "village": "v", "golem_lair": "g"}
    for name in rects:
        ox, oy, w, h = rects[name]
        rows = pieces[name]
        counts: collections.Counter = collections.Counter()
        opened: set[tuple[int, int]] = set()
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                px, py = ox + x, oy + y
                if ch == "E":
                    side, out = ("w", (px - 1, py)) if x == 0 else ("e", (px + 1, py)) if x == w - 1 \
                        else ("n", (px, py - 1)) if y <= 1 else ("s", (px, py + 1))
                    if side == "n" and y == 1:
                        opened.add((px, py - 1))
                        out = (px, py - 2)
                    gates[(name, side)] = out
                    ch = "."
                elif ch in "1234567":
                    ch = "."
                elif ch == "P" and name != "lab":
                    ch = "."
                if name == "village" and ch == ".":
                    continue              # 마을의 빈 땅은 둥근 흙바닥·둘레 숲 그대로
                if ch in "Y$IN":
                    table = {"Y": WAYSTONES, "$": PICKUPS, "I": SIGNS, "N": NPCS}[ch]
                    props[(py, px)] = (ch, table[name][counts[ch]])
                    counts[ch] += 1
                grid[py][px] = ch
                ground[py][px] = piece_ground[name]
        for px, py in opened:
            grid[py][px] = "."
    assert all(village_d(vx + x, vy + y) <= 1.0 for y, row in enumerate(pieces["village"]) for x, ch in enumerate(row) if ch != "."), \
        "마을의 집·주민이 둥근 흙바닥 밖으로 나감"

    def clear(x: int, y: int, kind: str | None = None, radius: int = 1) -> None:
        """길 한 칸: 둘레의 나무·바위·물을 치운다 (조각 안은 건드리지 않는다). kind 가 있으면 가운데 칸의 땅 종류를 바꾼다."""
        for dx in range(-radius, radius + 1):
            for dy in range(-radius, radius + 1):
                cx, cy = x + dx, y + dy
                if inside(cx, cy, 1) and grid[cy][cx] in "#~" and in_piece(cx, cy) is None:
                    grid[cy][cx] = "."
                    if ground[cy][cx] in "wm":
                        ground[cy][cx] = "g"
        if kind is not None and in_piece(x, y) is None and inside(x, y, 1):
            ground[y][x] = kind

    def line_cells(a: tuple[int, int], b: tuple[int, int], horizontal_first: bool) -> list[tuple[int, int]]:
        """a 에서 b 까지 ㄱ자로 이어지는 칸들."""
        (x0, y0), (x1, y1) = a, b
        out: list[tuple[int, int]] = []
        step_x = 1 if x1 >= x0 else -1
        step_y = 1 if y1 >= y0 else -1
        if horizontal_first:
            out += [(x, y0) for x in range(x0, x1 + step_x, step_x)]
            out += [(x1, y) for y in range(y0 + step_y, y1 + step_y, step_y)] if y0 != y1 else []
        else:
            out += [(x0, y) for y in range(y0, y1 + step_y, step_y)]
            out += [(x, y1) for x in range(x0 + step_x, x1 + step_x, step_x)] if x0 != x1 else []
        return out

    def step_cells(a: tuple[int, int], b: tuple[int, int]) -> list[tuple[int, int]]:
        """a 에서 b 까지 한 칸씩 이어지는 칸들 (가로·세로 걸음을 섞어 비스듬히 간다)."""
        x, y = a
        out = [(x, y)]
        total_x, total_y = abs(b[0] - x), abs(b[1] - y)
        err = 0
        while (x, y) != b:
            dx, dy = b[0] - x, b[1] - y
            # 남은 거리의 비율대로 가로·세로를 번갈아 걷는다
            if dx != 0 and (dy == 0 or err < 0 or (err == 0 and total_x >= total_y)):
                x += 1 if dx > 0 else -1
                err += total_y
            else:
                y += 1 if dy > 0 else -1
                err -= total_x
            out.append((x, y))
        return out

    def meander(a: tuple[int, int], b: tuple[int, int], sway: float, key: int) -> list[tuple[int, int]]:
        """a 에서 b 까지 구불구불 이어지는 칸들. sway = 곧은 선에서 옆으로 벗어나는 정도(칸)."""
        dist = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, int(dist / 12))
        nx, ny = (-(b[1] - a[1]) / dist, (b[0] - a[0]) / dist) if dist > 0 else (0.0, 0.0)
        pts = [a]
        for i in range(1, n):
            t = i / n
            off = (noise(i * 0.9, key * 7.3, 1.0, seed + 60 + key) - 0.5) * 2.0 * sway * math.sin(t * math.pi) ** 0.5
            px = min(max(round(a[0] + (b[0] - a[0]) * t + nx * off), 5), N - 6)
            py = min(max(round(a[1] + (b[1] - a[1]) * t + ny * off), 5), N - 6)
            pts.append((px, py))
        pts.append(b)
        out: list[tuple[int, int]] = []
        for p0, p1 in zip(pts, pts[1:]):
            seg = step_cells(p0, p1)
            out += seg if not out else seg[1:]
        return out

    # ---- 철길: 연구소의 부서진 벽 → 광산촌 (유일하게 뚫린 길) ----
    lab_gate = gates[("lab", "e")]
    vil_gate = gates[("village", "w")]
    # 직각으로 꺾지 않고 비스듬히(지그재그로) 곧장 이어진다: 벽 앞에서 몇 칸 곧게 나와 대각선으로 가다가 마을 앞에서 다시 곧게
    out_a = (lab_gate[0] + 4, lab_gate[1])
    out_b = (vil_gate[0] - 4, vil_gate[1])
    rail = line_cells(lab_gate, out_a, True) + step_cells(out_a, out_b)[1:] + line_cells(out_b, (vil_gate[0] + 3, vil_gate[1]), True)[1:]
    # 철길 양옆은 숲이 감싼다 (철길 말고는 새는 곳이 없게), 그 가운데로 철길을 낸다
    for x, y in rail:
        for dx in range(-5, 6):
            for dy in range(-5, 6):
                cx, cy = x + dx, y + dy
                if inside(cx, cy) and in_piece(cx, cy) is None and village_d(cx, cy) > 1.0 and rect_dist("lab", cx, cy) > 4.5:
                    grid[cy][cx], ground[cy][cx] = "#", "g"
    for x, y in rail:
        clear(x, y, "r")
        if in_piece(x, y) == "village":
            ground[y][x] = "r"      # 철길은 마을 안 몇 칸까지 들어와 끝난다
    landmarks["lab_gate"] = lab_gate
    landmarks["rail_mid"] = rail[len(rail) // 2]
    landmarks["village_gate"] = vil_gate
    landmarks["village_center"] = (round(vcx), round(vcy))

    # ---- 쓰러진 나무 길: 광산촌 → 골렘 터 ----
    lair_gate = gates[("golem_lair", "w")]
    top = next(y for y in range(vy + vh // 2, 0, -1) if village_d(vx + vw // 2, y) > 1.0)
    points = [(vx + vw // 2, top - 4)] + [cell(p) for p in layout["trail"]["bends"]] + [(lair_gate[0] - 3, lair_gate[1])]
    trail: list[tuple[int, int]] = [(vx + vw // 2, y) for y in range(top, top - 4, -1)]
    for i, (a, b) in enumerate(zip(points, points[1:])):
        seg = meander(a, b, 6.0, 100 + i)
        trail += seg if not trail or trail[-1] != seg[0] else seg[1:]
    trail += line_cells(points[-1], lair_gate, True)[1:]
    rail_near = {(x + dx, y + dy) for x, y in rail for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
    # 길 둘레는 숲 (길을 따라가는 느낌이 나게), 그 가운데로 길을 낸다
    for x, y in trail:
        for dx in range(-4, 5):
            for dy in range(-4, 5):
                cx, cy = x + dx, y + dy
                if inside(cx, cy) and in_piece(cx, cy) is None and village_d(cx, cy) > 1.0 and (cx, cy) not in rail_near \
                        and rect_dist("lab", cx, cy) > 4.5:
                    grid[cy][cx], ground[cy][cx] = "#", "g"
    for x, y in trail:
        clear(x, y, "t")
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if in_piece(x + dx, y + dy) is None and inside(x + dx, y + dy) and grid[y + dy][x + dx] == "." \
                    and village_d(x + dx, y + dy) > 1.0:
                ground[y + dy][x + dx] = "t"
    landmarks["trail_start"] = trail[0]
    for i in range(6, len(trail) - 4, 9):       # 길가의 잔해 (골렘이 지나간 흔적)
        x, y = trail[i]
        for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
            sx, sy = x + dx, y + dy
            if inside(sx, sy) and grid[sy][sx] == "#" and in_piece(sx, sy, 1) is None and rng.random() < 0.5:
                grid[sy][sx] = "R"
                break
    for frac, enemies in layout["trail"]["camps"]:      # 적이 있는 빈터
        cx, cy = trail[int(frac * (len(trail) - 1))]
        spots = []
        for y in range(cy - 5, cy + 6):
            for x in range(cx - 5, cx + 6):
                if inside(x, y) and in_piece(x, y, 2) is None and math.hypot(x - cx, y - cy) <= 3.2 + wobble(x, y) * 1.6:
                    if grid[y][x] == "#":
                        grid[y][x] = "."
                    if grid[y][x] == "." and (x, y) not in trail and math.hypot(x - cx, y - cy) >= 2.0:
                        spots.append((x, y))
        rng.shuffle(spots)
        for ch, (x, y) in zip(enemies, spots):
            grid[y][x] = ch
        landmarks[f"camp_{len([k for k in landmarks if k.startswith('camp_')])}"] = (cx, cy)
    for n, frac in enumerate(layout["trail"]["blocks"]):   # 길을 막은 나무. 첫 번째 앞에 표지판
        i = int(frac * (len(trail) - 1))
        for j in (i, i + 1):
            x, y = trail[j]
            for dx in range(-2, 3):
                for dy in range(-2, 3):
                    bx, by = x + dx, y + dy
                    if inside(bx, by) and in_piece(bx, by, 1) is None and grid[by][bx] == ".":
                        grid[by][bx] = "#"
        landmarks[f"trail_block_{n}"] = trail[i]
        # 막힌 나무 바로 앞에 설 자리와, 거기서 마주 보는 나무 (길을 거슬러 올라가 처음 나오는 빈 칸)
        j = i
        while grid[trail[j][1]][trail[j][0]] == "#":
            j -= 1
        landmarks[f"trail_block_stand_{n}"] = trail[j]
        landmarks[f"trail_block_tree_{n}"] = trail[j + 1]
        landmarks[f"trail_before_block_{n}"] = trail[j - 2]
        j2 = i + 1
        while grid[trail[j2][1]][trail[j2][0]] == "#":
            j2 += 1
        landmarks[f"trail_after_block_{n}"] = trail[j2 + 1]
        if n == 0:
            sx, sy = trail[j - 3]
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if grid[sy + dy][sx + dx] == "." and (sx + dx, sy + dy) not in trail:
                    grid[sy + dy][sx + dx] = "I"
                    props[(sy + dy, sx + dx)] = ("I", CHOP_SIGN)
                    break
            else:
                raise AssertionError("표지판 놓을 자리가 없음")
    tx, ty = trail[int(layout["trail"]["tower"] * (len(trail) - 1))]     # 골렘 터 앞 탑
    for dx, dy in ((0, -1), (0, 1), (1, 0), (-1, 0)):
        if grid[ty + dy][tx + dx] == "." and (tx + dx, ty + dy) not in trail and grid[ty + dy + 1][tx + dx] in ".#":
            grid[ty + dy][tx + dx] = "Y"
            props[(ty + dy, tx + dx)] = ("Y", TRAIL_TOWER)
            if grid[ty + dy + 1][tx + dx] == "#":
                grid[ty + dy + 1][tx + dx] = "."      # 순간이동 도착 자리 (탑 한 칸 아래)
            break
    else:
        raise AssertionError("탑 놓을 자리가 없음")
    landmarks["lair_gate"] = lair_gate

    # ---- 나머지 지역: 탑 하나씩 + 탑과 탑을 잇는 흙길 + 작은 볼거리들 ----
    protected = set(rail) | set(trail)

    def near_protected(x: int, y: int, d: int) -> bool:
        return any(abs(x - px) < d and abs(y - py) < d for px, py in protected)

    def free_spot(cx: int, cy: int, reach: int = 14) -> tuple[int, int]:
        """그 근처에서 탑을 놓을 만한 자리 (조각·철길·쓰러진 나무 길에서 떨어진 곳)."""
        for r in range(0, reach + 1):
            for y in range(cy - r, cy + r + 1):
                for x in range(cx - r, cx + r + 1):
                    if max(abs(x - cx), abs(y - cy)) == r and inside(x, y, 6) and in_piece(x, y, 14) is None \
                            and not near_protected(x, y, 7):
                        return x, y
        raise AssertionError(f"놓을 자리가 없음 @ {(cx, cy)}")

    outer_towers: dict[str, tuple[int, int]] = {}
    for i, r in enumerate(region_cfg):
        if r["id"] in ("lab", "village", "golem"):
            continue
        tx, ty = free_spot(*seeds[i])
        for dy in range(-2, 4):
            for dx in range(-2, 3):
                set_floor(tx + dx, ty + dy, "p")
        grid[ty][tx] = "Y"
        props[(ty, tx)] = ("Y", dict(id=f"tower_{r['id']}", name=f"{r['name']} 탑"))
        outer_towers[r["id"]] = (tx, ty + 1)
        for dy in range(-2, 4):
            for dx in range(-2, 3):
                regions[ty + dy][tx + dx] = str(i)
    # 흙길: 탑마다 가장 가까운 다른 탑 둘과 잇는다 (물 위는 둑길이 된다)
    linked: set[tuple[str, str]] = set()
    for a, pa in outer_towers.items():
        near = sorted((math.hypot(pa[0] - pb[0], pa[1] - pb[1]), b) for b, pb in outer_towers.items() if b != a)[:2]
        for _d, b in near:
            if (b, a) in linked or (a, b) in linked:
                continue
            linked.add((a, b))
            for n_step, (x, y) in enumerate(meander(pa, outer_towers[b], 14.0, len(linked))):
                if in_piece(x, y, 13) is not None or near_protected(x, y, 6) or not inside(x, y, 3):
                    continue          # 연구소·마을 둘레 숲과 철길·쓰러진 나무 길은 건드리지 않는다
                # 길 폭은 한두 칸으로 조금씩 달라진다
                wide = ((x, y), (x + 1, y), (x, y + 1)) if noise(n_step, len(linked) * 3.1, 9.0, seed + 70) > 0.45 else ((x, y), (x + 1, y))
                for cx, cy in wide:
                    if grid[cy][cx] in "#~." and (cy, cx) not in props:
                        set_floor(cx, cy, "p")

    # 작은 볼거리: 작은 지역마다 하나씩 (적 야영지 · 폐허 · 숨겨 둔 물건)
    extra_items = [e["item"] for e in layout["field_pickups"]]
    rng.shuffle(extra_items)
    poi_kinds = ["camp", "ruin", "cache", "camp"]
    used: list[tuple[int, int]] = list(outer_towers.values())
    for zi, z in enumerate(zones):
        if z["fixed"]:
            continue
        for _try in range(400):
            cx = z["seed"][0] + rng.randrange(-N // 16, N // 16 + 1)
            cy = z["seed"][1] + rng.randrange(-N // 16, N // 16 + 1)
            if not inside(cx, cy, 8) or zmap[cy][cx] != zi or in_piece(cx, cy, 15) is not None \
                    or any(math.hypot(cx - ux, cy - uy) < 12 for ux, uy in used) or near_protected(cx, cy, 9):
                continue
            kind = poi_kinds[zi % len(poi_kinds)]
            used.append((cx, cy))
            for y in range(cy - 4, cy + 5):          # 작은 빈터
                for x in range(cx - 4, cx + 5):
                    if math.hypot(x - cx, y - cy) <= 2.6 + wobble(x, y) * 1.4:
                        set_floor(x, y, ground[y][x] if ground[y][x] in "gmp" else "g")
            if kind == "camp":
                for ch, (dx, dy) in zip(rng.choice(("Cc", "CS", "SB", "cCS")), ((-2, 0), (2, 1), (0, -2), (1, 2))):
                    grid[cy + dy][cx + dx] = ch
            elif kind == "ruin":
                for dx, dy, ch in ((-2, -1, "#"), (-1, -1, "#"), (1, -1, "R"), (2, -1, "#"), (-2, 0, "R"), (2, 1, "R"), (-1, 2, "#"), (0, 2, "R")):
                    grid[cy + dy][cx + dx] = ch
                    if ch == "#":
                        ground[cy + dy][cx + dx] = "l"      # 무너진 연구소 벽 조각
            if extra_items:
                grid[cy][cx] = "$"
                props[(cy, cx)] = ("$", extra_items.pop())
            break

    # 세상 테두리: 두 겹 나무 (맨 바깥은 벨 수 없다). 끝 출입구만 뚫려 있다
    for y in range(N):
        for x in range(N):
            if x < 2 or y < 2 or x >= N - 2 or y >= N - 2:
                grid[y][x], ground[y][x] = "#", "g"
                props.pop((y, x), None)

    rows_out = ["".join(r) for r in grid]
    # ---- 닿을 수 있는지 확인 ----
    start = next((x, y) for y, r in enumerate(rows_out) for x, ch in enumerate(r) if ch == "P")

    def flood(chop: bool, no_rail: bool = False) -> set[tuple[int, int]]:
        seen = {start}
        queue = collections.deque([start])
        while queue:
            x, y = queue.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < N and 0 <= ny < N) or (nx, ny) in seen:
                    continue
                ch = rows_out[ny][nx]
                wall_ok = chop and ch == "#" and inside(nx, ny, 1) and ground[ny][nx] in BREAKABLE
                if ch in "RNY~" or (ch == "#" and not wall_ok) or (no_rail and ground[ny][nx] == "r"):
                    continue
                seen.add((nx, ny))
                queue.append((nx, ny))
        return seen

    # 바위·물에 갇힌 소품·적이 있으면 가장 가까운 닿는 곳까지 샛길을 낸다
    for _round in range(60):
        chop = flood(True)
        stuck = [(x, y) for (y, x) in props if not any(p in chop for p in ((x, y), (x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))]
        stuck += [(x, y) for y, r in enumerate(rows_out) for x, ch in enumerate(r) if ch in "CcSB" and (x, y) not in chop]
        if not stuck:
            break
        for sx, sy in stuck:      # 갇힌 것마다 한 번에 샛길을 낸다
            came: dict[tuple[int, int], tuple[int, int] | None] = {(sx, sy): None}
            queue = collections.deque([(sx, sy)])
            end = None
            while queue and end is None:
                x, y = queue.popleft()
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not inside(nx, ny, 3) or (nx, ny) in came or in_piece(nx, ny, 1) is not None \
                            or grid[ny][nx] in "YNI$EZCcSB":
                        continue          # 다른 소품·적 자리는 지나가지 않는다
                    came[(nx, ny)] = (x, y)
                    if (nx, ny) in chop:
                        end = (nx, ny)
                        break
                    queue.append((nx, ny))
            assert end is not None, f"샛길을 낼 수 없음 @ {(sx, sy)}"
            step = came[end]
            while step is not None and step != (sx, sy):
                x, y = step
                if grid[y][x] in "#~R":
                    grid[y][x] = "."
                    ground[y][x] = "g" if ground[y][x] in "wml" else ground[y][x]
                step = came[step]
        rows_out = ["".join(r) for r in grid]

    walk = flood(False)     # 나무를 베지 않고
    chop = flood(True)      # 나무를 베면서
    assert landmarks["village_gate"] in walk and landmarks["trail_before_block_0"] in walk, "철길로 광산촌·쓰러진 나무 길 입구까지 걸어서 닿아야 한다"
    assert landmarks["trail_after_block_0"] not in walk, "쓰러진 나무 길은 나무를 베어야 지나갈 수 있어야 한다"
    assert landmarks["lair_gate"] in chop, "골렘 터에 닿을 수 없음"
    for (y, x), (ch, _cfg) in props.items():
        near = [(x, y), (x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
        assert any(p in chop for p in near), f"닿을 수 없는 소품 {ch} @ {(x, y)}"
    # 연구소 둘레는 숲으로 막혀 있고 철길만 뚫려 있다: 철길을 막으면 마을에 닿지 못해야 한다
    assert landmarks["village_gate"] not in flood(False, True), "연구소 숲에 철길 말고 뚫린 길이 있음"

    OUT.mkdir(parents=True, exist_ok=True)
    head = "; tools/build_world.py 가 만든다. 직접 고치지 말 것 (layout.json·조각 맵·build_world.py 를 고친다)\n"
    (OUT / "world.txt").write_text("; 바깥 세상 — 넓은 정사각형 한 장\n" + head + "\n".join(rows_out) + "\n", encoding="utf-8")
    (OUT / "world_ground.txt").write_text("\n".join("".join(r) for r in ground) + "\n", encoding="utf-8")
    (OUT / "world_regions.txt").write_text("\n".join("".join(ALPHABET[zi] for zi in row) for row in zmap) + "\n", encoding="utf-8")

    # ---- world.tres ----
    def esc(t: str) -> str:
        return t.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

    def arr(xs) -> str:
        return ", ".join('"%s"' % esc(x) for x in xs)

    subs = ""
    refs: dict[str, list[str]] = {"E": [], "Y": [], "N": [], "zone": []}
    pickups: list[str] = []
    signs: list[str] = []
    for i, ((py, px), (ch, cfg)) in enumerate(sorted(props.items())):
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
    for zi, z in enumerate(zones):
        extra = dict(REGION_EXTRA.get(z["group"], {}))
        enter = ZONE_ENTER.get(z["id"], "")
        ov = extra.get("overrides")
        ov_text = "{\n" + ",\n".join(f'"{k}": "{v}"' for k, v in ov.items()) + "\n}" if ov else "{}"
        subs += (f'[sub_resource type="Resource" id="zone_{z["id"]}"]\nscript = ExtResource("zone")\nid = "{z["id"]}"\n'
                 f'display_name = "{z["name"]}"\nkey = "{ALPHABET[zi]}"\ngroup = "{z["group"]}"\ngroup_name = "{z["group_name"]}"\n'
                 f'revealed_at_start = {"true" if z["id"] == "lab" else "false"}\n'
                 f'enter_story_id = "{enter}"\nenemy_overrides = {ov_text}\n\n')
        refs["zone"].append(f'SubResource("zone_{z["id"]}")')
    lair = rects["golem_lair"]
    marks = "{\n" + ",\n".join(f'"{k}": Vector2i({v[0]}, {v[1]})' for k, v in sorted(landmarks.items())) + "\n}"
    for name, (ox, oy, w, h) in rects.items():
        marks = marks[:-2] + f',\n"{name}_pos": Vector2i({ox}, {oy}),\n"{name}_size": Vector2i({w}, {h})\n}}'

    def gdict(field: str, quote: bool) -> str:
        return "{\n" + ",\n".join(f'"{k}": ' + (f'"{v[field]}"' if quote else v[field]) for k, v in GROUNDS.items()) + "\n}"

    (ROOT / "data" / "areas" / "world.tres").write_text(f'''[gd_resource type="Resource" script_class="AreaData" format=3]

[ext_resource type="Script" path="res://story/area_data.gd" id="area"]
[ext_resource type="Script" path="res://story/area_exit_data.gd" id="exit"]
[ext_resource type="Script" path="res://story/waystone_data.gd" id="way"]
[ext_resource type="Script" path="res://story/npc_data.gd" id="npc"]
[ext_resource type="Script" path="res://story/zone_data.gd" id="zone"]

{subs}[resource]
script = ExtResource("area")
id = "world"
display_name = "숲"
map_file = "res://levels/areas/world.txt"
ground_file = "res://levels/areas/world_ground.txt"
regions_file = "res://levels/areas/world_regions.txt"
tileset = "tiles_forest"
ground_tilesets = {gdict("tileset", True)}
ground_floor_colors = {gdict("floor", False)}
ground_wall_colors = {gdict("wall", False)}
breakable_grounds = "{BREAKABLE}"
on_map = true
zones = Array[ExtResource("zone")]([{", ".join(refs["zone"])}])
boss_room_rect = Rect2i({lair[0]}, {lair[1]}, {lair[2]}, {lair[3]})
boss_cleared_flag = "golem_destroyed"
landmarks = {marks}
break_hits = 2
break_drop_item = "wood"
break_ammo = 3
enemy_overrides = {{}}
exits = Array[ExtResource("exit")]([{", ".join(refs["E"])}])
waystones = Array[ExtResource("way")]([{", ".join(refs["Y"])}])
pickups = Array[String]([{arr(pickups)}])
npcs = Array[ExtResource("npc")]([{", ".join(refs["N"])}])
signs = Array[String]([{arr(signs)}])
''', encoding="utf-8")
    print(f"세계 생성 완료: {N}×{N}칸 (화면 {N / 20:.0f}×{N / 11.25:.0f}개), 묶음 {len(seeds)}개, 작은 지역 {len(zones)}개, 소품 {len(props)}개")
    for i, r in enumerate(region_cfg):
        print(f"  {r['name']}: " + ", ".join(zones[zi]["name"] for zi in by_province[i]))


if __name__ == "__main__":
    main()
