#!/usr/bin/env python3
"""스프라이트 생성기.

고정 팔레트만 써서 픽셀 단위로 그린 뒤 스프라이트시트 PNG + 메타데이터 JSON을 만든다.
실행: python3 tools/sprite_gen.py
- 랜덤은 고정 시드만 쓰므로 다시 실행해도 결과가 같다.
- 시트 구조: 한 줄 = 애니메이션 하나, 한 칸 = 프레임 하나 (Aseprite 등에서 고치기 쉽게).
- 테마(세계관)를 바꾸려면 THEME 폴더를 새로 만들고 팔레트·그림 함수를 교체한다.
"""
from __future__ import annotations

import json
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
THEME = "dungeon"  # 임시 판타지 던전 테마
OUT = ROOT / "art" / "themes" / THEME

# ---------------------------------------------------------------------------
# 팔레트 (24색). 모든 스프라이트는 이 색만 쓴다. 투명은 None.
# ---------------------------------------------------------------------------
PALETTE: list[tuple[str, str]] = [
    ("outline", "0e0b14"),
    ("shadow", "2a2333"),
    ("stone_dark", "463c51"),
    ("stone", "655a6e"),
    ("stone_light", "8b8296"),
    ("pale", "c2bccb"),
    ("white", "f2eff5"),
    ("brown_dark", "5a2f2a"),
    ("brown", "8a5236"),
    ("tan", "c58a55"),
    ("skin", "f0c79a"),
    ("plum", "3b1f3f"),
    ("crimson", "7a2b45"),
    ("red", "c4404b"),
    ("orange", "f07a4a"),
    ("yellow", "f8c85a"),
    ("green_dark", "2a4a3a"),
    ("green", "3f7a4a"),
    ("green_light", "7cc15a"),
    ("navy", "1e2f55"),
    ("blue", "2f5f9a"),
    ("sky", "4fa3d8"),
    ("cyan", "9fe3f0"),
    ("purple", "6b3fa0"),
]
PAL_INDEX = {name: i for i, (name, _) in enumerate(PALETTE)}
PAL_RGB = [tuple(int(h[i : i + 2], 16) for i in (0, 2, 4)) for _, h in PALETTE]


def c(name: str) -> int:
    """팔레트 이름 → 인덱스."""
    return PAL_INDEX[name]


