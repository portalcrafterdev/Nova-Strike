# Nova Strike

A 2D top-down space shooter for Android and iOS, built with Flutter and Flame.

Portrait only, offline only, no accounts and no servers. Drag a finger anywhere on
screen to fly, the ship fires on its own, and 1500 levels are generated from the
level number rather than authored by hand.

The lane runs up the screen. Enemies enter from the far end and come down it,
and the whole thing is drawn by a small renderer of its own rather than by
sprites.

## Running it

```
flutter pub get
flutter run
```

Tests:

```
flutter test
flutter analyze
```

## How it fits together

| Folder | What lives there |
| --- | --- |
| `lib/game/` | Everything inside the Flame game: components, systems, effects |
| `lib/game/render3d/` | The camera, the models and the renderer that draws them |
| `lib/levels/` | Pure data and pure functions: the level generator, the difficulty curve, the catalogs |
| `lib/audio/` | The audio controller, the volume settings, the sound list |
| `lib/state/` | Save data and player progress |
| `lib/ui/` | Every screen, sheet, overlay and widget, all Flutter |
| `lib/theme/` | Colours, layout constants and text styles |
| `tool/` | The placeholder audio generator |

Two rules hold the shape of the codebase together:

- Gameplay lives inside Flame. Every menu, sheet and the heads up display are
  Flutter widgets driven by notifiers on the game.
- `lib/levels/` and `lib/game/systems/bullet_patterns.dart` and
  `movement_patterns.dart` never import Flame components, so the level maths and
  the attack patterns can be unit tested without a game loop.

Every tuning number lives in `lib/levels/difficulty_curve.dart`, and every colour
and drawn size lives in `lib/theme/palette.dart`.

## The renderer

There is no rendering package and there are no image assets. `lib/game/render3d/`
is a few hundred lines that do the whole job:

- `camera3d.dart` is an orthographic lens looking straight down at the play
  plane. The world is right handed: x runs across the screen, z runs up the lane
  away from the player, and y is only there to give a model thickness and to
  decide which face draws on top. Nothing is smaller for being further away. It
  also casts a touch back onto the plane, which is what turns a finger into a
  place to fly to.
- `mesh.dart` builds low poly models from numbers. No model files, no textures.
  Every hull, rock, gem and boss in the game comes out of this one file.
- `mesh_renderer.dart` draws a model with flat shading from one key light, culls
  the faces pointing away from the lens, and sorts the rest so the highest parts
  of a hull paint last.
- `scene3d.dart` collects everything that draws and paints it in one sorted
  pass, so a ship covers the star field rather than the other way around.

Collision is spheres, in `systems/collision_rules.dart`. Bullets are tested along
the line they travelled during the frame rather than where they ended up, because
a bullet covers more ground in one frame than a small enemy is wide and would
otherwise fly straight through it.

## The 1500 levels

Levels are generated, not stored. `Random(levelNumber * 7919 + 104729)` seeds the
generator, so the same level number produces the same level for every player on
every device and nothing about a level is written to disk.

- 100 chapters of 15 levels. Levels 1 to 13 are normal, 14 is an elite swarm and
  15 is a boss.
- 10 boss archetypes, one per chapter position, gaining hit points and one extra
  attack pattern every time the archetype comes back around.
- Enemies, formations and bullet patterns unlock by chapter so early levels stay
  readable.
- Some ordinary levels become an objective instead: hold out on a survival level,
  keep a freighter alive on an escort, fly through the gate at the end of a gate
  level.
- A level may carry one twist, which changes how it plays without changing what
  is in it. Boss and objective levels never carry one, because they already
  change the rules.
- Every fifth level steps the multipliers back, so a long session has somewhere
  to breathe. Boss levels are never relief levels.
- `lib/levels/handcrafted.dart` overrides the generator for the tutorial levels 1
  to 8 and for a set piece on every hundredth level.

Difficulty climbs through hit points, rate of fire, enemy count and the families
that unlock later. It never climbs through speed: the pace at level 1500 is the
pace at level 1, so late levels ask for play rather than for reactions.

## Audio

`AudioController` is the only thing in the codebase that talks to the audio
plugins. It owns three volume channels, master, music and effects, plus a mute
flag that does not overwrite the slider values. Changes apply live, music volume
is set on the running player rather than restarting the track, and writes are
debounced by 300ms so dragging a slider does not write on every frame.

### Placeholder audio

`assets/audio/` currently holds synthesised placeholders so the audio system can
be built and tested end to end. They are generated by:

```
dart run tool/gen_audio.dart
```

Replace the files with real sound design when it lands. Keep the file names, they
are derived from the `Sfx` enum. Real music should be `.ogg`, which means
updating `MusicTracks.path` in `lib/audio/sfx.dart`.

## Art and branding

Ships, bullets, gems, rocks and the star field are all drawn from the meshes and
the palette, with cached `Paint` objects. Texture memory is zero and everything
scales to any screen.

The launcher icon, the launch window and the mark on the menu are the player's
own hull, rendered by the game's own renderer through the same code path the game
uses. They are regenerated by a gated test, so a change to the hull or the
palette never leaves the branding behind:

```
BRANDING=1 flutter test test/branding_test.dart
```

Two more gated tests draw the art rather than assert on it. `MODEL_SHEET=x
flutter test test/model_sheet_test.dart` writes a contact sheet of every model in
the game, which is the fastest way to see what a mesh change did.

## Verified

- `flutter analyze` is clean and `flutter test` passes 161 tests.
- All 1500 levels generate, each with at least one wave and non-zero enemy hit
  points, and every level only uses content unlocked by its chapter.
- No level number between 1 and 1500 makes anything move faster than level 1.
- The game loop is exercised headlessly: waves spawn, the ship auto fires,
  enemies take damage and die, lives run out, the bullet cap holds, bosses arrive
  and protect their core, gems apply and expire, and levels complete and unlock.
- The star field is asserted to draw stars and never lines, by handing the
  component a canvas that counts what it was asked to paint.
- Volume settings and progress survive a restart.
- A debug APK builds and installs.

## Measured on a device

Frame timing was sampled on a real phone with
`dumpsys SurfaceFlinger --timestats` during play: every frame presented on the
16.6ms cadence with no janky frames, in a debug build. A release build has more
headroom again.
