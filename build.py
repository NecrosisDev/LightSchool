"""Build the Light School addon folder: its scripts plus the two spell-book files the game looks for.

    python -X utf8 -B mods/light-orb/build.py --game "D:/.../Exanima" --out <new folder>

The game's spell book has a Light page that loads Resource.rpk:pwr_light.pwr and the icon sheet
thmlgtico1.rfi; neither ships. This writes:
- pwr_light.pwr: the Light page (POWERS below), with the ExaniMate power-tree writer;
- thmlgtico1.rfi: the original icon sheet painted by icon.py (one 512 px cell per power), encoded in
  the same texture format as the install's Energy sheet (thmnrgico1.rfi: RGB with mipmaps). Only that
  sheet's format is used, never its pixels.
The install is only read. Output goes to a new folder only.
"""
import argparse
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, __import__('os').environ.get('EXANIMATE_SERVICE', ''))  # the ExaniMate service folder
from exanimate import pwr, rfi, rpk  # noqa: E402
from PIL import Image  # noqa: E402

import icon  # noqa: E402

ID = 'com.necrosis.light-orb'
# (power id, name, description, x, y, parent node 1-based or 0, Insight technique needed or None).
# Ids must match scripts/config.lua. Bits 16-17 give the mode (Flare is immediate, the rest continuous);
# the low byte is the icon cell (number - 1) in thmlgtico1. The technique goes into bits 28-31, as in the
# shipped trees; the game masks it off when it matches a cast.
POWERS = [
    (0x20501, 'Light Orb',
     'Summon a small orb of light that floats beside you, lighting further than a torch while both '
     'hands stay free. Cast again to dismiss it. Needs a free Continuity binding; holds back some '
     'focus while lit.', 0.0, 0.0, 0, None),
    (0x20502, 'Kindle',
     'While held, wall torches you pass within arm\'s reach catch light on their own. Cast again to '
     'release it. Needs a free Continuity binding; holds back some focus.', 40.0, -38.0, 1, None),
    (0x20503, 'Snuff',
     'While held, lit wall torches and fires you pass within arm\'s reach go out, to pass unseen. '
     'Cast again to release it. Needs a free Continuity binding; holds back some focus.', -40.0, -38.0, 1, 'Inversion'),
    (0x00504, 'Flare',
     'Throw out a brief, blinding burst of light that lights the whole room and fades within moments. '
     'Its focus returns shortly after; Iteration halves the cost of casting it again.', 0.0, -62.0, 1, 'Expansion'),
    (0x20505, 'Sanctuary',
     'While held, a calm light gathers around you and those nearby slowly lose their hostility and '
     'concern toward you. It soothes; it does not command. Needs a free Continuity binding; holds back '
     'more focus than the others.', 0.0, -100.0, 4, 'Coherence'),
    (0x20506, 'Beacon',
     'Leave a steady light hanging where you stand, to mark a path or hold back the dark behind you. '
     'Cast again to let it go out. Needs a free Continuity binding; holds back some focus.', 40.0, -100.0, 2, 'Convergence'),
]
MODES = {0: 'immediate', 1: 'sustained', 2: 'continuous'}
TECHNIQUES = {name: number for number, name in pwr.INSIGHT.items()}
# Shipped links carry two small control floats before the parent; these are in the shipped range.
LINK = (-0.14, 0.26)


def light_tree(template: bytes) -> bytes:
    """The Light page. Header, language tag and string-table head come from a shipped tree (every
    shipped tree names thmmndico1 there; the game picks the icon sheet by school instead); the nodes
    and every string are new, so no game text is carried over. Like the shipped tables, the blob
    starts with an empty string that the last offset points at."""
    shipped = pwr.parse(template)
    tree = pwr.Tree(shipped.head, [], shipped.language, shipped.string_head, [0], b'\0\0\0\0')
    for power, name, description, x, y, parent, needs in POWERS:
        links = [(LINK[0], LINK[1], parent, 0)] if parent else []
        stored = power | (TECHNIQUES[needs] << 28 if needs else 0)
        tree.nodes.append(pwr.Node(stored, tree.set_text(None, name), tree.set_text(None, description), x, y, links))
    data = pwr.pack(tree)
    nodes = pwr.view(data)['nodes']
    for node, (power, name, _description, _x, _y, parent, needs) in zip(nodes, POWERS):
        if (int(node['id'], 16) & 0x3FFFF != power or node['name'] != name or node['mode'] != MODES[(power >> 16) & 3]
                or node['requires'] != ([needs] if needs else []) or node['parents'] != ([parent] if parent else [])):
            raise SystemExit(f'pwr_light.pwr did not read back as written: {node}')
    return data


def light_icons(like: bytes) -> bytes:
    """The painted sheet as an .rfi in the Energy sheet's format. .rfi rows are stored bottom row first
    (the exporter flips them back), so the image is flipped before encoding."""
    image = icon.draw().convert('RGBA').transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    return rfi.encode(image.tobytes(), image.width, image.height, like)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    if out.exists():
        parser.error('use a new output folder')
    resource = args.game / 'Resource.rpk'
    tree = light_tree(rpk.read(resource, 'pwr_energy.pwr'))
    icons = light_icons(rpk.read(resource, 'thmnrgico1.rfi'))
    mod = out / 'mods' / ID
    packages = mod / 'assets/packages/Resource'
    packages.mkdir(parents=True)
    (packages / 'pwr_light.pwr').write_bytes(tree)
    (packages / 'thmlgtico1.rfi').write_bytes(icons)
    shutil.copyfile(HERE / 'manifest.toml', mod / 'manifest.toml')
    shutil.copytree(HERE / 'scripts', mod / 'scripts')
    print(f'LIGHT_ORB_BUILT={mod} pwr_light.pwr={len(tree)} bytes thmlgtico1.rfi={len(icons)} bytes')
    return 0


if __name__ == '__main__':
    sys.exit(main())
