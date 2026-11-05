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
    "W": "white",        # 망토 빛 받는 테두리
    "P": "pale",         # 밝은 후드·망토
    "l": "stone_light",  # 주름 그늘
    "n": "stone",        # 후드 안쪽 그늘
    "t": "brown",        # 앞머리
    "s": "skin",
    "e": "outline",      # 눈
    "y": "yellow",       # 망토 고정 장식
    "b": "sky",          # 망토 안감
    "h": "tan",          # 장갑
    "g": "stone_light",  # 총
    "G": "stone_dark",
    "k": "brown_dark",   # 장화
}
# 밝은 흰 후드 망토 (오른쪽을 봄). 후드 아래로 앞머리와 얼굴이 보인다.
# 후드가 목에서 조이지 않고 발목까지 긴 망토로 이어지며, 밑단은 찢어져 너덜너덜하다.
PLAYER_BASE = [
    "....oo..........",
    "...oWWoo........",
    "...oWPPWoo......",
    "..oWPPPPPWo.....",
    "..oWPPPPPPWo....",
    "..oWPPPlnttto...",
    "..oWPPlntssso...",
    "..oWPPlnsseso...",
    ".oWPPPPlnsso....",
    ".oWPPPPPlyloooo.",
    "oWPPPPPPPhhgggo.",
    "oWPPPPPPPboGGo..",
    "oWPPlPPPPbo.....",
    "oWPPlPPPPPbo....",
    "oPoPPoPlo.Po....",
    ".o.oPo.okokoo...",
]
# 쓰러져 누운 모습 (머리 왼쪽, 발 오른쪽)
PLAYER_LYING = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "..oooo..........",
    ".oWWPo.oooooo...",
    "oWPtssooPPPPPPoo",
    "oWPseso.PPPbPPko",
    "oPPsssoPPPPPPPko",
    ".oPPoo.oPlPlPoo.",
    "..oo....oooooo..",
]
# 찢어진 밑단 (펄럭임 2가지)
PLAYER_HEMS = [
    "oPoPPoPlo.Po....",
    "oPPoPoPPoPo.....",
]
# 밑단 아래 장화·늘어진 천 조각 (마지막 줄)
PLAYER_FEET = {
    "stand": ".o.oPo.okokoo...",
    "step_a": "...oko.Po.okoo..",
    "step_b": ".....okookoo....",
    "spread": "..okoo....okoo..",
    "tuck": "..oooooooooo....",
}


def player_legs(base: Canvas, rows: list[str]) -> Canvas:
    """다리(13~15행)만 바꾼 프레임."""
    cv = base.copy()
    legs = Canvas.from_rows(rows, PLAYER_CMAP)
    for i in range(3):
        cv.px[13 + i] = legs.px[i][:]
    return cv


def player_row(cv: Canvas, y: int, row: str) -> Canvas:
    """한 줄을 바꾼 프레임 (밑단·장화 등)."""
    assert len(row) == 16, f"줄 길이 16 아님: {row!r}"
    out = cv.copy()
    part = Canvas.from_rows([row], PLAYER_CMAP)
    out.px[y] = part.px[0][:]
    return out


def hem(cv: Canvas, pose: int) -> Canvas:
    return player_row(cv, 14, PLAYER_HEMS[pose % len(PLAYER_HEMS)])


def boots(cv: Canvas, row: str) -> Canvas:
    return player_row(cv, 15, row)


