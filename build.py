"""Build the Light School addon folder: its scripts plus the two spell-book files the game looks for.

    python -X utf8 -B build.py --game "D:/.../Exanima" --out <new folder> [--exanimate <ExaniMate service folder>]

The game's spell book has a Light page that loads Resource.rpk:pwr_light.pwr and the icon sheet
thmlgtico1.rfi; neither ships, so neither replaces a game file. This writes:
- pwr_light.pwr: the Light page (POWERS below), authored here with the ExaniMate power-tree writer.
  Only the file format's fixed header fields are constants below; every node and string is new.
- thmlgtico1.rfi: the original icon sheet painted by icon.py (one 512 px cell per power), encoded in
  the texture format of the install's Energy sheet (thmnrgico1.rfi: RGB with mipmaps). Only that
  sheet's header is read for its format, never its pixels.
The install is only read. Output goes to a new folder only. The package carries no game data.
"""
import argparse
import os
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

ID = 'com.necrosis.light-orb'
# (power id, name, description, x, y, parent node 1-based or 0, Insight technique needed or None).
# Ids must match scripts/config.lua. Bits 16-17 give the mode (Flare is immediate, the rest continuous);
# the low byte is the icon cell (number - 1) in thmlgtico1. The technique goes into bits 28-31, as in the
# shipped trees; the game masks it off when it matches a cast. The first node is the page's root.
# The root is instant: the spell book only lets a continuous power be studied with Continuity I
# (0x1dc2b0), so a new character could not otherwise start the Light page. Coordinates use the shipped
# trees' range (root at 0, 0; branches upward, negative y).
POWERS = [
    (0x00504, 'Flare',
     'Throw out a brief, blinding burst of light that lights the whole room and fades within moments. '
     'Foes close by are dazzled and fight worse for a moment. Iteration halves the cost of casting it '
     'again.', 0.0, 0.0, 0, None),
    (0x20501, 'Light Orb',
     'Summon a small orb of light that floats beside you, lighting further than a torch while both '
     'hands stay free. Cast again to dismiss it. Needs a free Continuity binding; holds back some '
     'focus while lit.', -8.0, -46.0, 1, None),
    (0x20502, 'Kindle',
     'While held, wall torches you pass within arm\'s reach catch light on their own. Cast again to '
     'release it. Needs a free Continuity binding; holds back some focus.', 40.0, -72.0, 2, None),
    (0x20503, 'Snuff',
     'While held, lit wall torches and fires you pass within arm\'s reach go out, to pass unseen. '
     'Cast again to release it. Needs a free Continuity binding; holds back some focus.', 92.0, -100.0, 3, 'Inversion'),
    (0x20506, 'Beacon',
     'Leave a steady light hanging where you stand, to mark a path or hold back the dark behind you. '
     'Cast again to let it go out. Needs a free Continuity binding; holds back some focus.', 46.0, -116.0, 3, 'Convergence'),
    (0x20505, 'Radiance',
     'While held, you blaze with light. Foes who press close cannot look straight at you and fight '
     'half-blind for as long as they stay. Needs a free Continuity binding; holds back more focus than '
     'the others.', -18.0, -122.0, 2, 'Coherence'),
    (0x20507, 'Guiding Light',
     'While held, your light shows those who fight beside you the openings: followers and friends nearby '
     'strike sharper, and lose the edge moments after you let go. Needs a free Continuity binding; holds '
     'back as much focus as Radiance.', -52.0, -164.0, 6, 'Expansion'),
    (0x00508, 'Glare',
     'Flash a narrow, searing light into the eyes of the nearest foe winding up to strike. Caught '
     'mid-swing, they reel off balance and fight blind for a few moments. Iteration halves the cost of '
     'casting it again.', -62.0, -40.0, 1, 'Convergence'),
    (0x20509, 'Searing Beacon',
     'While held, your Beacon burns as well as shines: foes who stand close to it are scorched, the dead '
     'worst of all. Needs a standing Beacon and a free Continuity binding; holds back some focus.',
     60.0, -164.0, 5, 'Union'),
]
MODES = {0: 'immediate', 1: 'sustained', 2: 'continuous'}
# A link's two floats are where its line meets each ring, as angles in turns: first at the node that owns
# the link, then at its parent. The game measures them from +y, signed by x (0x1db920 / 0x1db9e0).
LINK_CURVE = 0.03   # the shipped links bend slightly; this keeps ours from looking ruled