# ---------------------------------------------------------------------------
# 캔버스: 팔레트 인덱스(또는 None) 2차원 배열
# ---------------------------------------------------------------------------
class Canvas:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.px: list[list[int | None]] = [[None] * w for _ in range(h)]

    @staticmethod
    def from_rows(rows: list[str], cmap: dict[str, str | None]) -> "Canvas":
        h, w = len(rows), len(rows[0])
        cv = Canvas(w, h)
        for y, row in enumerate(rows):
            assert len(row) == w, f"행 길이 불일치 (y={y}): {row!r}"
            for x, ch in enumerate(row):
                name = cmap[ch]
                cv.px[y][x] = None if name is None else c(name)
        return cv

    def copy(self) -> "Canvas":
        cv = Canvas(self.w, self.h)
        cv.px = [row[:] for row in self.px]
        return cv

    def set(self, x: int, y: int, color: int | None) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = color

    def fill(self, color: int) -> None:
        for y in range(self.h):
            for x in range(self.w):
                self.px[y][x] = color

    def line(self, x0: int, y0: int, x1: int, y1: int, color: int) -> None:
        """브레젠험 직선."""
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.set(x0, y0, color)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def shift_rows(self, top: int, bottom: int, dy: int) -> "Canvas":
        """top~bottom 행 묶음을 dy만큼 아래로 민다 (나머지 행은 유지)."""
        cv = self.copy()
        block = [self.px[y][:] for y in range(top, bottom + 1)]
        for y in range(top, bottom + 1):
            cv.px[y] = [None] * self.w
        for i, row in enumerate(block):
            ty = top + i + dy
            if 0 <= ty < self.h:
                for x, v in enumerate(row):
                    if v is not None:
                        cv.px[ty][x] = v
        return cv

    def recolor(self, keep: set[int], to: int) -> "Canvas":
        cv = self.copy()
        for y in range(self.h):
            for x in range(self.w):
                v = cv.px[y][x]
                if v is not None and v not in keep:
                    cv.px[y][x] = to
        return cv

    def rotate_cw(self) -> "Canvas":
        cv = Canvas(self.h, self.w)
        for y in range(self.h):
            for x in range(self.w):
                cv.px[x][self.h - 1 - y] = self.px[y][x]
        return cv

    def bbox(self) -> tuple[int, int, int, int]:
        xs = [x for y in range(self.h) for x in range(self.w) if self.px[y][x] is not None]
        ys = [y for y in range(self.h) for x in range(self.w) if self.px[y][x] is not None]
        return min(xs), min(ys), max(xs), max(ys)

    def moved(self, dx: int, dy: int) -> "Canvas":
        cv = Canvas(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                v = self.px[y][x]
                if v is not None:
                    cv.set(x + dx, y + dy, v)
        return cv

    def to_image(self) -> Image.Image:
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                v = self.px[y][x]
                if v is not None:
                    img.putpixel((x, y), (*PAL_RGB[v], 255))
        return img


def save_sheet(name: str, fw: int, fh: int, anims: list[tuple[str, list[Canvas], float, bool]]) -> None:
    """애니메이션 목록을 시트 PNG + JSON으로 저장한다. 한 줄 = 애니메이션 하나."""
    cols = max(len(frames) for _, frames, _, _ in anims)
    sheet = Image.new("RGBA", (cols * fw, len(anims) * fh), (0, 0, 0, 0))
    meta: dict = {"frame_width": fw, "frame_height": fh, "animations": {}}
    for row, (anim, frames, fps, loop) in enumerate(anims):
        for col, frame in enumerate(frames):
            assert (frame.w, frame.h) == (fw, fh), f"{name}/{anim} 프레임 크기 불일치"
            sheet.paste(frame.to_image(), (col * fw, row * fh))
        meta["animations"][anim] = {"row": row, "frames": len(frames), "fps": fps, "loop": loop}
    sheet.save(OUT / f"{name}.png", optimize=False)
    write_json(OUT / f"{name}.json", meta)


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


# ---------------------------------------------------------------------------
# 플레이어 (16x16, 오른쪽을 보는 기준. 왼쪽은 게임에서 좌우 반전)
# ---------------------------------------------------------------------------
PLAYER_CMAP: dict[str, str | None] = {
    ".": None,
    "o": "outline",
    "h": "blue",
    "H": "sky",
    "n": "navy",
    "s": "skin",
    "e": "outline",
    "b": "brown",
    "B": "brown_dark",
    "g": "stone_light",
    "G": "stone_dark",
}
PLAYER_BASE = [
    "................",
    "................",
    "......ooooo.....",
    ".....ohHHhho....",
    "....ohHhhhhno...",
    "....ohhossseo...",
    "....onhosssso...",
    "....onnhoooo....",
    "...onhhhhhhgGG..",
    "...onnhbbbhoo...",
    "...onnhhhhho....",
    "....onnhhhho....",
    "....onnnnnno....",
    ".....oBo.oBo....",
    ".....oBo.oBo....",
    ".....ooo.ooo....",
]


def player_legs(base: Canvas, rows: list[str]) -> Canvas:
    """다리(13~15행)만 바꾼 프레임."""
    cv = base.copy()
    legs = Canvas.from_rows(rows, PLAYER_CMAP)
    for i in range(3):
        cv.px[13 + i] = legs.px[i][:]
    return cv


def build_player() -> None:
    base = Canvas.from_rows(PLAYER_BASE, PLAYER_CMAP)
    bob = base.shift_rows(0, 12, 1)  # 상체를 1px 내린 프레임

    idle = [base, bob]

    stride_a = player_legs(base, [
        "....oBo...oBo...",
        "....oBo...oBo...",
        "....ooo...ooo...",
    ])
    together = player_legs(bob, [
        ".....oBooBo.....",
        ".....oBooBo.....",
        ".....oooooo.....",
    ])
    move = [stride_a, together, stride_a.shift_rows(0, 12, 0), together]

    flash = base.copy()
    flash.set(14, 8, c("yellow"))
    flash.set(15, 8, c("white"))
    flash.set(14, 7, c("orange"))
    flash.set(14, 9, c("orange"))
    recoil = base.copy()
    recoil.set(14, 8, c("yellow"))
    shoot = [flash, recoil]

    blade, tip = c("pale"), c("white")
    m0 = base.copy()
    m0.line(10, 8, 13, 2, blade)
    m0.set(13, 2, tip)
    m1 = base.copy()
    for x, y in [(12, 3), (13, 4), (14, 6), (14, 8), (14, 10), (13, 12)]:
        m1.set(x, y, tip)
    for x, y in [(12, 4), (13, 6), (13, 8), (13, 10), (12, 11)]:
        m1.set(x, y, blade)
    m2 = base.copy()
    m2.line(10, 9, 14, 14, blade)
    m2.set(14, 14, tip)
    melee = [m0, m1, m2]

    squash = player_legs(bob, [
        "....oBo...oBo...",
        "...oBo.....oBo..",
        "...ooo.....ooo..",
    ])
    ball = base.shift_rows(0, 12, 2)
    ball = player_legs(ball, [
        ".....oBooBo.....",
        ".....oooooo.....",
        "................",
    ])
    for y in (7, 9, 11):
        ball.line(0, y, 2, y, c("pale"))
    dodge = [squash, ball, squash]

    outline = {c("outline")}
    hurt = [base.recolor(outline, c("white")), base.recolor(outline, c("red"))]

    lying = base.rotate_cw()
    x0, y0, x1, y1 = lying.bbox()
    lying = lying.moved(0, 15 - y1)
    death = [base.shift_rows(0, 12, 1), base.shift_rows(0, 12, 3), lying.moved(0, -1), lying]

    save_sheet("player", 16, 16, [
        ("idle", idle, 3.0, True),
        ("move", move, 8.0, True),
        ("shoot", shoot, 12.0, False),
        ("melee", melee, 15.0, False),
        ("dodge", dodge, 15.0, False),
        ("hurt", hurt, 12.0, False),
        ("death", death, 6.0, False),
    ])


# ---------------------------------------------------------------------------
# 타일 (16x16). tiles.json에 이름 → 아틀라스 좌표 기록
# ---------------------------------------------------------------------------
def tile_floor(rng: random.Random, cracked: bool) -> Canvas:
    t = Canvas(16, 16)
    t.fill(c("stone_dark"))
    # 큰 돌판 이음새
    t.line(0, 0, 15, 0, c("shadow"))
    t.line(0, 0, 0, 15, c("shadow"))
    t.line(0, 8, 15, 8, c("shadow"))
    t.line(8, 1, 8, 7, c("shadow"))
    # 밝은 모서리
    t.line(1, 1, 7, 1, c("stone"))
    t.line(9, 1, 15, 1, c("stone"))
    t.line(1, 9, 15, 9, c("stone"))
    for _ in range(6):
        t.set(rng.randrange(1, 16), rng.randrange(1, 16), c("stone"))
    for _ in range(3):
        t.set(rng.randrange(1, 16), rng.randrange(1, 16), c("shadow"))
    if cracked:
        t.line(3, 11, 6, 13, c("shadow"))
        t.line(6, 13, 10, 12, c("shadow"))
        t.line(10, 12, 12, 15, c("shadow"))
    return t


def tile_wall_top() -> Canvas:
    t = Canvas(16, 16)
    t.fill(c("shadow"))
    for y in (3, 11):
        for x in range(0, 16, 4):
            t.set(x + (2 if y == 11 else 0), y, c("stone_dark"))
    return t


def tile_wall_face() -> Canvas:
    t = Canvas(16, 16)
    t.fill(c("stone"))
    for y in (0, 5, 10):
        t.line(0, y, 15, y, c("stone_dark"))
    for row, y0 in enumerate((1, 6, 11)):
        off = 0 if row % 2 == 0 else 4
        for x in range(off, 16, 8):
            t.line(x, y0, x, y0 + 3, c("stone_dark"))
        t.line(0, y0, 15, y0, c("stone_light"))
    t.line(0, 15, 15, 15, c("shadow"))
    t.line(0, 14, 15, 14, c("stone_dark"))
    return t


def build_tiles() -> None:
    rng = random.Random(1001)  # 고정 시드
    tiles = [
        ("floor", tile_floor(rng, False)),
        ("floor_alt", tile_floor(rng, True)),
        ("wall_top", tile_wall_top()),
        ("wall_face", tile_wall_face()),
    ]
    sheet = Image.new("RGBA", (16 * len(tiles), 16), (0, 0, 0, 0))
    meta: dict = {"tile_size": 16, "tiles": {}}
    for i, (name, cv) in enumerate(tiles):
        sheet.paste(cv.to_image(), (i * 16, 0))
        meta["tiles"][name] = [i, 0]
    sheet.save(OUT / "tiles.png", optimize=False)
    write_json(OUT / "tiles.json", meta)


# ---------------------------------------------------------------------------
# 탄 (8x8). 반사탄은 색으로 확실히 구분 (부스 관객용)
# ---------------------------------------------------------------------------
def orb(size: int, r: float, core: str, ring: str, outline: str | None, phase: int) -> Canvas:
    cv = Canvas(size, size)
    cx = cy = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= r - 1.2:
                cv.set(x, y, c(core))
            elif d <= r:
                cv.set(x, y, c(ring))
            elif outline and d <= r + 0.9:
                cv.set(x, y, c(outline))
    # 반짝임: 프레임마다 하이라이트 위치가 바뀜
    hx = int(cx - 1 + phase)
    cv.set(hx, int(cy - 1), c("white"))
    return cv


def build_bullets() -> None:
    save_sheet("bullets", 8, 8, [
        ("player", [orb(8, 2.2, "yellow", "orange", "outline", p) for p in (0, 1)], 10.0, True),
        ("enemy", [orb(8, 2.8, "red", "crimson", "outline", p) for p in (0, 1)], 8.0, True),
        ("reflect", [orb(8, 2.4, "cyan", "sky", "outline", p) for p in (0, 1)], 12.0, True),
        ("reflect_perfect", [orb(8, 3.3, "white", "cyan", "sky", p) for p in (0, 1)], 16.0, True),
    ])


# ---------------------------------------------------------------------------
# 이펙트 (16x16, 오른쪽 기준. 게임에서 회전)
# ---------------------------------------------------------------------------
def arc_pixels(cx: float, cy: float, r: float, a0: float, a1: float, steps: int = 24):
    import math
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        yield round(cx + r * math.cos(a)), round(cy + r * math.sin(a))


def build_effects() -> None:
    import math

    # 근접 베기 호
    slash = []
    for a0, a1 in ((-80, -20), (-75, 75), (20, 80)):
        cv = Canvas(16, 16)
        for x, y in arc_pixels(4, 7.5, 9, a0, a1):
            cv.set(x, y, c("white"))
        for x, y in arc_pixels(4, 7.5, 7.5, a0 + 10, a1 - 10):
            cv.set(x, y, c("pale"))
        slash.append(cv)

    # 패링 불꽃: 별 모양이 퍼짐
    parry = []
    for r in (2, 4, 6):
        cv = Canvas(16, 16)
        for k in range(8):
            a = math.radians(k * 45)
            for t in range(max(1, r - 2), r + 1):
                cv.set(round(7.5 + t * math.cos(a)), round(7.5 + t * math.sin(a)),
                       c("white") if t == r else c("yellow"))
        cv.set(7, 7, c("white"))
        cv.set(8, 8, c("white"))
        parry.append(cv)

    # 완벽 판정: 커지는 이중 고리 (게임에서 2배로 키워 표시)
    perfect = []
    for r in (2.5, 4.5, 6.5, 7.5):
        cv = Canvas(16, 16)
        for y in range(16):
            for x in range(16):
                d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
                if abs(d - r) < 0.6:
                    cv.set(x, y, c("white"))
                elif abs(d - (r - 2)) < 0.5 and r < 7.5:
                    cv.set(x, y, c("cyan"))
        perfect.append(cv)

    # 투명 진입 연기
    puff = []
    rng = random.Random(77)
    for r in (3, 5, 7):
        cv = Canvas(16, 16)
        for _ in range(18):
            a = rng.uniform(0, math.tau)
            d = rng.uniform(r - 2, r)
            cv.set(round(7.5 + d * math.cos(a)), round(7.5 + d * math.sin(a)),
                   c("pale") if rng.random() < 0.6 else c("cyan"))
        puff.append(cv)

    # 탄이 벽·대상에 맞음
    hit = []
    for r in (1, 3):
        cv = Canvas(16, 16)
        for k in range(4):
            a = math.radians(45 + k * 90)
            cv.set(round(7.5 + r * math.cos(a)), round(7.5 + r * math.sin(a)), c("yellow"))
        cv.set(7, 7, c("white"))
        hit.append(cv)

    save_sheet("effects", 16, 16, [
        ("slash", slash, 20.0, False),
        ("parry", parry, 20.0, False),
        ("perfect", perfect, 16.0, False),
        ("stealth_puff", puff, 12.0, False),
        ("hit", hit, 20.0, False),
        ("enemy_death", build_enemy_death(), 12.0, False),
    ])


# ---------------------------------------------------------------------------
# 테스트·연습용 소품 (16x16)
# ---------------------------------------------------------------------------
DUMMY = [
    "................",
    "......oooo......",
    ".....otttto.....",
    ".....otetto.....",
    ".....otttto.....",
    "......oooo......",
    "...oooobboooo...",
    "...obbbbbbbbo...",
    "...oooobboooo...",
    "......obbo......",
    ".....otttto.....",
    ".....otttto.....",
    "......obbo......",
    "......obbo......",
    "....oooooooo....",
    "....oBBBBBBo....",
]
TURRET = [
    "................",
    "................",
    "....oooooooo....",
    "...osssssssso...",
    "..osSSSSSSSSso..",
    "..oSSowwwoSSSo..",
    "..oSowrrrwoSSo..",
    "..oSowrRrwoSSo..",
    "..oSSowwwoSSSo..",
    "..osSSSSSSSSso..",
    "...osssssssso...",
    "....oSSSSSSo....",
    "...oSSSSSSSSo...",
    "...oddddddddo...",
    "...oooooooooo...",
    "................",
]


def build_props() -> None:
    dmap = {".": None, "o": "outline", "t": "tan", "e": "brown_dark", "b": "brown", "B": "brown_dark"}
    dummy = Canvas.from_rows(DUMMY, dmap)
    tmap = {".": None, "o": "outline", "s": "stone_light", "S": "stone", "w": "pale",
            "r": "red", "R": "yellow", "d": "stone_dark"}
    turret = Canvas.from_rows(TURRET, tmap)
    turret_lit = turret.copy()
    for x, y in [(6, 6), (7, 6), (8, 6), (6, 7), (8, 7)]:
        turret_lit.set(x, y, c("orange"))
    save_sheet("props", 16, 16, [
        ("dummy_idle", [dummy], 1.0, True),
        ("dummy_hit", [dummy.recolor({c("outline")}, c("white")), dummy], 12.0, False),
        ("turret_idle", [turret, turret_lit], 2.0, True),
    ])


# ---------------------------------------------------------------------------
# 적 (16x16, 오른쪽 기준). 애니메이션: idle / move / attack / hurt
# 사망은 이펙트(enemy_death)로 표현
# ---------------------------------------------------------------------------
CHARGER = [
    "................",
    "................",
    "................",
    "...........ww...",
    ".....ooooooowo..",
    "....obbbbbbbbo..",
    "...obBBbbbbbeboo",
    "..obBBBbbbbbbbbo",
    "..obBBBbbbbbbbo.",
    "..obbBBbbbbbbbo.",
    "...obbbbbbbbbo..",
    "....oooooooooo..",
    "....oBo....oBo..",
    "....oBo....oBo..",
    "....ooo....ooo..",
    "................",
]
SHOOTER = [
    "................",
    "......oooo......",
    ".....oppppo.....",
    "....oppppppo....",
    "....oppkkkpo....",
    "....opkekeko....",
    "....oppkkkpo.Y..",
    "...oppppppppoYo.",
    "...oPpppppPpogo.",
    "...oPPppppPPo.g.",
    "...oPPPpppPPo.g.",
    "...oPPPPPPPPo.g.",
    "....oPPPPPPo..g.",
    "....oooooooo..g.",
    "..............g.",
    "................",
]


def spreader_frame(spin: int, pulse: int) -> Canvas:
    """탄막형: 떠 있는 가시 수정 눈. spin 으로 가시 회전, pulse 로 눈 깜빡임."""
    import math
    cv = Canvas(16, 16)
    cx = cy = 7.5
    for y in range(16):
        for x in range(16):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= 3.6:
                cv.set(x, y, c("green_light") if d <= 2.2 else c("green"))
            elif d <= 4.6:
                cv.set(x, y, c("outline"))
    for k in range(6):
        a = math.radians(k * 60 + spin * 15)
        for t in (5, 6, 7):
            cv.set(round(cx + t * math.cos(a)), round(cy + t * math.sin(a)),
                   c("purple") if t < 7 else c("outline"))
    cv.set(7, 7, c("white"))
    cv.set(8, 7, c("white"))
    cv.set(7 + pulse, 8, c("outline"))
    return cv


def legs_swap(base: Canvas, rows: list[str], cmap: dict, top: int) -> Canvas:
    cv = base.copy()
    part = Canvas.from_rows(rows, cmap)
    for i in range(len(rows)):
        cv.px[top + i] = part.px[i][:]
    return cv


def build_enemies() -> None:
    outline = {c("outline")}

    cmap = {".": None, "o": "outline", "b": "brown", "B": "brown_dark", "e": "red", "w": "pale"}
    ch = Canvas.from_rows(CHARGER, cmap)
    ch_step = legs_swap(ch, [
        "...oBo......oBo.",
        "...oBo......oBo.",
        "...ooo......ooo.",
    ], cmap, 12)
    ch_wind = ch.shift_rows(0, 11, 1)  # 웅크림 (돌진 준비)
    ch_wind.set(12, 6, c("yellow"))
    save_sheet("enemy_charger", 16, 16, [
        ("idle", [ch, ch.shift_rows(0, 11, 1)], 3.0, True),
        ("move", [ch, ch_step], 8.0, True),
        ("attack", [ch_wind, ch_step.moved(1, 0)], 10.0, True),
        ("hurt", [ch.recolor(outline, c("white")), ch], 12.0, False),
    ])

    smap = {".": None, "o": "outline", "p": "purple", "P": "plum", "k": "outline",
            "e": "yellow", "Y": "yellow", "g": "brown"}
    sh = Canvas.from_rows(SHOOTER, smap)
    sh_bob = sh.shift_rows(0, 12, 1)
    sh_cast = sh.copy()
    for x, y in [(12, 5), (14, 5), (13, 4), (12, 7), (14, 7)]:
        sh_cast.set(x, y, c("orange"))
    save_sheet("enemy_shooter", 16, 16, [
        ("idle", [sh, sh_bob], 3.0, True),
        ("move", [sh, sh_bob], 6.0, True),
        ("attack", [sh_cast, sh], 10.0, True),
        ("hurt", [sh.recolor(outline, c("white")), sh], 12.0, False),
    ])

    sp = [spreader_frame(i, i % 2) for i in range(4)]
    sp_att = [f.recolor({c("outline"), c("white")}, c("orange")) for f in sp[:2]]
    save_sheet("enemy_spreader", 16, 16, [
        ("idle", sp, 6.0, True),
        ("move", sp, 8.0, True),
        ("attack", [sp_att[0], sp[1]], 10.0, True),
        ("hurt", [sp[0].recolor(outline, c("white")), sp[0]], 12.0, False),
    ])


def build_enemy_death() -> list[Canvas]:
    import math
    frames = []
    rng = random.Random(4242)
    pieces = [(rng.uniform(0, math.tau), rng.uniform(0.6, 1.0)) for _ in range(10)]
    for step in (2, 4, 6, 7):
        cv = Canvas(16, 16)
        for a, sp in pieces:
            r = step * sp
            cv.set(round(7.5 + r * math.cos(a)), round(7.5 + r * math.sin(a)),
                   c("crimson") if step < 6 else c("stone"))
        if step == 2:
            for x, y in [(7, 7), (8, 7), (7, 8), (8, 8)]:
                cv.set(x, y, c("white"))
        frames.append(cv)
    return frames


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
HEART = [
    ".oo.oo..",
    "owrorro.",
    "orrrrro.",
    "orrrrro.",
    ".orrro..",
    "..oro...",
    "...o....",
    "........",
]
AMMO_FULL = [
    "..oo....",
    ".oyyo...",
    ".oyyo...",
    ".oYYo...",
    ".oYYo...",
    ".oBBo...",
    ".oBBo...",
    "..oo....",
]


def build_ui_icons() -> None:
    cmap = {".": None, "o": "outline", "y": "yellow", "Y": "orange", "B": "brown"}
    full = Canvas.from_rows(AMMO_FULL, cmap)
    empty = full.recolor({c("outline")}, c("stone_dark"))
    hmap = {".": None, "o": "outline", "r": "red", "w": "white"}
    heart = Canvas.from_rows(HEART, hmap)
    heart_empty = heart.recolor({c("outline")}, c("stone_dark"))
    save_sheet("ui_icons", 8, 8, [
        ("ammo_full", [full], 1.0, False),
        ("ammo_empty", [empty], 1.0, False),
        ("heart_full", [heart], 1.0, False),
        ("heart_empty", [heart_empty], 1.0, False),
    ])

CROSSHAIR = [
    "....o....",
    "...owo...",
    "...owo...",
    ".oo...oo.",
    "ow..w..wo",
    ".oo...oo.",
    "...owo...",
    "...owo...",
    "....o....",
]


def build_ui() -> None:
    cross = Canvas.from_rows(CROSSHAIR, {".": None, "o": "outline", "w": "white"})
    cross.to_image().save(OUT / "crosshair.png", optimize=False)


# ---------------------------------------------------------------------------
# 팔레트 파일 (Aseprite·GIMP에서 그대로 불러올 수 있는 .gpl + 1px 견본 PNG)
# ---------------------------------------------------------------------------
def build_palette() -> None:
    lines = ["GIMP Palette", f"Name: {THEME}", "Columns: 8", "#"]
    for (name, _), (r, g, b) in zip(PALETTE, PAL_RGB):
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{name}")
    (OUT / "palette.gpl").write_text("\n".join(lines) + "\n", encoding="utf-8")
    img = Image.new("RGBA", (len(PALETTE), 1))
    for i, rgb in enumerate(PAL_RGB):
        img.putpixel((i, 0), (*rgb, 255))
    img.save(OUT / "palette.png", optimize=False)


def verify_palette() -> None:
    """생성된 모든 PNG가 팔레트 색만 쓰는지 검사한다."""
    allowed = set(PAL_RGB)
    for png in sorted(OUT.glob("*.png")):
        raw = Image.open(png).convert("RGBA").tobytes()
        for i in range(0, len(raw), 4):
            r, g, b, a = raw[i : i + 4]
            if a == 0:
                continue
            assert a == 255 and (r, g, b) in allowed, f"{png.name}: 팔레트 밖 색 {(r, g, b, a)}"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build_palette()
    build_player()
    build_tiles()
    build_ui()
    build_bullets()
    build_effects()
    build_props()
    build_ui_icons()
    build_enemies()
    verify_palette()
    print(f"스프라이트 생성 완료: {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
