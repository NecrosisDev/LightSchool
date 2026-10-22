"""Draw the Light school icon sheet (thmlgtico1): original, procedurally painted images.

The game picks a power's icon from its school's sheet in 512x512 cells: cell (power & 0xff) - 1,
left to right and top to bottom, cells per row = sheet width / 512 (0x1d5c00, 0x1d3e30). Each cell
is a painted scene inside a black disc, usually with a figure or hand working the power; each cell
here has the caster's hand reaching toward the effect. This sheet is 2048x2048 (four cells per row)
with nine:
  1 Light Orb  a warm-white orb hovering in a dark stone alcove
  2 Kindle     a wall torch bursting into flame, sparks rising
  3 Snuff      a smoking, freshly put-out wall torch in cold dark
  4 Flare      a blinding white burst with sharp rays and a shock ring
  5 Radiance   a column of light settling on a glowing floor ring
  6 Beacon     a small steady star left hanging in the dark
  7 Guiding    a raised light crowned with warm rays
  8 Glare      a narrow searing beam thrown from the palm
  9 Searing    a hanging star burning a ringed, branded floor below it
Nothing is copied from the game. Needs only Pillow.

    python -X utf8 -B mods/light-orb/icon.py out.png
"""
import math
import random
import sys

from PIL import Image, ImageFilter

CELL = 512
SEED = 0x20501


def noise(rng: random.Random, octaves: int) -> list[float]:
    """Fractal value noise in [0, 1], row-major, one cell in size."""
    total = [0.0] * (CELL * CELL)
    weight, amplitude = 0.0, 1.0
    for o in range(octaves):
        cells = 4 * 2 ** o + 1
        small = Image.new('L', (cells, cells))
        small.putdata([rng.randrange(256) for _ in range(cells * cells)])
        for i, v in enumerate(small.resize((CELL, CELL), Image.BICUBIC).tobytes()):
            total[i] += amplitude * v / 255
        weight += amplitude
        amplitude *= 0.5
    return [v / weight for v in total]


def gauss(dx: float, dy: float, sx: float, sy: float) -> float:
    return math.exp(-((dx / sx) ** 2 + (dy / sy) ** 2))


# The caster's hand reaching toward each effect, as the game's own power icons show a figure or hand
# working the power: (angle the fingers point, radians in image space; wrist distance from the light;
# finger spread; finger curl 0..1).
HAND_POSES = {
    'orb': (-1.2, 250, 0.22, 0.1),
    'kindle': (-0.55, 235, 0.18, 0.2),
    'snuff': (-0.35, 160, 0.05, 0.6),
    'flare': (-math.pi / 2, 235, 0.32, 0.0),
    'sanctuary': (-math.pi / 2, 205, 0.26, 0.05),
    'beacon': (-1.0, 240, 0.2, 0.3),
    'rally': (-math.pi / 2 + 0.25, 225, 0.3, 0.0),
    'glare': (-0.15, 270, 0.12, 0.1),
    'hallowed': (-1.3, 230, 0.24, 0.15),
}
HAND_SCALE = 1.1
SKIN = (0.62, 0.42, 0.32)
SUPERSAMPLE = 2