def ring_angle(dx: float, dy: float) -> float:
    import math
    length = math.hypot(dx, dy)
    angle = math.acos(max(-1.0, min(1.0, dy / length))) / (2 * math.pi)
    return -angle if dx < 0 else angle


def link(child, parent_node, parent_index):
    _, _, _, cx, cy, *_ = child
    _, _, _, px, py, *_ = parent_node
    def wrap(turns):
        return (turns + 0.5) % 1.0 - 0.5
    return (wrap(ring_angle(px - cx, py - cy) + LINK_CURVE), wrap(ring_angle(cx - px, cy - py) - LINK_CURVE), parent_index, 0)
# The tree file's fixed fields, as every shipped tree has them (0x1de110 skips the header; the game
# picks the icon sheet by school, not by the name in it): 8 zero bytes, a 16-byte icon sheet name,
# zero padding; the 'en' language tag; the string table head (its count is rewritten on pack).
TREE_HEAD = bytes(8) + b'thmmndico1'.ljust(16, b'\0') + bytes(16)
TREE_LANGUAGE = b'en\0\0'
TREE_STRING_HEAD = bytes.fromhex('656e0000e4040100000000002e000000')


def exanimate_library(folder: Path):
    """The ExaniMate service package (power-tree writer, archive and texture codecs)."""
    sys.path.insert(0, str(folder))
    from exanimate import pwr, rfi, rpk
    return pwr, rfi, rpk


def light_tree(pwr) -> bytes:
    """The Light page. Like the shipped tables, the string blob starts with an empty string that the
    last offset points at."""
    techniques = {name: number for number, name in pwr.INSIGHT.items()}
    tree = pwr.Tree(TREE_HEAD, [], TREE_LANGUAGE, TREE_STRING_HEAD, [0], b'\0\0\0\0')
    for power, name, description, x, y, parent, needs in POWERS:
        links = [link((power, name, description, x, y), POWERS[parent - 1], parent)] if parent else []
        stored = power | (techniques[needs] << 28 if needs else 0)
        tree.nodes.append(pwr.Node(stored, tree.set_text(None, name), tree.set_text(None, description), x, y, links))
    data = pwr.pack(tree)
    nodes = pwr.view(data)['nodes']
    for node, (power, name, _description, _x, _y, parent, needs) in zip(nodes, POWERS):
        if (int(node['id'], 16) & 0x3FFFF != power or node['name'] != name or node['mode'] != MODES[(power >> 16) & 3]
                or node['requires'] != ([needs] if needs else []) or node['parents'] != ([parent] if parent else [])):
            raise SystemExit(f'pwr_light.pwr did not read back as written: {node}')
    return data


def light_icons(rfi, like: bytes) -> bytes:
    """The painted sheet as an .rfi in the Energy sheet's format. .rfi rows are stored bottom row first
    (the exporter flips them back), so the image is flipped before encoding."""
    import icon
    from PIL import Image
    image = icon.draw().convert('RGBA').transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    return rfi.encode(image.tobytes(), image.width, image.height, like)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--exanimate', type=Path, default=Path(os.environ['EXANIMATE_SERVICE']) if os.environ.get('EXANIMATE_SERVICE') else None,
                        required=not os.environ.get('EXANIMATE_SERVICE'))
    args = parser.parse_args()
    out = args.out.resolve()
    if out.exists():
        parser.error('use a new output folder')
    pwr, rfi, rpk = exanimate_library(args.exanimate)
    tree = light_tree(pwr)
    icons = light_icons(rfi, rpk.read(args.game / 'Resource.rpk', 'thmnrgico1.rfi'))
    mod = out / 'mods' / ID
    packages = mod / 'assets/packages/Resource'
    packages.mkdir(parents=True)
    (packages / 'pwr_light.pwr').write_bytes(tree)
    (packages / 'thmlgtico1.rfi').write_bytes(icons)
    shutil.copyfile(HERE / 'manifest.toml', mod / 'manifest.toml')
    shutil.copytree(HERE / 'scripts', mod / 'scripts')
    print(f'LIGHT_SCHOOL_BUILT={mod} pwr_light.pwr={len(tree)} bytes thmlgtico1.rfi={len(icons)} bytes')
    return 0


if __name__ == '__main__':
    sys.exit(main())
