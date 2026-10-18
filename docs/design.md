# Timi design notes

These notes explain how Timi works and why. To install or use Timi, read the
[README](../README.md). For each behavior and its constants, read the
[behavior reference](behavior.md).

## Source of truth

The web prototype `Prototype/mochi-timer.jsx` defines the behavior of Timi.
("Mochi" was her working name.) The app ports the prototype exactly.

An original product specification, which is not in this repository, also
shaped the app. Some of its changes to the prototype are on purpose, for
macOS. In those cases, the specification wins. Where the two disagree by
accident, the prototype wins. The [Decisions](#decisions) section lists each
case.

## Package layout

The Swift package has these targets:

- `TimiKit` is a library with all of the deterministic logic. It does not import
  AppKit, so tests can run it without a GUI session.
- `Timi` is the executable. It is the AppKit shell: the panel, the
  `CADisplayLink`, input, audio output, the menu bar item, Settings, and
  storage.
- `TimiKitTests` and `TimiTests` test the two targets.

```
Package.swift
Sources/TimiKit/
  Engine/        TimerCore, PalEngine, Physics, EngineTypes, DurationFormat
  Render/        PixelCanvas, Renderer, Sprites, Font3x5, Palette
  Audio/         SynthDSP
  Characters/    Timi (CharacterConfig and the sound names)
  Persistence/   SettingsModel, SessionRecord
Sources/Timi/
  App/           main, AppDelegate, PalController, StatusBarController,
                 SettingsView, HotkeyManager, Notifier, LoginItem,
                 DebugHarness, Acknowledgements
  Window/        PalPanel, ControlsStrip, GlowLayer, CabinetLayer, HintLabel
  Audio/         ChipSynth
  Persistence/   SettingsStore, SessionStore
Tests/
  TimiKitTests/  engine, timer, physics, rendering, DSP, and format tests
  TimiTests/     persistence tests
  snapshots/     golden images, and images of the panel from live runs
Packaging/       build.sh, notarize.sh, release.sh, Info.plist,
                 Timi.entitlements, AppIcon.icns, make-icon.swift,
                 project.yml, homebrew/Casks/timi.rb
Prototype/       mochi-timer.jsx
.github/         workflows/ci.yml, workflows/release.yml
```

The package uses Swift tools version 5.10, so the targets compile in the
Swift 5 language mode. In this mode, the compiler does not apply the strict
concurrency checks to the AppKit code, which runs on the main thread. The
minimum system is macOS 14. The only third-party dependency is
[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts).
`Packaging/build.sh` builds a universal binary with
`swift build -c release --arch arm64 --arch x86_64`.

## Coordinate spaces

Timi uses three coordinate spaces.

1. **Canvas space** has 56×48 logical pixels. The origin is at the top left,
   and y increases downward. This space is the same as the `<canvas>` of the
   prototype. The sprite, face, and particle math is the prototype's math, with
   no changes.
2. **Physics space** is the global AppKit screen space. The origin is at the
   bottom left of the screen arrangement, and y increases upward. `pos`, `vel`,
   and `home` are in this space. `home` is the point where Timi rests.
   - The container rectangle of the prototype, `(0, 0, w, h)`, becomes the
     `visibleFrame` of the screen that contains Timi.
   - Three formulas change because y increases upward. The first is the start
     position: the prototype puts `home` at `h·0.45` from the top, and the app
     uses `minY + h·0.55`.
   - The second is the finish glide. The prototype sets `home.y = h/2 − 20`,
     and the app sets `home.y = visibleFrame.midY + 20`. The third is the eye
     gaze, which flips the y offset of the pointer.
   - Hops, lift, and gravity are canvas-space values in pixels, so they do not
     change.
   - The pointer position (`NSEvent.mouseLocation`) is already in physics
     space, so it needs no conversion.
3. **Panel space** is the space of the `NSPanel`, which is 340×300 pt. The
   center of the cat is at (170, 170) from the bottom-left corner of the panel.
   Each frame, the app moves the panel with
   `setFrameOrigin(pos.x − 170, pos.y − 170)`.
   - The canvas layer is 168×144 pt, centered on the cat. Each canvas pixel is
     3 pt, which is 6 device pixels on a 2× screen.
   - The glow layer is 260×230 pt, with the same center.
   - The top edge of the controls strip is 84 pt below the center of the cat.
     This value is the `top: 84` of the prototype.

Squash, stretch, and the scale spring are a `CATransform3D` scale on the canvas
layer, with the anchor at the center. They never change the bitmap, so the
pixels stay at an integer scale when Timi is at rest.

## Prototype to Swift

| Prototype | Swift | Notes |
|---|---|---|
| `S`, the large mutable state object | The fields of the `PalEngine` class | `step(_:)` follows the animation loop of the prototype line by line. |
| `loop(t)` on `requestAnimationFrame` | `PalEngine.step(_:)`, called from a `CADisplayLink` in `PalController` | `t` is `CACurrentMediaTime()` in ms. Like `performance.now()`, it is monotonic and pauses during system sleep. |
| `Date.now()` and `endAt` | A wall-clock `Date` in `TimerCore` | The end time survives sleep. The app computes the remaining time again after a wake. |
| A tick on each new second (`sec !== lastSec`) | A `DispatchSourceTimer` in `PalController`, set to the next deadline from `TimerCore` | The deadlines are the second boundaries and the milestone times. The ticks sound the same as in the prototype. |
| Milestone checks in each frame | Fire times from `TimerCore`, and the visual reaction in the engine | When the timer runs, `TimerCore` knows the times of half, quarter, and minute. The fired flags survive pause and resume. |
| `finish()` from a frame check | `TimerCore` finishes at `endAt` | The finish is accurate to ±50 ms. |
| `makeAudio()` closures | `ChipSynth` voices on an `AVAudioSourceNode` | The voices are polyBLEP square, triangle, and noise. A voice can also have a frequency ramp, vibrato, or a high-pass filter. The master gain is 0.5, followed by a 7.5 kHz low-pass filter. |
| CSS transforms on the wrapper and the canvas | `setFrameOrigin` and a `CALayer` transform | `translate3d` becomes the panel origin. `scale(sxc·S, syc·S)` becomes the transform of the canvas layer. |
| Opacity of the glow `div` | `palView.glowLayer.opacity`, a `CALayer` with implicit animations off | The glow breathes between 0.35 and 0.65. While Timi sleeps, the app multiplies it by 0.45. |
| Canvas 2D `fillRect` | A `PixelCanvas` RGBA8 buffer, converted to a `CGImage` for the layer contents, with the `.nearest` filter | One frame is 56×48×4 bytes. |
| Pointer events and pointer capture | `mouseDown`, `mouseDragged`, and `mouseUp` on the view of the cat, and `NSEvent.mouseLocation` in each frame | AppKit tracks a drag outside the window with no extra code. |
| The `wheel` handler | `scrollWheel(with:)` over Timi, only while idle | The app sums `scrollingDeltaY` to find each step. It ignores momentum scroll events. |
| `ResizeObserver` on the container | `didChangeScreenParametersNotification` | The app returns `home` to a screen. It remembers the last position on each screen. |
| The row of buttons | `ControlsStrip`, an `NSView` with chip buttons | The fade takes 300 ms. The strip shows on hover, which is a change for macOS. |
| The Space, R, and M keys | The global hotkey ⌃⌥T and the menu items | Timi is an `LSUIElement` app with no focused window, so the web keys became a hotkey and menu items. |

## Engine

Each frame, `PalController` makes an `EngineInput` and calls `engine.step(_:)`.
The input has these values:

- The monotonic time and the frame duration
- The timer mode, the session length, and the remaining time
- The pointer position, and whether the pointer moved
- The hover state, and the Reduce Motion setting
- The `visibleFrame` of the screen

`PalEngine` holds every field of the state object `S` of the prototype. `step`
advances this state by one frame. The pointer and timer hooks, for example
`pointerDown` and `onFinish`, also change it. `step` returns a `StepResult`
with the sounds and the events of the frame. It also computes `FrameFlags`, the
values of the frame that the renderer reads.

After the step, `PalController` reads the engine state to move the panel. It
also sets the canvas transform, the glow opacity, and the canvas opacity.
`Renderer.draw` paints the canvas from the engine state.

`TimiKit` names each sound as a `PalSound` value, and `ChipSynth` in the app
plays it. So `TimiKit` has no audio framework, and each frame is deterministic
for a given input and RNG state. The RNG is a seeded `SplitMix64`. The app
seeds it from system entropy, and the tests use fixed seeds.

`CharacterConfig.timi` holds the constants of Timi. These are the palette, the
glow tint, the banner text `NYA!`, the finish timings, and the sound for each
timer moment. The `CharacterID` enum has one case, `timi`. Session records
store this ID, so a later version can add a character without a data migration.

## Decisions

### Changes for macOS

1. The app has no CRT stage by default. The prototype drew a CRT stage with
   scanlines and a vignette. The optional **Cabinet Frame** setting draws a
   small CRT frame.
2. The controls strip shows on hover. The prototype always showed its buttons
   while idle. The app shows the strip on hover while the timer is idle or
   running. During a pause, the strip stays visible.
3. Hearts persist for each day. The prototype counted hearts in memory, so each
   page load reset them. The app stores each session and counts the completed
   sessions of the current day. A session counts for the day that it finished.
4. A global hotkey replaces the web keys. The prototype used Space, R, and M on
   a focused page. The default hotkey is ⌃⌥T. The specification asked for
   ⌃⌥Space, but macOS uses that key combination to select the next input
   source.
5. Reduce Motion is a native addition, because the prototype has no motion
   setting. Sound does not change. With Reduce Motion on:
   - Timi does not hop, pounce, wiggle, fidget, or blink, and she has no
     zoomies.
   - The canvas shows no confetti, no sleep Zs, no landing dust, and no tail
     puff.
   - Squash shrinks to 0.3 of its size, and the breath bounce shrinks to 0.35
     of its size.
6. An outline improves contrast. Timi draws a dark 1 px outline around
   everything on the canvas, except the sleep Zs and the confetti. The outline
   is on by default, and Settings has a toggle for it. The system Increase
   Contrast setting forces the outline on.
7. Only pointer movement near Timi counts as interaction. The prototype counted
   any pointer movement in its container. The app counts movement within 300 pt
   of Timi, as the specification asks. These events also count:
   - A pointer down or a drag on Timi
   - Scrolling over Timi
   - The hotkey and the menu commands
   - Wall impacts
8. A system timer times the session, not the frame loop. A `DispatchSourceTimer`
   makes the ticks and the finish from the wall clock. On
   `NSWorkspace.didWakeNotification`, the app computes the remaining time again
   from `endAt`. If the deadline passed during sleep, the session finishes
   quietly: the fanfare plays at 50% volume. The rest of the finish does not
   change.
9. Physics uses the screen that contains Timi.
   - Each frame, the app finds the screen that contains `pos`. The bounds are
     the `visibleFrame` of that screen.
   - During a flight, the bounces keep Timi inside that screen. A drag can move
     her to another screen.
   - When the screen setup changes, the app clamps `home` and `pos` into the
     screen that contains Timi. If no screen contains her, it uses the screen
     of the panel, or else the main screen.
   - The app stores the last position on each screen, by the UUID of the
     screen.
10. The halo and the hit area are not the same size.
    - The halo is the 168×144 pt canvas rectangle, like the hover area of the
      prototype. While the controls strip shows, the chip row and the gap above
      it also count as the halo.
    - The halo controls the hover scale, the ear perk, the clock visibility,
      the strip reveal, and the frame rate. While the pointer is over the halo,
      Timi does not settle.
    - The eyes do not use the halo. They follow the pointer whenever it is
      within 300 pt of Timi.
    - The hit area is smaller: 88×84 pt around the drawn cat. Only the hit area
      and the visible strip accept clicks in the default mouse mode.
11. By default, the panel ignores clicks, so each click goes to the window
    below. The panel starts with `ignoresMouseEvents = true`. Each frame, the
    app reads `NSEvent.mouseLocation` at the frame rate, from 12 Hz to 60 Hz.
    This rate meets the target of about 30 Hz in the specification, without a
    global event monitor. Then the app sets the input state from the mouse
    mode:
    - Hover (the default): input is on while the pointer is over the hit area
      or the visible strip.
    - Hold ⌥: the whole panel accepts input while you hold ⌥.
    - Always: the whole panel always accepts input.
    - During a drag, the panel accepts input in each mode.
12. Notifications and the login item need an app bundle. The code checks
    `Bundle.main.bundleIdentifier` first. A bare `swift run` binary skips both
    features, and the bundled app has both.
13. The resting spot stays clear of the Dock.
    - The prototype keeps `home` 90 pt inside its container on each side.
    - In the app, the controls strip reaches 110 pt below the center of the
      cat, and its chip row is about 235 pt wide.
    - So the bottom inset is 120 pt and the side insets are 125 pt. The top
      inset stays at 90 pt.
    - A cat in a bottom corner keeps her presets in front of the Dock.
    - The flight bounds (`bounceHalfSize`, 78 pt) do not change.
14. Hearts show as a ♥×n tally on the same line as the clock.
    - The prototype drew one heart sprite for each completed session, in a row.
      It centered the clock on the same line, at y=2.
    - In the app, hearts persist for each day. So at 4 hearts, the row
      overlapped the digits. At 8 hearts, the row stopped growing and gave no
      sign.
    - The app draws a tally at the top left instead. The tally is a 5×5 heart,
      a 3×3 multiplication sign on the middle row, and the count, up to 99.
      All three are pink.
    - The heart has 5 rows so that it fills the same rows as the digits. The
      4-row heart of the prototype sat 1 px too low.
    - The clock is right-aligned and ends at x=53, which gives margins of 2 px
      on both sides. In the worst case, `♥×99` and `90:00`, 18 px separate the
      tally and the clock. The centered done banner clears both.
    - A count suits hearts better than a row, because hearts have no maximum.
15. The flying heart lands on the tally. The prototype aimed the heart at the
    next free slot in its row. The app aims it at the tally heart, at (4, 4).
    When the heart lands, the count increases by one, a blip plays, and the
    tally heart flashes for 130 ms.
16. The menu bar icon is a 1-bit portrait of Timi. When the timer is idle or
    done, the icon is a template image, so macOS draws it in the color of the
    menu bar. While a session runs and during a pause, the icon is in color. A
    setting shows the remaining time, for example `12:34`, next to the icon.
17. The app adds custom session lengths. The `…` chip and the **Custom…** menu
    item accept a length from 0.5 to 90 minutes.
18. When you open Timi, she shows a hint until your first interaction. The
    hint lists the gestures: TAP TO START, HOLD TO PAT, DRAG OR FLING, HOVER
    FOR PRESETS, and SCROLL SETS MINUTES. If nobody interacts, the hint closes
    after 15 s and shows again the next time Timi opens. **Show Tips** in the
    menu shows it at any time.

### Specification and prototype

These items settle places where the specification and the prototype disagree,
or where the prototype is not clear.

1. The finish has no hop loop. The specification lists a repeating celebration
   hop, but the cat prototype has none. She pounces, has the zoomies from 0.9 s
   to 3.2 s after the finish, and then loafs. The app follows the prototype.
2. All three milestones flash. Half, quarter, and minute each set the flash of
   90 ms. Only half and quarter make Timi hop. The minute milestone plays a
   buzz.
3. Timi stays awake after a start and after a milestone. A start sets
   `wakeUntil` to now + 3000 ms. A milestone sets it to now + 2600 ms.
4. A pat has no release sound. The cat prototype plays no sound when a pat ends.
   The purr loop starts from `patT` and repeats every 1450 ms while `purring` is
   true, which is for 1500 ms after the pat. So a pat gives about one purr. At
   60 fps, a second purr can start about 1.45 s after the pat.
5. Kneading needs `happy && !walking && mode == idle`. This condition occurs in
   the idle time of about 3.6 s after the auto-reset, because `happyUntil` lasts
   longer than the done state.
6. The clock format is `ceil(ms/1000)` as `m:ss`. This format is the same as
   `fmt` in the prototype.
7. Each `Math.random()` call of the prototype uses the injected seeded RNG.

## Frame rate and energy

`PalController` gets a `CADisplayLink` from
`NSView.displayLink(target:selector:)`. It sets `preferredFrameRateRange` from
this policy:

- **60 fps** when the engine asks for it. The engine asks during a drag, a
  flight, a hop, the finish, and the hunt. It also asks while confetti, a pat
  heart, or the flying heart is on the canvas.
- **60 fps** also while the pointer is over the halo or within 300 pt, and for
  1.5 s after a change of mode.
- **12 fps** while Timi sleeps or loafs, and in the bored state.
- **30 fps** at all other times.

Sleep Zs do not ask for 60 fps, because the sleep rate wins.

The `CADisplayLink` stops when the panel is hidden, when the screen locks, when
the screens sleep, and when the app quits.

The work for each frame is small. One engine step takes microseconds, and one
canvas redraw writes about 10 KB. The app skips `setFrameOrigin` when the
movement is less than 0.05 pt.

The timer never depends on the frame rate.

## Tests

`swift test` runs 116 tests in nine suites.

| Suite | Tests | Coverage |
|---|---|---|
| `TimerCoreTests` | 21 | The tick volume curve and the pitch ramp of the hunt. One tick per second, with no burst of ticks after a gap. Milestones fire once, also across pause and resume, with their gates. The abandon rule. A clock jump during sleep gives a quiet finish on wake. |
| `PhysicsTests` | 23 | The home and drag springs, flight drag, bounces, impacts, and corner hits. Hops and quiet landings at 60 fps. Squash. Home margins. Tap, pat, and fling detection, and the throw-speed cap. A tap during a hop. The flight exit, the wall boing, and the hiss. |
| `EngineTests` | 17 | Settling into a nap, and no settling in the last 75 s. Waking on hover. Sleep Zs every 1.7 s. The hunt and the wiggle, with no blinks. The finish: confetti, the flying heart, the pounce, the zoomies, the loaf, and the mew. Reduce Motion, boredom, fidgets, the sad window, happiness, purring, and the gaze. |
| `RenderSnapshotTests` | 13 | Golden images of 13 states. The [behavior reference](behavior.md#quality) lists them. |
| `SynthDSPTests` | 12 | Ticks and blips, the frequency, the envelope, the fanfare and its quiet form, the purr, the hiss, mute, delayed notes, and voice expiry. |
| `PixelCanvasTests` | 7 | Clipping at each edge, sprites and lean, font width and the colon blink, the flash overlay, the outline, and clear. |
| `SessionStatsTests` | 9 | Hearts today, the all-time total, and the streak rules. These include gaps, an empty day, incomplete sessions, and a session that crosses midnight. |
| `DurationFormatTests` | 5 | Compact and long forms of a length, the presets, and the clock rounding. |
| `PersistenceTests` | 9 | The session ledger on disk, abandoned and stale sessions, and a reset. A missing or corrupt ledger. Settings with missing keys, unknown values, or corrupt data. |

A snapshot test compares the canvas with `Tests/snapshots/golden-*.png`, byte
for byte. If a golden file does not exist, the test records it and fails.
Examine the new image. Then run the test again.

## History

Timi began as "Pixel Pal", an app with two characters: Pip, a mint-colored blob,
and Mochi, this cat. The project removed Pip and the prototype of Pip. Mochi
became Timi, and the app took her name. The removal did not change her
behavior: her golden snapshots stayed identical, byte for byte.