def hand_mask(lx: float, ly: float, pose) -> tuple[list[float], list[float]]:
    """Coverage of a right hand seen from the back (0..1, row-major), and the same mask blurred,
    whose slope gives the hand's rounded shading."""
    from PIL import ImageDraw
    angle, reach, spread, curl = pose
    s, k = HAND_SCALE, SUPERSAMPLE
    ux, uy = math.cos(angle), math.sin(angle)
    wx, wy = lx - ux * reach, ly - uy * reach
    big = Image.new('L', (CELL * k, CELL * k))
    pen = ImageDraw.Draw(big)

    def limb(x0, y0, x1, y1, width):
        pen.line([(x0 * k, y0 * k), (x1 * k, y1 * k)], fill=255, width=int(width * k))
        for x, y in ((x0, y0), (x1, y1)):
            r = width * k / 2
            pen.ellipse([x * k - r, y * k - r, x * k + r, y * k + r], fill=255)

    limb(wx - ux * 400, wy - uy * 400, wx, wy, 78 * s)                       # forearm, off the disc
    px, py = wx + ux * 52 * s, wy + uy * 52 * s
    r = 50 * s * k
    pen.ellipse([px * k - r, py * k - r * 1.05, px * k + r, py * k + r * 1.05], fill=255)   # palm
    for i, length in enumerate((88, 100, 96, 80)):                              # index .. little finger
        offset = (i - 1.5) * 22 * s
        bx, by = px + ux * 38 * s - uy * offset, py + uy * 38 * s + ux * offset
        a = angle + (i - 1.5) * spread
        n = length * s * (1 - 0.6 * curl)
        limb(bx, by, bx + math.cos(a) * n, by + math.sin(a) * n, 21 * s)
    ta = angle - 0.95                                                            # thumb
    tx, ty = px - uy * 40 * s, py + ux * 40 * s
    n = 70 * s * (1 - 0.4 * curl)
    limb(tx, ty, tx + math.cos(ta) * n, ty + math.sin(ta) * n, 24 * s)
    small = big.resize((CELL, CELL), Image.LANCZOS)
    soft = small.filter(ImageFilter.GaussianBlur(9))
    return [v / 255 for v in small.tobytes()], [v / 255 for v in soft.tobytes()]


def shade_hand(rgb, i, x, y, lx, ly, tint, strength, coverage, soft, rough):
    """Skin lit from the effect: a strong rim on edges facing the light, soft fill elsewhere."""
    a = coverage[i]
    if a <= 0:
        return rgb
    gx = soft[i + 1] - soft[i - 1] if 0 < x < CELL - 1 else 0.0
    gy = soft[i + CELL] - soft[i - CELL] if 0 < y < CELL - 1 else 0.0
    dx, dy = lx - x, ly - y
    distance = math.hypot(dx, dy) or 1.0
    # The blurred mask falls off toward the hand's edges, so -gradient points out of the hand.
    facing = max(0.0, -(gx * dx + gy * dy) / distance) * 9.0
    near = strength / (1.0 + (distance / 130.0) ** 2)
    grain = 0.85 + 0.3 * rough[i]
    skin = [c * grain * (0.04 + near * (0.22 + 2.4 * min(facing, 1.0)) * t) for c, t in zip(SKIN, tint)]
    return [b * (1 - a) + h * a for b, h in zip(rgb, skin)]


