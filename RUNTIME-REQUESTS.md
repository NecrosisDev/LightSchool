# Runtime requests from Light School

Static reading of Exanima.exe 0.9.5.2g (Ghidra decompile; addresses are RVAs); not run in game.
Light School already calls each of these behind presence checks (`scripts/feedback.lua`,
`scripts/main.lua`), so each switches on when a runtime provides it. Earlier requests (last cast,
gesture, glow, bindings) shipped in 0.28.0.

## `powers.teach(power)` — most urgent: without it the Light page cannot be opened

- **Game:** the spell book's school wheel (`TDomainWheel`, VMT `0x32b440`) lets the player click a
  school only when its flag at wheel `+0x18b + school` is set (`0x1d5940`). `0x1dd440` sets those flags
  from the character's known powers: for each entry of stats (`+0x10a0`) `+0x188` count / `+0x190`
  array (16-byte entries `{u32 id, u32 state, 8 bytes}`) it sets the flag of `(id >> 8) & 0xff`. A new
  character gets only `0x101` (state `0x1000`) and `0x20101` (state `0x2800`) from the default list
  at `0x2e8730` (`0x1de590`). So the Light school stays greyed out until the character knows a Light
  power. The game adds known entries with `0x1d3950(stats, id, state)` (append or overwrite; grows the
  array with `0x10000ee10`). `0x1ddb40(stats, id)` is its full "learn" path (Raise Dead revelation),
  which checks requirements first.
- **Ask:** `powers.teach(power)`, needing `powers.cast`, from timer callbacks during a session. On the
  game thread, for the controlled character: if no known entry has `id & 0x3ffff == power`, append
  `{power, 0x1000, 0}` through `0x1d3950` (state `0x1000` is what the game seeds Sense Minds with). Never
  overwrite an existing entry, because that would reset learning progress. Light school ids only
  (`(power & 0xff00) == 0x500`). Returns true when it was added or already known. Entries are saved with
  the character (actor chunk `0xcdec01/02`), so this is a one-time grant per character.
- **Light School:** calls `powers.teach(0x504)` (Flare, the page's root) at each session start.

## `powers.spend_focus(amount)`

Drains `amount` (0..0.5) from the player's current focus the way the game's casts pay.

- **Game:** `0x17a620(char, cost)` adds `cost` to `+0xd80`; each tick `0x17a6b0` moves a ramping share
  of `+0xd80` out of current focus `+0xd74` (floored at 0) and pauses recovery while it runs. Instant
  powers call it with their cost (Mind: `0x1e4360` and the other use functions). Continuous powers
  call it through `0x17aad0`, which adds the same cost to the reserve `+0xd84` too, so starting one
  both drains current focus and lowers the ceiling.
- **Ask:** add `amount` to the controlled character's `+0xd80` on the game's work queue, like
  `powers.hold_focus`. Capability `powers.focus`. Returns true when staged; false outside a session.
  Refuse non-finite or out-of-range values with a Lua error. Nothing is given back: focus recovers by
  the game's own rule.
- **Light School:** a held power spends its cost once when it starts (and keeps holding it, as
  `0x17aad0` does); Flare spends its cost instead of the hold-and-return it uses today.

## `powers.wheel(power, outcome)`

The power wheel's own reaction to a Light cast, which the runtime's cast detour currently skips.

- **Game:** `0x1d8340(slot)` calls `0x13dcf0(1000)` before dispatching (the wheel stays shown for
  1000 ms: `[0x4f0710] = now + 1000`). After a successful dispatch, if `[0x56a570]` is set it calls
  `0x1d7df0(1)`, clears the flag, and updates the slot's flash row in the 20-byte table at
  `0x2e8668 + slot*20` (flags, start tick `0x2e866c`, length `0x2e8670`), choosing the branch by the
  row's flags exactly as the decompile shows. A failed dispatch plays `ThaumFail01`
  (`0x1000cd130(0x4eec90, sound, ...)`).
- **Ask:** `powers.wheel(power, "cast" | "fail")`, needing `powers.cast`. The runtime finds the
  prepared slot holding `power` (stats `+0x198`, masked `0x3ffff`), and on the game thread runs
  `0x13dcf0(1000)` and then, for `"cast"`, the same post-dispatch steps `0x1d8340` runs for a
  successful cast of that slot, or for `"fail"` its fail-sound call. If no slot holds the power, it
  returns false. Lua decides acceptance one pulse after the key press, so the flash comes a pulse late.
  That is acceptable; doing it in the detour would flash refused casts too.
- **Light School:** calls `"cast"` when a power starts or Flare fires, and `"fail"` on a refusal (its own
  fail sound is then skipped).

## `row:boost_ai`: let `attribute2` be omitted

Runtime 0.28.0's `row:boost_ai{skill, attribute2, attribute3, seconds}` takes absolute set_ai values.
Light School changes only an NPC's AI skill (Flare, Glare, Radiance lower it; Guiding Light raises it)
and must leave attribute 2 alone: it feeds courage, which is the Mind school's (Embolden, Fear), and it
cannot be read, so any value we pass overwrites the NPC's own.

- **Ask:** `attribute2` and `attribute3` optional in `boost_ai`; an omitted field keeps the NPC's
  current stored value (the runtime already saves all six fields on the first call, so it has them).
- **Light School:** calls `row:boost_ai{skill = awareness.skill * 100 ± change, seconds = s}` (the game
  stores set_ai's 0..100 times 0.01, `hotload.h` `AiFields`), behind `row.boost_ai` and
  `characters.ai.write` checks and a pcall. Until the ask lands, a runtime that requires attribute2
  refuses the call and these NPC effects do nothing.

## More lights per addon

API.md 0.28.0: 3 lights per addon, 6 in all. Light School can hold five at once: the orb, the
Flare/Glare burst, the Beacon, Radiance's glow around you, and the short "touch" light that marks who
a power just reached.

- **Ask:** 5 per addon (keeping 6, or raising it, in all).
- **Light School:** every extra light is placed behind a pcall, so with 3 the orb, burst and Beacon win
  and Radiance's glow and the touch cues show only when a slot is free.