def build_player() -> None:
    base = Canvas.from_rows(PLAYER_BASE, PLAYER_CMAP)
    bob = base.shift_rows(0, 13, 1)  # 망토째 1px 내려앉음 (숨쉬기)

    idle = [hem(base, 0), hem(base, 1), hem(bob, 1), hem(bob, 0)]

    # 이동: 찢어진 밑단 아래로 장화가 번갈아 나오고 밑단이 펄럭임
    move = [boots(hem(base, 0), PLAYER_FEET["step_a"]), boots(hem(bob, 1), PLAYER_FEET["step_b"]),
            boots(hem(base, 1), PLAYER_FEET["stand"]), boots(hem(bob, 0), PLAYER_FEET["step_b"])]

    # 사격: 총구 불꽃 → 반동
    flash = hem(base, 0)
    flash.set(15, 10, c("white"))
    flash.set(15, 9, c("yellow"))
    flash.set(15, 11, c("yellow"))
    flash.set(14, 8, c("orange"))
    flash.set(14, 12, c("orange"))
    recoil = hem(base, 1).moved(-1, 0)
    recoil.set(14, 10, c("yellow"))
    shoot = [flash, recoil]

    # 근접: 망토 속 단검 (위 → 앞 → 아래)
    blade, tip = c("pale"), c("white")
    m0 = hem(base, 1)
    m0.line(11, 9, 14, 4, blade)
    m0.set(15, 3, tip)
    m1 = hem(base, 0)
    for x, y in [(12, 4), (13, 5), (14, 7), (15, 9), (14, 11), (13, 13)]:
        m1.set(x, y, tip)
    for x, y in [(12, 5), (13, 7), (14, 9), (13, 11), (12, 12)]:
        m1.set(x, y, blade)
    m2 = hem(base, 1)
    m2.line(11, 11, 14, 14, blade)
    m2.set(15, 15, tip)
    melee = [m0, m1, m2]

    # 회피: 몸을 낮추고 망토가 뒤로 쏠림 + 잔상 선
    squash = boots(hem(bob, 1), PLAYER_FEET["spread"])
    ball = base.shift_rows(0, 13, 2)
    ball = boots(hem(ball, 0), PLAYER_FEET["tuck"])
    for y in (5, 9, 13):
        ball.line(0, y, 1, y, c("pale"))
    dodge = [squash, ball, squash]

    outline = {c("outline")}
    hurt = [base.recolor(outline, c("white")), base.recolor(outline, c("red"))]

    # 쓰러짐: 무릎 꿇기 → 옆으로 쓰러져 누움 (따로 그린 프레임)
    lying = Canvas.from_rows(PLAYER_LYING, PLAYER_CMAP)
    death = [hem(base.shift_rows(0, 13, 1), 1), hem(base.shift_rows(0, 13, 3), 0), lying.moved(0, -1), lying]

    save_sheet("player", 16, 16, [
        ("idle", idle, 4.0, True),
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


def tile_pit() -> Canvas:
    """구덩이: 플레이어는 못 건너지만 탄은 지나간다."""
    t = Canvas(16, 16)
    t.fill(c("outline"))
    t.line(0, 0, 15, 0, c("stone_dark"))
    t.line(0, 1, 15, 1, c("shadow"))
    t.line(0, 2, 15, 2, c("shadow"))
    for x in range(0, 16, 5):
        t.set(x + 2, 3, c("shadow"))
    return t


def build_tiles() -> None:
    rng = random.Random(1001)  # 고정 시드
    tiles = [
        ("floor", tile_floor(rng, False)),
        ("floor_alt", tile_floor(rng, True)),
        ("wall_top", tile_wall_top()),
        ("wall_face", tile_wall_face()),
        ("pit", tile_pit()),
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
        ("combo_aura", build_combo_aura(), 10.0, True),
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


def gate_frame(open_: bool) -> Canvas:
    t = Canvas(16, 16)
    for x in (0, 15):
        t.line(x, 0, x, 15, c("outline"))
    for x in (1, 14):
        t.line(x, 0, x, 15, c("stone_light"))
    if open_:
        t.line(2, 0, 13, 0, c("stone_dark"))
        t.line(2, 1, 13, 1, c("stone"))
        return t
    t.line(2, 0, 13, 0, c("outline"))
    t.line(2, 15, 13, 15, c("outline"))
    for x in (3, 6, 9, 12):
        t.line(x, 1, x, 14, c("stone_light"))
        t.line(x + 1, 1, x + 1, 14, c("stone_dark"))
    t.line(2, 7, 13, 7, c("brown"))
    t.line(2, 8, 13, 8, c("brown_dark"))
    return t


def spike_frame(stage: int) -> Canvas:
    """0 = 내려감(판과 구멍), 1 = 예고(판 테두리가 주황), 2 = 올라옴(큰 가시)"""
    t = Canvas(16, 16)
    rim = c("orange") if stage == 1 else c("shadow")
    for x in range(1, 15):
        t.set(x, 1, rim)
        t.set(x, 14, rim)
    for y in range(1, 15):
        t.set(1, y, rim)
        t.set(14, y, rim)
    for cx, cy in ((5, 6), (10, 6), (5, 12), (10, 12)):
        if stage < 2:
            t.set(cx, cy, c("outline"))
            t.set(cx + 1, cy, c("outline"))
            if stage == 1:
                t.set(cx, cy - 1, c("pale"))
                t.set(cx + 1, cy - 1, c("pale"))
        else:
            # 높이 5, 밑변 4 의 삼각 가시
            for h in range(5):
                half = 2 - h // 2
                for dx in range(-half, half + 1):
                    x = cx + dx if dx <= 0 else cx + dx
                    color = c("white") if dx >= 0 else c("pale")
                    t.set(x, cy - h, color)
            t.set(cx - 2, cy, c("outline"))
            t.set(cx + 3, cy, c("outline"))
    return t


def switch_frame(on: bool) -> Canvas:
    rows = [
        "......oo........",
        ".....occo.......",
        "....occcco......",
        "...occCccco.....",
        "...occCcccco....",
        "..occCCccccco...",
        "..occCccccccco..",
        "...occcccccco...",
        "....occcccco....",
        ".....occcco.....",
        "......occo......",
        ".....oSSSSo.....",
        "....oSSSSSSo....",
        "...oSSSSSSSSo...",
        "...oooooooooo...",
        "................",
    ]
    cmap = {".": None, "o": "outline", "c": "cyan" if on else "blue",
            "C": "white" if on else "sky", "S": "stone"}
    cv = Canvas.from_rows(rows, cmap)
    if on:
        for x, y in ((12, 1), (13, 3), (2, 2)):
            cv.set(x, y, c("yellow"))
    return cv


def boulder_frame(phase: int) -> Canvas:
    t = Canvas(16, 16)
    for y in range(16):
        for x in range(16):
            d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
            if d <= 6.0:
                t.set(x, y, c("stone"))
            elif d <= 7.0:
                t.set(x, y, c("outline"))
    # 굴러가는 느낌: 금 무늬 위치가 프레임마다 바뀜
    marks = [((5, 5), (6, 6), (9, 10)), ((9, 4), (10, 5), (5, 10))][phase]
    for x, y in marks:
        t.set(x, y, c("stone_dark"))
    t.set(5 + phase * 3, 4, c("stone_light"))
    return t


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
        ("gate_closed", [gate_frame(False)], 1.0, False),
        ("gate_open", [gate_frame(True)], 1.0, False),
        ("spike_down", [spike_frame(0)], 1.0, False),
        ("spike_warn", [spike_frame(1)], 1.0, False),
        ("spike_up", [spike_frame(2)], 1.0, False),
        ("switch_off", [switch_frame(False)], 1.0, False),
        ("switch_on", [switch_frame(True)], 1.0, False),
        ("boulder", [boulder_frame(0), boulder_frame(1)], 8.0, True),
        ("sign", [Canvas.from_rows(SIGN, {".": None, "o": "outline", "b": "tan", "t": "brown_dark", "B": "brown"})], 1.0, False),
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


def build_combo_aura() -> list[Canvas]:
    """콤보 단계 표시: 발밑을 도는 불꽃 고리 (게임에서 단계별 색·크기)."""
    import math
    frames = []
    for phase in range(4):
        cv = Canvas(16, 16)
        for k in range(6):
            a = math.radians(k * 60 + phase * 15)
            x, y = round(7.5 + 6.5 * math.cos(a)), round(9.5 + 4.0 * math.sin(a))
            cv.set(x, y, c("white"))
            cv.set(x, y - 1, c("yellow"))
        frames.append(cv)
    return frames


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
# 스킬 아이콘 (16x16) · 스킬 이펙트
# ---------------------------------------------------------------------------
def icon_frame() -> Canvas:
    t = Canvas(16, 16)
    t.fill(c("shadow"))
    t.line(0, 0, 15, 0, c("outline"))
    t.line(0, 15, 15, 15, c("outline"))
    t.line(0, 0, 0, 15, c("outline"))
    t.line(15, 0, 15, 15, c("outline"))
    t.line(1, 1, 14, 1, c("stone_dark"))
    return t


def build_skill_icons() -> None:
    import math
    # 블링크: 화살표 + 잔상
    blink = icon_frame()
    for i, col in enumerate(("stone", "sky", "cyan")):
        x = 3 + i * 3
        blink.line(x, 5, x, 10, c(col))
    blink.line(11, 4, 13, 7, c("white"))
    blink.line(13, 8, 11, 11, c("white"))
    blink.line(10, 7, 13, 7, c("white"))
    blink.line(10, 8, 13, 8, c("white"))
    # 흡수 장막: 호 + 빨려드는 탄
    absorb = icon_frame()
    for x, y in arc_pixels(4, 7.5, 7, -70, 70):
        absorb.set(x, y, c("cyan"))
    for x, y in arc_pixels(4, 7.5, 6, -55, 55):
        absorb.set(x, y, c("sky"))
    absorb.set(5, 7, c("red"))
    absorb.set(6, 8, c("red"))
    absorb.set(3, 8, c("yellow"))
    # 미끼 분신: 사람 두 개 (하나는 흐림)
    decoy = icon_frame()
    for ox, col in ((2, "stone"), (7, "blue")):
        decoy.line(ox + 2, 3, ox + 4, 3, c(col))
        for y in range(4, 7):
            decoy.line(ox + 1, y, ox + 5, y, c(col))
        for y in range(7, 12):
            decoy.line(ox + 2, y, ox + 4, y, c(col))
        decoy.set(ox + 4, 5, c("skin") if col == "blue" else c("pale"))
    # 충격파: 동심원
    shock = icon_frame()
    for r, col in ((2, "white"), (4.5, "yellow"), (6.5, "orange")):
        for y in range(16):
            for x in range(16):
                d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
                if abs(d - r) < 0.55 and 1 <= x <= 14 and 2 <= y <= 14:
                    shock.set(x, y, c(col))
    # 표식: 과녁
    mark = icon_frame()
    for y in range(16):
        for x in range(16):
            d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
            if abs(d - 5.5) < 0.6 or abs(d - 2.5) < 0.6:
                mark.set(x, y, c("red"))
    mark.line(7, 2, 7, 4, c("white"))
    mark.line(8, 11, 8, 13, c("white"))
    mark.line(2, 8, 4, 8, c("white"))
    mark.line(11, 7, 13, 7, c("white"))
    save_sheet("skill_icons", 16, 16, [
        ("blink", [blink], 1.0, False),
        ("absorb", [absorb], 1.0, False),
        ("decoy", [decoy], 1.0, False),
        ("shockwave", [shock], 1.0, False),
        ("mark", [mark], 1.0, False),
    ])

    # 흡수 장막: 오른쪽 기준 큰 호 (게임에서 회전)
    barrier = []
    for phase in (0, 1):
        cv = Canvas(16, 16)
        for x, y in arc_pixels(2, 7.5, 11, -60, 60, 40):
            cv.set(x, y, c("cyan"))
        for x, y in arc_pixels(2, 7.5, 10, -50, 50, 40):
            cv.set(x, y, c("sky") if (x + y + phase) % 2 == 0 else c("cyan"))
        barrier.append(cv)
    # 충격파 고리 (게임에서 크게)
    wave = []
    for r in (2.5, 4.5, 6.5, 7.5):
        cv = Canvas(16, 16)
        for y in range(16):
            for x in range(16):
                d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
                if abs(d - r) < 0.6:
                    cv.set(x, y, c("yellow") if r < 6 else c("orange"))
        wave.append(cv)
    # 표식: 적 머리 위 과녁 (8x8 를 16 칸 가운데에)
    mk = []
    for phase in (0, 1):
        cv = Canvas(16, 16)
        for y in range(16):
            for x in range(16):
                d = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5
                if abs(d - (3.5 if phase == 0 else 3.0)) < 0.6:
                    cv.set(x, y, c("red"))
        cv.set(7, 7, c("white"))
        cv.set(8, 8, c("white"))
        mk.append(cv)
    save_sheet("skill_fx", 16, 16, [
        ("barrier", barrier, 10.0, True),
        ("shockwave", wave, 16.0, False),
        ("mark", mk, 4.0, True),
    ])


SIGN = [
    "................",
    "..oooooooooooo..",
    "..obbbbbbbbbbo..",
    "..obttttttttbo..",
    "..obbbbbbbbbbo..",
    "..obttttttbbbo..",
    "..obbbbbbbbbbo..",
    "..oooooooooooo..",
    "......oBBo......",
    "......oBBo......",
    "......oBBo......",
    "......oBBo......",
    "......oBBo......",
    ".....oBBBBo.....",
    "....oooooooo....",
    "................",
]


# ---------------------------------------------------------------------------
# 탄막 골렘 (48x48). 가슴의 코어가 약점 (반사탄으로만 제대로 맞음)
# 돌덩이 부위를 뒤 → 앞 순서로 쌓아 그린다. 부위마다 테두리 + 왼쪽 위 빛 명암 + 돌 얼룩.
# ---------------------------------------------------------------------------
## 이 높이 이상 들면 주먹을 머리 위로 치켜든 자세로 그린다
RAISED_ARM = 10


class GolemPose:
    """한 프레임의 자세·색. 기본값 = 평소 대기."""

    def __init__(self, **kw):
        self.bob = 0            # 몸통·머리·팔이 내려가는 정도 (숨쉬기)
        self.arm_l = 0          # 왼팔 들어올림 (px)
        self.arm_r = 0          # 오른팔 들어올림
        self.step = 0           # 걸음: -1 왼발 듦 / 1 오른발 듦
        self.slump = 0          # 그로기: 머리·팔 처짐
        self.core = "cyan"      # 코어 색
        self.core_hi = "white"  # 코어 하이라이트
        self.core_glow = False  # 코어 주변 빛 번짐
        self.eye = "yellow"
        self.rune = "blue"      # 어깨 룬 (평소 흐림, 공격 시 밝게)
        self.crack = "shadow"   # 금 색 (각성 시 주황)
        self.stars = -1         # 그로기 별 회전 위치 (-1 = 없음)
        self.sparks = 0         # 각성·필살기 파편 (0 = 없음, 1~ = 프레임)
        for k, v in kw.items():
            setattr(self, k, v)


def _stone_part(t: Canvas, inside, x0: int, y0: int, x1: int, y1: int, seed: int,
                base: str = "stone", hi: str = "stone_light", lo: str = "stone_dark") -> None:
    """inside(x, y) 로 정의된 돌덩이 하나: 테두리(outline) + 위·왼쪽 밝게 + 아래·오른쪽 어둡게 + 얼룩."""
    rng = random.Random(seed)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if not inside(x, y):
                continue
            edge = not (inside(x - 1, y) and inside(x + 1, y) and inside(x, y - 1) and inside(x, y + 1))
            if edge:
                t.set(x, y, c("outline"))
                continue
            top = not inside(x, y - 2)
            left = not inside(x - 2, y)
            bottom = not inside(x, y + 2)
            right = not inside(x + 2, y)
            if top or (left and not bottom):
                col = hi
            elif bottom or right:
                col = lo
            else:
                col = base
            # 돌 얼룩 (같은 시드 = 매번 같은 무늬)
            r = rng.random()
            if col == base and r < 0.07:
                col = lo
            elif col == base and r < 0.10:
                col = hi
            t.set(x, y, c(col))


def _rrect(x0: int, y0: int, x1: int, y1: int, r: int):
    """모서리가 둥근 사각형 안쪽 판정 함수."""
    def inside(x, y):
        if x < x0 or x > x1 or y < y0 or y > y1:
            return False
        cx = min(max(x, x0 + r), x1 - r)
        cy = min(max(y, y0 + r), y1 - r)
        return (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.5
    return inside


def _trapezoid(x0_top: int, x1_top: int, x0_bot: int, x1_bot: int, y0: int, y1: int, r: int = 2):
    """위가 넓고 아래가 좁은 몸통."""
    def inside(x, y):
        if y < y0 or y > y1:
            return False
        f = (y - y0) / max(y1 - y0, 1)
        left = x0_top + (x0_bot - x0_top) * f
        right = x1_top + (x1_bot - x1_top) * f
        if x < left - 0.01 or x > right + 0.01:
            return False
        # 위쪽 모서리 둥글게
        if y < y0 + r:
            if x < x0_top + r and (x - (x0_top + r)) ** 2 + (y - (y0 + r)) ** 2 > r * r + 0.5:
                return False
            if x > x1_top - r and (x - (x1_top - r)) ** 2 + (y - (y0 + r)) ** 2 > r * r + 0.5:
                return False
        return True
    return inside


def golem_frame(p: GolemPose) -> Canvas:
    t = Canvas(48, 48)
    b = p.bob
    s = p.slump

    # --- 다리·발 (맨 뒤) ---
    for lx, lift in ((12, p.step == -1), (28, p.step == 1)):
        dy = -1 if lift else 0
        _stone_part(t, _rrect(lx + 1, 36 + dy, lx + 7, 44 + dy, 1), lx + 1, 36 + dy, lx + 7, 44 + dy, 11 + lx,
                    base="stone_dark", hi="stone", lo="shadow")
        _stone_part(t, _rrect(lx, 42 + dy, lx + 8, 47 + dy, 2), lx, 42 + dy, lx + 8, 47 + dy, 13 + lx)

    # --- 허리 ---
    _stone_part(t, _rrect(14, 31 + b, 33, 39 + b, 2), 14, 31 + b, 33, 39 + b, 21,
                base="stone_dark", hi="stone", lo="shadow")

    # --- 몸통 (넓은 가슴) ---
    torso = _trapezoid(8, 39, 13, 34, 12 + b, 35 + b, 3)
    _stone_part(t, torso, 8, 12 + b, 39, 35 + b, 31)
    # 가슴 판 이음새
    t.line(15, 30 + b, 32, 30 + b, c("stone_dark"))
    t.line(23, 31 + b, 23, 34 + b, c("stone_dark"))
    # 금
    t.line(12, 16 + b, 15, 22 + b, c(p.crack))
    t.line(15, 22 + b, 14, 26 + b, c(p.crack))
    t.line(36, 15 + b, 33, 20 + b, c(p.crack))
    t.line(30, 31 + b, 33, 34 + b, c(p.crack))

    # --- 코어 (가슴 가운데): 홈 → 코어 → 하이라이트 ---
    cx, cy = 24, 22 + b
    for y in range(cy - 8, cy + 9):
        for x in range(cx - 8, cx + 9):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= 6.6 and d > 5.5:
                t.set(x, y, c("shadow"))          # 홈 테두리
            elif d <= 5.5 and d > 4.6:
                t.set(x, y, c("outline"))
            elif d <= 4.6:
                # 아래·오른쪽은 진하게
                dark = (x - cx) + (y - cy) > 2.5
                t.set(x, y, c(p.core) if not dark else c({"cyan": "sky", "sky": "blue", "orange": "red",
                                                            "yellow": "orange", "red": "crimson",
                                                            "white": "cyan"}.get(p.core, p.core)))
            elif p.core_glow and d <= 7.6 and (x + y) % 2 == 0:
                t.set(x, y, c(p.core))            # 빛 번짐 (점점이)
    t.set(cx - 2, cy - 2, c(p.core_hi))
    t.set(cx - 1, cy - 3, c(p.core_hi))
    t.set(cx - 3, cy - 1, c(p.core_hi))

    # --- 팔 (어깨 아래로 늘어뜨림) + 주먹. 높이 들면(필살기) 머리 위로 올라가므로 나중에 그림 ---
    for side in (-1, 1):
        lift = p.arm_l if side < 0 else p.arm_r
        if lift >= RAISED_ARM:
            continue
        ax0 = 2 if side < 0 else 37
        ay0 = 18 + b + s - lift
        _stone_part(t, _rrect(ax0 + 1, ay0, ax0 + 8, ay0 + 14, 2), ax0 + 1, ay0, ax0 + 8, ay0 + 14, 41 + side)
        fx0 = 0 if side < 0 else 36
        fy0 = ay0 + 12
        _stone_part(t, _rrect(fx0, fy0, fx0 + 11, fy0 + 9, 3), fx0, fy0, fx0 + 11, fy0 + 9, 43 + side)
        # 손가락 마디
        for k in range(3):
            t.set(fx0 + 3 + k * 3, fy0 + 7, c("stone_dark"))

    # --- 어깨 바위 (팔 위를 덮음) + 룬 + 이끼 ---
    for side in (-1, 1):
        sx0 = 1 if side < 0 else 33
        sy0 = 9 + b + s // 2 - (min(p.arm_l if side < 0 else p.arm_r, 6) // 2)
        _stone_part(t, _rrect(sx0, sy0, sx0 + 13, sy0 + 11, 4), sx0, sy0, sx0 + 13, sy0 + 11, 51 + side)
        # 룬: 작은 ㅅ 모양 문양
        rx, ry = sx0 + 6, sy0 + 5
        for dx, dy in ((0, 0), (-1, 1), (1, 1), (0, -1), (-2, 2), (2, 2)):
            t.set(rx + dx, ry + dy, c(p.rune))
        # 이끼 (어깨 윗면)
        for dx in (2, 3, 5, 9, 10):
            t.set(sx0 + dx, sy0 + 1, c("green") if dx % 2 else c("green_dark"))
        t.set(sx0 + 3, sy0 + 2, c("green_dark"))

    # --- 머리 (어깨 사이에 박힘) ---
    hy = 3 + b + s
    _stone_part(t, _rrect(17, hy, 30, hy + 11, 3), 17, hy, 30, hy + 11, 61)
    # 이마 튀어나온 부분
    t.line(18, hy + 4, 29, hy + 4, c("stone_dark"))
    t.line(19, hy + 3, 28, hy + 3, c("stone_light"))
    # 눈 (빛나는 틈)
    for ex in (20, 25):
        t.line(ex, hy + 6, ex + 2, hy + 6, c(p.eye))
        t.set(ex + 1, hy + 7, c(p.eye))
    t.line(20, hy + 9, 27, hy + 9, c("stone_dark"))  # 입
    t.set(19, hy + 1, c("green"))
    t.set(20, hy + 1, c("green_dark"))

    # --- 머리 위로 치켜든 팔·주먹 (어깨·머리보다 앞) ---
    for side in (-1, 1):
        lift = p.arm_l if side < 0 else p.arm_r
        if lift < RAISED_ARM:
            continue
        top = max(0, 14 - lift)                 # 높이 들수록 위로
        ax0 = 6 if side < 0 else 33
        _stone_part(t, _rrect(ax0, top + 6, ax0 + 8, 18 + b, 2), ax0, top + 6, ax0 + 8, 18 + b, 71 + side)
        fx0 = ax0 - 2 + (1 if side < 0 else 0)
        _stone_part(t, _rrect(fx0, top, fx0 + 11, top + 9, 3), fx0, top, fx0 + 11, top + 9, 73 + side)
        for k in range(3):
            t.set(fx0 + 3 + k * 3, top + 2, c("stone_dark"))

    # --- 그로기 별 (머리 위를 도는) ---
    if p.stars >= 0:
        import math
        for k in range(3):
            a = math.radians(p.stars * 40 + k * 120)
            sx, sy = round(24 + 9 * math.cos(a)), round(hy - 2 + 2.5 * math.sin(a))
            for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)):
                t.set(sx + dx, sy + dy, c("yellow") if (dx, dy) != (0, 0) else c("white"))

    # --- 파편 (각성·필살기) ---
    if p.sparks:
        rng = random.Random(900 + p.sparks)
        for _ in range(10):
            x, y = rng.randrange(2, 46), rng.randrange(1, 30)
            if t.px[y][x] is None:
                t.set(x, y, c("orange") if rng.random() < 0.5 else c("yellow"))
    return t


def build_golem() -> None:
    outline = {c("outline")}
    P = GolemPose
    idle = [P(), P(bob=0), P(bob=1, core="sky"), P(bob=1, core="sky")]
    move = [P(step=-1), P(bob=1), P(step=1), P(bob=1)]
    attack = [P(arm_l=4, arm_r=4, core="orange", rune="cyan", core_glow=True),
              P(arm_l=7, arm_r=7, core="yellow", rune="cyan", core_glow=True),
              P(arm_l=5, arm_r=5, core="orange", rune="sky", core_glow=True)]
    base_flash = golem_frame(P())
    hurt = [base_flash.recolor(outline, c("white")), golem_frame(P())]
    core_hit = [golem_frame(P(core="white", core_hi="white", core_glow=True)), golem_frame(P(core="cyan", core_glow=True))]
    groggy = [P(slump=3, core="blue", core_hi="sky", eye="stone_dark", rune="navy", stars=i) for i in range(3)]
    awaken = [P(core="red", eye="red", rune="red", crack="orange", core_glow=True, sparks=1),
              P(bob=1, core="red", eye="orange", rune="orange", crack="orange", core_glow=True, sparks=2),
              P(arm_l=3, arm_r=3, core="white", core_hi="yellow", eye="red", rune="red", crack="orange", core_glow=True, sparks=3)]
    special = [P(arm_l=12, arm_r=12, core="white", core_hi="yellow", eye="red", rune="orange", crack="orange", core_glow=True, sparks=4),
               P(arm_l=14, arm_r=14, core="red", core_hi="white", eye="white", rune="red", crack="orange", core_glow=True, sparks=5)]
    save_sheet("golem", 48, 48, [
        ("idle", [golem_frame(p) for p in idle], 4.0, True),
        ("move", [golem_frame(p) for p in move], 6.0, True),
        ("attack", [golem_frame(p) for p in attack], 8.0, True),
        ("hurt", hurt, 12.0, False),
        ("core_hit", core_hit, 12.0, False),
        ("groggy", [golem_frame(p) for p in groggy], 6.0, True),
        ("awaken", [golem_frame(p) for p in awaken], 6.0, True),
        ("special", [golem_frame(p) for p in special], 8.0, True),
    ])


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
def build_icon() -> None:
    """창·exe 아이콘 (64x64): 플레이어를 4배로."""
    base = Canvas.from_rows(PLAYER_BASE, PLAYER_CMAP)
    img = Image.new("RGBA", (64, 64), (*PAL_RGB[c("shadow")], 255))
    img.alpha_composite(base.to_image().resize((64, 64), Image.NEAREST))
    img.save(ROOT / "art" / "icon.png", optimize=False)


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
    build_skill_icons()
    build_golem()
    build_icon()
    verify_palette()
    print(f"스프라이트 생성 완료: {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