def cell(kind: str, rng: random.Random) -> Image.Image:
    rough, coarse, wisp = noise(rng, 5), noise(rng, 3), noise(rng, 4)
    half = CELL / 2
    # Light source and colour per scene.
    if kind == 'orb':
        lx, ly, falloff, tint, ambient = CELL * 0.52, CELL * 0.44, 105.0, (1.0, 0.86, 0.62), (0.35, 0.45, 0.7)
    elif kind == 'flare':
        lx, ly, falloff, tint, ambient = CELL * 0.5, CELL * 0.47, 230.0, (1.0, 0.95, 0.85), (0.35, 0.45, 0.7)
    elif kind == 'sanctuary':
        lx, ly, falloff, tint, ambient = CELL * 0.5, CELL * 0.62, 150.0, (1.0, 0.9, 0.68), (0.45, 0.55, 0.85)
    elif kind == 'rally':
        lx, ly, falloff, tint, ambient = CELL * 0.5, CELL * 0.3, 160.0, (1.0, 0.82, 0.5), (0.4, 0.45, 0.6)
    elif kind == 'beacon':
        lx, ly, falloff, tint, ambient = CELL * 0.58, CELL * 0.4, 80.0, (0.7, 0.85, 1.0), (0.3, 0.35, 0.5)
    elif kind == 'glare':
        lx, ly, falloff, tint, ambient = CELL * 0.62, CELL * 0.45, 70.0, (1.0, 0.98, 0.92), (0.3, 0.35, 0.5)
    elif kind == 'hallowed':
        lx, ly, falloff, tint, ambient = CELL * 0.5, CELL * 0.3, 140.0, (1.0, 0.62, 0.3), (0.35, 0.3, 0.3)
    elif kind == 'kindle':
        lx, ly, falloff, tint, ambient = CELL * 0.5, CELL * 0.36, 95.0, (1.0, 0.62, 0.28), (0.3, 0.3, 0.4)
    else:
        lx, ly, falloff, tint, ambient = CELL * 0.5, CELL * 0.36, 40.0, (0.9, 0.35, 0.15), (0.45, 0.6, 1.0)
    coverage, soft = hand_mask(lx, ly, HAND_POSES[kind])
    strength = 1.6 if kind != 'snuff' else 0.35
    ambient_level = 0.035 if kind != 'snuff' else 0.12
    count = 46 if kind != 'snuff' else 0
    motes = []
    for _ in range(count):
        a, d = rng.uniform(0, 2 * math.pi), rng.uniform(40, 190)
        if kind == 'kindle':          # sparks rise above the flame
            mx, my = lx + rng.uniform(-70, 70), ly - rng.uniform(20, 200)
        else:
            mx, my = lx + math.cos(a) * d, ly + math.sin(a) * d * 0.8
        motes.append((mx, my, rng.uniform(1.2, 3.2), rng.uniform(0.3, 1.0) * math.exp(-math.hypot(mx - lx, my - ly) / 160)))
    pixels = []
    for y in range(CELL):
        block = math.floor(y / 74.0)
        row = (y / 74.0) % 1.0
        for x in range(CELL):
            i = y * CELL + x
            # Rough stone with darker mortar lines on a staggered block grid.
            col = ((x + 37 * block) / 118.0) % 1.0
            mortar = min(min(row, 1 - row) * 74, min(col, 1 - col) * 118)
            stone = (0.55 * rough[i] + 0.45 * coarse[i]) * (0.55 + 0.45 * min(mortar / 6.0, 1.0))
            dx, dy = x - lx, y - ly
            r = math.hypot(dx, dy)
            light = strength / (1.0 + (r / falloff) ** 2)
            rgb = [stone * (light * t + ambient_level * a) for t, a in zip(tint, ambient)]
            if kind == 'orb':
                core = math.exp(-(r / 22.0) ** 2) * 1.8
                body = math.exp(-(r / 44.0) ** 4) * 1.1
                halo = math.exp(-(r / 95.0) ** 2) * 0.35
                rays = (0.5 + 0.5 * math.cos(math.atan2(dy, dx) * 9 + 0.6)) ** 6 * math.exp(-r / 150.0) * (0.6 + 0.8 * wisp[i]) * 0.1
                add = (core + body + halo + rays, core + body * 0.9 + halo * 0.78 + rays * 0.85, core + body * 0.65 + halo * 0.45 + rays * 0.55)
            elif kind == 'flare':
                # A blinding burst: wide white core, long sharp rays, a bright ring of the shock.
                core = math.exp(-(r / 48.0) ** 2) * 3.0
                rays = (0.5 + 0.5 * math.cos(math.atan2(dy, dx) * 12)) ** 14 * math.exp(-r / 260.0) * (0.7 + 0.6 * wisp[i]) * 1.4
                ring = math.exp(-((r - 150.0) / 14.0) ** 2) * 0.45 * (0.6 + 0.8 * wisp[i])
                add = (core + rays + ring, core + rays * 0.95 + ring * 0.9, core + rays * 0.8 + ring * 0.7)
            elif kind == 'beacon':
                # A small steady star left hanging in the dark, with a faint pool on the floor below it.
                core = math.exp(-(r / 12.0) ** 2) * 1.8
                halo = math.exp(-(r / 60.0) ** 2) * 0.45
                pool = gauss(dx, dy - 200, 90, 18) * 0.35
                add = (core * 0.9 + halo * 0.7 + pool * 0.6, core + halo * 0.85 + pool * 0.75, core + halo + pool)
            elif kind == 'rally':
                # A raised light with a warm crown of rays spreading outward, lighting the space around it.
                core = math.exp(-(r / 26.0) ** 2) * 1.9
                crown = math.exp(-((r - 90.0) / 16.0) ** 2) * (0.5 + 0.5 * math.cos(math.atan2(dy, dx) * 16)) ** 3 * 0.9
                glow = math.exp(-(r / 130.0) ** 2) * 0.4
                add = (core + crown + glow, core + crown * 0.85 + glow * 0.8, core * 0.85 + crown * 0.5 + glow * 0.5)
            elif kind == 'glare':
                # A narrow searing beam thrown sideways from the palm, brightest at its tip.
                beam = gauss(0, dy, 1, 7 + 0.05 * max(dx + 120, 0)) * (1.0 if -120 < dx < 230 else 0.0) * math.exp(-max(dx, 0) / 260.0) * 1.2
                core = math.exp(-(r / 16.0) ** 2) * 2.2
                streak = (0.5 + 0.5 * math.cos(math.atan2(dy, dx) * 4)) ** 30 * math.exp(-r / 120.0) * 0.8
                add = (core + beam + streak, core + beam * 0.97 + streak * 0.95, core + beam * 0.9 + streak * 0.85)
            elif kind == 'hallowed':
                # A hanging star whose light falls in a pale cone onto a floor marked with a ring and cross.
                core = math.exp(-(r / 13.0) ** 2) * 1.8
                cone = gauss(dx, 0, 30 + 0.45 * max(dy, 0), 1) * (1.0 if dy > 0 else 0.0) * math.exp(-max(dy, 0) / 420.0) * 0.4
                fx, fy = dx, (dy - 210) * 3.0
                ring = math.exp(-((math.hypot(fx, fy) - 110.0) / 8.0) ** 2) * 0.9
                cross = (gauss(fx, 0, 4, 1) + gauss(0, fy, 1, 4)) * (1.0 if math.hypot(fx, fy) < 100 else 0.0) * 0.7
                add = (core + cone + ring + cross, core * 0.8 + cone * 0.6 + ring * 0.55 + cross * 0.55, core * 0.55 + cone * 0.3 + ring * 0.25 + cross * 0.25)
            elif kind == 'sanctuary':
                # A soft column of light settling onto a glowing ring on the floor.
                column = gauss(dx, 0, 46, 1) * (0.35 + 0.65 * max(0.0, min(1.0, (y - 40) / 260.0))) * (0.7 + 0.5 * wisp[i]) * 0.8
                ring = math.exp(-((math.hypot(dx, dy * 3.2) - 120.0) / 9.0) ** 2) * 1.1
                pool = gauss(dx, dy, 120, 38) * 0.6
                add = (column + ring + pool, column * 0.92 + ring * 0.9 + pool * 0.88, column * 0.72 + ring * 0.62 + pool * 0.6)
            else:
                # The torch: a dark wooden haft below the head, an iron bracket band across it.
                haft = 1.0 if abs(dx) < 11 - 0.02 * max(dy, 0) and 6 < dy < 190 else 0.0
                band = 1.0 if abs(dx) < 19 and 70 < dy < 84 else 0.0
                wood = 0.22 + 0.18 * rough[i]
                if band:
                    rgb = [0.10 + 0.05 * coarse[i]] * 3
                elif haft:
                    rgb = [wood * 0.55, wood * 0.36, wood * 0.22]
                    rgb = [c * (0.25 + light * 0.9) for c in rgb]
                if kind == 'kindle':
                    # Teardrop flame: a tall body, a hot base, flickering edges.
                    flick = 0.75 + 0.5 * wisp[i]
                    flame = gauss(dx, dy + 34, 22, 52) * flick * 1.4
                    hot = gauss(dx, dy + 4, 12, 16) * 1.6
                    add = (flame * 1.0 + hot, flame * 0.55 + hot * 0.9, flame * 0.12 + hot * 0.6)
                else:
                    # A dying ember at the head and a thin smoke trail curling up.
                    ember = gauss(dx, dy - 4, 9, 6) * 0.9
                    curl = dx - 26 * math.sin(dy / 55.0) * min(1.0, -dy / 60.0) if dy < 0 else dx
                    smoke = gauss(curl, 0, 8 + 0.12 * max(-dy, 0), 1) * (0.25 + 0.75 * wisp[i]) * (math.exp(dy / 220.0) if dy < 0 else 0.0) * 0.55
                    add = (ember + smoke * 0.55, ember * 0.25 + smoke * 0.6, ember * 0.08 + smoke * 0.72)
            rgb = [c + a for c, a in zip(rgb, add)]
            rgb = shade_hand(rgb, i, x, y, lx, ly, tint, strength, coverage, soft, rough)
            if motes and r < 260:
                spark = 0.0
                for mx, my, s, b in motes:
                    d2 = (x - mx) ** 2 + (y - my) ** 2
                    if d2 < 36 * s * s:
                        spark += b * math.exp(-d2 / (2 * s * s))
                rgb = [c + spark * k for c, k in zip(rgb, (1.4, 1.26 if kind == 'orb' else 0.9, 0.98 if kind == 'orb' else 0.35))]
            # Tone map, then the black disc frame of the game's icons with a soft edge and vignette.
            edge = math.hypot(x - half, y - half)
            frame = max(0.0, min(1.0, (CELL * 0.485 - edge) / 10.0))
            frame *= 1 - 0.55 * max(0.0, min(1.0, (edge - CELL * 0.25) / (CELL * 0.25))) ** 2
            pixels.append(tuple(int(255 * max(0.0, min(1.0, (1 - math.exp(-c * 1.25)) * frame)) ** (1 / 1.1)) for c in rgb))
    image = Image.new('RGB', (CELL, CELL))
    image.putdata(pixels)
    return sepia(image).filter(ImageFilter.GaussianBlur(0.6))


