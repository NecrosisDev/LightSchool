# Light School 0.9.2 — Lua addon candidate (mod id com.necrosis.light-orb)

The first power in the spell book's Light school. Cast it from the power wheel
to summon a small cool-white light that floats behind and beside your head and
reaches further than a torch (range 2000; a torch is about 1500). Cast it again
to dismiss it. Both hands stay free. It follows the game's rules for
continuous powers, like the Force ones: you need a free Continuity binding and
at least its cost in focus, and while it is lit it holds back 0.15 of your
focus ceiling (0.1125 with Abstraction). Clarity's faster recovery applies too.

**Also on the Light page:** **Kindle** (while held, wall torches you pass within about 2 m catch light) and **Snuff** (while held, lit wall torches and fires you pass go out). Each is a held power with the same Continuity and focus rules (0.10 each); starting one releases the other. Kindle and Snuff need the runtime's `world.read` and `world.devices`; without them only the orb works. Only static wall torches count, not carried torches or story lamps.

**Flare** is an instant cast: a blinding burst of light (range 4000) that fades over about two seconds. Its 0.12 focus cost is held back for 8 seconds, then returned; Iteration halves it when Flare was also your last cast.

**Sanctuary** is a held power in the Light school (the only school a mod can add casts to): while held, NPCs within 7 m who remember you lose 2 hostility and 1 concern per second, up to 8 at a time. The game's AI can raise them again; it soothes, it does not command. It holds 0.20 focus and needs a binding, plus the runtime's `characters.awareness` and `characters.attitude.write`.

**Beacon** (held) leaves a steady light where you cast it, for as long as it is held; it goes out when released or when you leave the level. It needs runtime 0.28.0's `lights.place` and a character snapshot (`characters.read` or `characters.awareness`) for your position; without them, casting Beacon only logs why.

**Learning:** Light Orb and Kindle are open from the start; Snuff needs Inversion, Flare Expansion, Beacon Convergence and Sanctuary Coherence, like the game's own trees. **Feedback:** with `ui.sound` the game's thaumaturgy sounds play on start, release, Flare and refusal. Cast gestures, the visible orb glow, Iteration across schools and counting against the game's bindings use runtime 0.28.0-r10 and switch off on older runtimes.

Code layout: `scripts/main.lua` (casting and focus), `scripts/rules.lua` (the game's cost rules), `scripts/effects.lua` (what each power does), `scripts/config.lua` (tuning).

**Status:** offline only. Nothing here has run in the game.

## What it needs

- The Exanima Lua Runtime 0.26.0 or later (`powers.cast`, `powers.focus`,
  `world.lights`, and new archive member names).
- The two spell book files the game looks for and doesn't ship:
  `Resource.rpk:pwr_light.pwr` (one node, power `0x20501`) and the icon sheet
  `thmlgtico1.rfi`. `build.py` writes both: the six-node tree with the
  ExaniMate writer, and a 2048x2048 sheet of six original icons painted by
  `icon.py` (orb, kindled torch, snuffed torch, flare, sanctuary, beacon), in the Energy sheet's format.

```bash
python -X utf8 -B mods/light-orb/build.py --game "D:/SteamLibrary/steamapps/common/Exanima" --out <new folder>
```

## Using it

Learn **Light Orb** on the Light page of the spell book, put it on the power
wheel, and cast it like any other power. Tune it in **Settings > Mod Settings > Light School** (runtime 0.27.0+): orb colour, range, brightness, position, drift and sway, every power's focus cost, Flare's brightness and return time, Sanctuary's reach, and whether held powers need a binding. `scripts/config.lua` holds the defaults.

## Still to check in the game

- whether the Light page lists and lets you learn the node
- the light's brightness and colour, and which side `right` puts it on
- level changes, death, save and reload (the light is never written into a save)
- whether NPCs react to it
