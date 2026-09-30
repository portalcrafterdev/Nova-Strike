# hand_tap.json

The tutorial hand. Supplied by the project owner, who reuses the same animation
across their games. Copied here from their blocktopus project, byte for byte.

- **Source:** https://lottiefiles.com/free-animation/hand-tap-5z6XERrjjo
- **Author:** not recorded on the copy supplied. **Fill this in from the
  LottieFiles page before release** - a credit line, if the licence asks for
  one, has to name somebody.
- **Licence:** not recorded on the copy supplied. **Confirm before release.**
  LottieFiles' free animations generally permit use *inside* a product but not
  redistribution of the animation on its own. This repository is pushed to
  GitHub, so the file sitting here is redistribution unless the licence allows
  it. Check, and record the answer here.

## Edits made to the file

**None.** It is byte for byte as supplied, and it needs none:

- It is *not* the hollow line-art problem. `Path 2` is a closed path with a
  real fill and `Path 1` is the open contour carrying the stroke, so there is
  no inner contour to delete and no fill rule to fight.
- `Group 2` (the stroke) is already listed before `Group 1` (the fill) in
  `shapes`, and earlier groups paint on top, so the outline is already in front
  where it belongs. A replacement listing them the other way round would have
  its outline covered by the fill.

Recolouring happens at runtime through `LottieDelegates` in
`lib/tutorial/hand_indicator.dart`, so the palette stays next to the rest of the
app's colours and a swapped file cannot quietly arrive in somebody else's
scheme.

The file ships **black fill on black outline**, which on this game's dark scrim
reads as a transparent hand with a black border. `HandArt.fill` paints it white
and `HandArt.line` keeps the border black.

## What a replacement has to match

Swap the file and nothing will throw. It will simply render in its own colours,
at its own speed, with the hand in the wrong place - so check all of this:

| | value | why it matters |
|---|---|---|
| canvas | 600 x 600 | the fingertip constant is in units of the box |
| frame rate | 25 fps | |
| frames | 41 (`ip` 0, `op` 41) | `HandArt.cycle` is 1640ms, which is 41/25 |
| resting frame | 0 | where `point` and `swipe` hold the playhead |

Layer, group and item names the delegates key on:

| what | path |
|---|---|
| hand fill | `hand_tap_01 Outlines` / `Group 1` / `Fill 1` |
| hand outline | `hand_tap_01 Outlines` / `Group 2` / `Stroke 1` |
| first ripple | `Shape Layer 3` / `Ellipse 1` / `Stroke 1` |
| second ripple | `Shape Layer 4` / `Ellipse 1` / `Stroke 1` |

## Notes on this particular file

- The ripples are masked by the hand shape through inverted alpha mattes
  (layers 3 and 5 are `td`, layers 4 and 6 are `tt: 2`), so they do not draw
  over the hand itself.
- The fingertip sits at **(0.402, 0.296)** of the box - nearly a third of the
  way down, because the 600x600 canvas carries a lot of air above the hand.
  `test/tutorial_test.dart` checks this against the file's own geometry and
  fails when it drifts. Do not derive it from the transform chain; it was
  measured off a render.
