# Light School

Adds the Light page to Exanima's spell book: nine thaumaturgy powers that light
your way, blind your foes, guide your allies and burn the dead. You learn and
cast them like the game's own powers, from the spell book and the power wheel.

## Features

Held powers are cast once to start and again to release. Like the game's own
continuous powers, each needs a free Continuity binding and holds back part of
your focus ceiling while it lasts (less with Abstraction). Instant powers are
cast once; Iteration halves their cost when you cast the same one again.

| Power | Type | What it does |
|---|---|---|
| Flare | Instant | A brief, blinding burst of light that lights the whole room and fades within moments. Foes close by who are fighting you are dazzled and fight worse for a moment. |
| Light Orb | Held | A small orb of light floats beside you, reaching further than a torch while both hands stay free. |
| Kindle | Held | Wall torches you pass within arm's reach catch light on their own. |
| Snuff | Held | Lit wall torches and fires you pass within arm's reach go out, so you can pass unseen. Starting Kindle or Snuff releases the other. |
| Beacon | Held | Leaves a steady light hanging where you cast it. It goes out when you release it or leave the level. |
| Radiance | Held | You blaze with light. Foes who press close cannot look straight at you and fight half-blind while they stay. |
| Guiding Light | Held | Followers and friends near you fight sharper, and a small light hangs over the nearest. |
| Glare | Instant | A narrow, searing light into the eyes of the nearest foe winding up to strike: they lose balance (never enough to knock them down on its own) and fight blind for a few moments. |
| Searing Beacon | Held | Needs a standing Beacon. Foes fighting you who stand close to it are scorched each second, the undead twice as much. It goes out with the Beacon. |

Light works on the body and the eye, not the mind: it changes how well an NPC
fights for a moment, never how they feel about you, and NPCs get their own
values back when the effect ends.

**Learning.** Flare is the root of the page. Light Orb and Glare branch from
Flare; Kindle and Radiance from Light Orb; Snuff and Beacon from Kindle;
Guiding Light from Radiance; Searing Beacon from Beacon. As in the game's own
trees, some nodes also need an Insight technique: Snuff (Inversion), Beacon
(Convergence), Radiance (Coherence), Guiding Light (Expansion), Glare
(Convergence) and Searing Beacon (Union).

**Insight.** Each Insight technique you have makes Light effects 10% stronger,
up to 50% with all five: light range, reach, and how much they sharpen or blind
fighters.

**Feedback.** Casts play the game's own thaumaturgy sounds and cast motions.

The page's tree and its nine icons are new files made for this mod; no game
file is replaced.

## Requirements

- Exanima (Steam).
- EMTK with the script-runtime startup patch, shipped with the Exanima Lua
  Runtime release.
- Exanima Lua Runtime 0.28.0 or later.

## Install

1. Download `LightSchool-<version>.zip` from the Releases page.
2. Close Exanima.
3. Copy the `mods` folder from the ZIP into your Exanima game folder, so you end
   up with `Exanima\mods\com.necrosis.light-orb`.
4. Enable Light School in your EMTK profile.
5. Launch the game through EMTK.

## Using it

When you load a game, the mod teaches your character Flare, the root of the
Light page, so the page can be opened in the spell book. Learn further powers
there, put them on the power wheel and cast them like any other power.

## Settings

Open Settings > Mod Settings > Light School.

- **General:** Continuity, whether each held Light power uses a free Continuity
  binding.
- **Light Orb:** colour (cool white, warm white, pale blue, gold), focus,
  brightness, reach, height, how far ahead or to the side it floats, drift (how
  quickly it catches up as you move), bob and glow size.
- **Kindle, Snuff:** focus.
- **Flare:** focus, brightness, and refund (seconds before Flare's focus comes
  back when the runtime cannot spend focus directly).
- **Radiance:** focus and reach.
- **Beacon:** focus and reach of its light.
- **Guiding Light:** focus and reach.

The defaults, and the tuning for powers without settings rows, are in
`scripts/config.lua` inside the mod folder.

## Known limits

- Only wall torches and fires count for Kindle and Snuff, not carried torches.
- The runtime gives each mod a small number of lights. Radiance's glow and the
  short light that marks who a power touched show only when one is free.

## Saves and uninstalling

- The lights are never written into a save. A Beacon goes out when you leave
  its level.
- Powers your character learns on the Light page are kept by the game with the
  character. Back up your saves before removing the mod.
- To uninstall, disable Light School in your EMTK profile, or delete
  `Exanima\mods\com.necrosis.light-orb`.

## For other mods

Another mod can make an NPC cast Glare or Guiding Light:

- `addons.send("com.necrosis.light-orb", "light.cast", {caster = <characters.read row or record id>, power = "glare" | "guide"})`
- or a game script line `LuaEvent(LightCastGlare, <caster record id>)` or
  `LuaEvent(LightCastGuiding, <caster record id>)`.

## Building from source

The build writes the Light page's power tree with the ExaniMate power-tree
writer and paints the icon sheet with `icon.py`. It reads one file from the
installed game, the Energy page's icon sheet, only to copy its texture format;
none of its pixels are used. You need Python 3 with Pillow, and the ExaniMate
service folder (which holds the `exanimate` format library).

```
python -X utf8 -B release.py --game <Exanima folder> --exanimate <ExaniMate service folder>
```

`--exanimate` can instead come from the `EXANIMATE_SERVICE` environment
variable.

This writes the mod folder to `dist/mods/com.necrosis.light-orb/` and the
release to `dist/LightSchool-<version>.zip`, with a `.sha256` file beside it. An
earlier build in `dist/mods/` is moved to `dist/previous/` first. Other options:

- `--zip-only` packages the mod folder already in `dist/` without rebuilding.
- `--tag v<version>` stops unless the tag matches the version in
  `manifest.toml`.

Author: NecrosisDev