# The game's power pages show dark, warm sepia scenes in which only the power itself keeps its colour.
SEPIA_DARK, SEPIA_LIGHT = (0, 0, 0), (236, 214, 176)   # black stays black: the disc frame
SEPIA_AMOUNT = 0.7


def sepia(image: Image.Image) -> Image.Image:
    """Tone the scene toward sepia, keeping more of the original colour in the brightest parts."""
    from PIL import ImageOps
    gray = ImageOps.grayscale(image)
    toned = ImageOps.colorize(gray, SEPIA_DARK, SEPIA_LIGHT)
    keep_original = gray.point(lambda v: int(255 * (1 - SEPIA_AMOUNT * (1 - (v / 255) ** 3))))
    return Image.composite(image, toned, keep_original)


KINDS = ('orb', 'kindle', 'snuff', 'flare', 'sanctuary', 'beacon', 'rally', 'glare', 'hallowed')   # power numbers 1..9
COLUMNS = 4                                                  # a 2048 sheet, like the Force school's


def draw() -> Image.Image:
    """The whole sheet: cells in power-number order, unused cells black."""
    rng = random.Random(SEED)
    sheet = Image.new('RGB', (CELL * COLUMNS, CELL * COLUMNS))
    for index, kind in enumerate(KINDS):
        sheet.paste(cell(kind, rng), ((index % COLUMNS) * CELL, (index // COLUMNS) * CELL))
    return sheet


if __name__ == '__main__':
    draw().save(sys.argv[1])
