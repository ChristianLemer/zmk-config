# zmk-config

_ZMK configuration for a **SplitKB Halcyon Ferris wireless** — nRF52840, e-paper on both
halves, driven through the USB-C dongle._

The layout is a port of the 34-key Vial layout kept in
[**orpheus**](https://github.com/ChristianLemer/orpheus), which holds the reasoning behind
it. This repo holds only what compiles into firmware.

## Getting firmware

Push, and GitHub Actions builds three `.uf2` files — download them from the run's
artifacts. Flashing: see
[orpheus](https://github.com/ChristianLemer/orpheus/tree/main/keyboards/splitkb/halcyon-ferris-wireless),
which documents the procedure and the two opposite things the reset button does.

| Artifact | Device | Role |
|---|---|---|
| `halcyon_ferris_dongle` | dongle | central, and the only one carrying the keymap |
| `halcyon_ferris_left_cc_epaper` | left half | peripheral |
| `halcyon_ferris_right_cc_epaper` | right half | peripheral |

**A keymap change needs only the dongle reflashed.** The halves know nothing about the
keymap — they report key positions and the central decides what they mean. The halves stay
closed.

## The layout

Five layers. Each of the four thumb keys opens one, and only one.

| Thumb | Held | Tapped |
|---|---|---|
| left outer | **Operators** — maths, rare punctuation, media, and the wireless keys | — |
| left inner | **Mouse** — cursor, clicks, wheel | Caps Lock |
| right inner | **Nav** — digits, arrows, editing, page movement | Space |
| right outer | **Symbols** — openers left, closers right | — |

Every home-row key is also a modifier: `A`/`S`/`D`/`F` = Shift/Ctrl/Alt/Gui, mirrored on
`;`/`L`/`K`/`J`. Same finger, same modifier, whichever hand is free.

## A faithful port, deliberately

Nothing was added, nothing moved. Where the Vial layout had an empty key, this one has an
empty key. The mod-tap is set to `tap-preferred` at 175 ms, which is how QMK's mod-tap
behaves by default and what the `.vil` had for `TAPPING_TERM` — so the feel should carry
over rather than being something new to learn.

ZMK can do better than this — `hold-trigger-key-positions` implements the opposite-hands
rule and would end the mod-tap ambiguity that killed the `F`+`D` combo under QMK. It is
deliberately **not** used here. Change one thing at a time: first confirm the layout you
know works on this board, then tune.

## Three keys this firmware does not have

A wireless board needs keys a wired one never did, and the faithful port has none of them.
Worth knowing before flashing:

| Missing | Consequence |
|---|---|
| `&studio_unlock` | **ZMK Studio can never unlock this firmware.** Editing means changing the keymap here and rebuilding. |
| `&bt BT_CLR`, `&bt BT_SEL n` | No way to switch or clear a Bluetooth profile. A pairing that goes bad needs a rebuild. |
| `&bootloader` | Reflashing means double-tapping the physical reset button on each device. |

The Operators layer's top row is empty and would hold all three without displacing
anything. That is a decision, not an oversight — say the word.

## Tuning

Everything below is one number, and no value is right for everyone — change one at a time
and type for a few days.

| Setting | Now | Raise it if | Lower it if |
|---|---|---|---|
| `tapping-term-ms` | 175 | modifiers fire when you meant letters | deliberate holds feel sluggish |

If stray modifiers survive a longer term, the next lever is `require-prior-idle-ms` — a key
pressed within N ms of the previous one is forced to a tap, so fast typing cannot throw
modifiers at all. After that, `hold-trigger-key-positions`: the opposite-hands rule, which
settles a mod-tap as a tap whenever the next key is on the same hand. Neither is set today.

## Building locally

Pushing and waiting four minutes is fine for a rare change; it is not fine for tuning a
tapping term by feel. Local builds turn that loop into seconds.

```nushell
omarchy pkg add cmake gperf dtc ccache   # once, needs sudo

use local
local                    # what this module does
local setup              # once, ~1.5 GB and a few minutes
local build              # every time after that
local build dongle       # just the dongle — enough for a keymap change
local build --propre     # start over
```

Everything lands in this repo and your home directory: a `.venv` for `west`, the Zephyr
workspace beside it, the ARM toolchain under your own SDK path. All of it is in
`.gitignore`.

**No Docker.** The container route would mean enabling the daemon and joining the `docker`
group, which is root-equivalent on this machine — too much to grant in order to compile a
keyboard. The four packages above are ordinary Arch repo packages and the rest needs no
privileges at all.

`local build` reads its targets from `build.yaml`, the same file GitHub Actions uses.
There is one list of build targets, not two.

## Layout source

Board definitions and the ZMK fork come from splitkb, pulled by `config/west.yml`:
[`zmk-halcyon-module`](https://github.com/splitkb/zmk-halcyon-module) ·
[`zmk-halcyon-config`](https://github.com/splitkb/zmk-halcyon-config)

Changing a module — a different display, a trackpad, no battery — means editing the
`shield:` line in `build.yaml`. The firmware must match the hardware; it is not a
preference.
