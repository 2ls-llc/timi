# Timi — Implementation Plan

> **Rename & rescope (post-M7):** the product is **Timi** — the cat, who is also the
> app. The app was built under the working title "Pixel Pal" with a second character
> ("Pip", a mint blob); per the owner's direction both were removed: the app, bundle
> (com.twols.timi), cask (`timi`), modules (Timi/TimiKit) and the cat herself are
> all named Timi, and Pip's character code, sounds, prototype file, and the character-
> switching UI are gone. Timi's own behavior is unchanged — the refactor was gated on
> her golden snapshots matching byte-for-byte. Sections below describe the original
> two-character build process and remain as history; read "Mochi" as Timi's working
> name.

A native macOS desktop app: a tiny pixel cat that lives above your windows and is a
focus timer. Ported **exactly** from the web prototype (`Prototype/mochi-timer.jsx`),
then exceeded in native polish.

Source of truth: the prototype file. Where the mission document and the file disagree,
the file wins. Where the mission document deliberately *adapts* for native (no CRT
stage, hover-revealed controls, hearts persist per day), the mission document wins —
those deltas are listed in §5 below.

---

## 1. Targets & layout

SwiftPM package, two products:

- **`PixelPalKit`** (library) — everything deterministic and AppKit-free: `TimerCore`,
  `Physics`, `PalEngine` (the prototype's frame-loop state machine `S`), `PixelCanvas`,
  `Font3x5`, `Palette`, `Sprites`, character data + renderers, `SoundEvent` descriptions,
  persistence models. Unit-testable without a GUI session.
- **`PixelPal`** (executable) — AppKit shell: `AppDelegate`, `PalPanel`, `RenderLoop`
  (CADisplayLink), `ClickThroughController`, `ControlsStrip`, `StatusBarController`,
  `SettingsView` (SwiftUI), `ChipSynth` (AVAudioEngine), `HotkeyManager`
  (KeyboardShortcuts), persistence stores, notifications.

Directory layout (maps to the mission's target layout; SwiftPM sources live under
`Sources/`, tests under `Tests/`):

```
Package.swift
Sources/PixelPalKit/
  Engine/      TimerCore.swift, Physics.swift, PalEngine.swift, EngineTypes.swift
  Render/      PixelCanvas.swift, Font3x5.swift, Sprites.swift, Palette.swift
  Characters/  Character.swift, Pip.swift, Mochi.swift
  Audio/       SoundBank.swift        (pure recipe descriptions; synth lives in the app)
  Persistence/ SettingsModel.swift, SessionRecord.swift
Sources/PixelPal/
  App/         main.swift, AppDelegate.swift, StatusBarController.swift,
               SettingsView.swift, HotkeyManager.swift, Notifier.swift
  Window/      PalPanel.swift, PalPanelController.swift, ClickThroughController.swift,
               ControlsStrip.swift, GlowLayer.swift, CabinetLayer.swift
  Engine/      RenderLoop.swift       (display-link cadence policy)
  Audio/       ChipSynth.swift, CatVoice: part of ChipSynth voice types
  Persistence/ SettingsStore.swift, SessionStore.swift
Tests/PixelPalKitTests/
  TimerCoreTests.swift, PhysicsTests.swift, RenderSnapshotTests.swift
Tests/snapshots/           committed PNG evidence
Packaging/   build.sh, notarize.sh, release.sh, homebrew/Casks/pixel-pal.rb,
             Info.plist, PixelPal.entitlements, project.yml (xcodegen), release.yml → .github/workflows
Prototype/   pip-timer-v4-3.jsx, mochi-timer.jsx (source of truth, checked in)
PLAN.md  CHECKLIST.md  README.md
```

Toolchain: Swift 6.2 compiler, `swiftLanguageMode(.v5)` on targets to keep AppKit
main-thread code pragmatic. `platforms: [.macOS(.v14)]`. Dependency: `KeyboardShortcuts`
only (network confirmed available). Universal binary built by `Packaging/build.sh` with
`swift build -c release --arch arm64 --arch x86_64`.

---

## 2. Coordinate spaces (the one real porting decision)

Three spaces:

1. **Canvas space** — 56×48 logical pixels, origin top-left, y down. Identical to the
   prototype's `<canvas>`. All sprite/face/particle math is byte-for-byte the prototype's.
2. **Physics space** — **global AppKit screen coordinates** (y up, origin bottom-left of the
   arrangement). `S.pos`/`S.vel`/`S.home` live here. The prototype's container rect
   `(0,0,w,h)` becomes the **`visibleFrame` of the screen currently containing the pal**.
   Every formula in the prototype's motion section is symmetric in y except two, which are
   flipped for y-up:
   - finish glide: prototype `home.y = h/2 − 20` (20 px *above* center, y-down) → native
     `home.y = visibleFrame.midY + 20`.
   - hop/lift/gravity are **canvas-space** quantities (px), unchanged.
   Cursor input (`NSEvent.mouseLocation`) is already in this space — no conversion at all.
3. **Panel space** — the NSPanel is 340×300 pt; the creature's center sits at (170, 170)
   from the panel's bottom-left. Each frame `setFrameOrigin(pos.x − 170, pos.y − 170)`.
   Canvas layer: 168×144 pt (3 pt per logical px; 6 device px per cell at 2×), centered on
   the creature center. Glow layer: 260×230 pt, same center. Controls strip: 84 pt below
   the creature center (the prototype's `top: 84`), i.e. strip's top edge at center-y − 84
   in panel coords.

Squash/stretch and the scale spring are applied as `CATransform3D` scale on the canvas
layer (anchor at center), never to the bitmap — pixels stay integer-scaled at rest.

## 3. Prototype → Swift mapping

| Prototype | Swift | Notes |
|---|---|---|
| `S` (big mutable ref) | `PalEngine` class fields | one struct-of-state; update(dt, now) mirrors the RAF loop line-for-line |
| `loop(t)` RAF | `PalEngine.step(input:)` driven by `RenderLoop` (CADisplayLink) | `t` = `CACurrentMediaTime()` ms — monotonic, pauses in system sleep, like `performance.now()` |
| `Date.now()` / `endAt` | `Date` wall clock in `TimerCore` | survives sleep; recomputed on wake |
| tick-on-second (`sec !== lastSec` in RAF) | `DispatchSourceTimer` aligned to the second boundary in `TimerCore` | spec §5 refines prototype; audible result identical |
| milestone checks each frame | exact scheduled fire dates in `TimerCore` + engine-side visual reaction | half/quarter/minute have known absolute times once running; fired flags survive pause/resume |
| `finish()` via frame check | `TimerCore` fires at `endAt` | ±50 ms accuracy requirement |
| `makeAudio()` closures | `ChipSynth` voices on `AVAudioSourceNode` | polyBLEP square, triangle, noise; per-voice freq ramp/vibrato/HPF; master gain 0.5 → LPF 7.5 kHz |
| CSS transforms on wrapper/canvas | `setFrameOrigin` + CALayer transform | `translate3d` → panel origin; `scale(sxc·S, syc·S)` → canvas layer transform |
| glow div opacity | `GlowLayer.opacity` (implicit animations disabled) | 0.35–0.65 breathing, ×0.45 asleep |
| canvas 2d `fillRect` | `PixelCanvas` RGBA8 buffer → `CGImage` → layer contents, `.nearest` | 56×48×4 B/frame |
| pointer events / capture | `NSView.mouseDown/Dragged/Up` on the pal view + `NSEvent.mouseLocation` polling each frame | AppKit tracks drags outside the window natively |
| `wheel` handler | `scrollWheel(with:)` over the pal, idle only | notch detection via `scrollingDeltaY` accumulation |
| container `ResizeObserver` | `didChangeScreenParametersNotification` | clamp `home` on-screen; per-screen last position remembered |
| buttons row | `ControlsStrip` NSView with chip-style buttons | fade 300 ms, hover-revealed (native adaptation) |
| keyboard space/R/M | global hotkey (⌃⌥Space) + menu key equivalents | app is LSUIElement; no window focus, so web keys become hotkey + menu |

## 4. Engine architecture

`PalEngine` owns every field of the prototype's `S` plus per-character sub-state. Per frame,
`RenderLoop` gathers an `EngineInput` (now-mono ms, cursor position, hovered flag, reduce-
motion, screen visibleFrame) and calls `engine.step(input)`; the engine returns an
`EngineOutput` (panel position, canvas transform sxc/syc/scale, glow opacity, canvas
opacity, sound events fired this frame, cadence hints). Then the character renderer draws
into `PixelCanvas` from the engine's state. Sounds are collected as `SoundEvent` values and
handed to `ChipSynth` — the Kit stays audio-framework-free and the whole frame is
deterministic given (input, RNG). RNG: seeded `SplitMix64` injected — tests use fixed seeds.

`Character` protocol =
- `palette` (all named colors), `glowTint`, popped-segment color, banner text ("YAY"/"NYA!"),
  finish timings (flyHeart delay 900/1100 ms, happy 9/10 s, auto-reset 6.0/6.4 s),
- sound hooks: start / half / quarter / minute / pause / resume / sleep / wake / abandon /
  pat / finish-extra (Mochi's +700 ms mew) / hard-wall (Mochi hiss),
- `updateCharacter(engine:...)` — per-frame bespoke behavior (Pip: ahoge spring, panic
  shake+sweat, celebrate hop loop; Mochi: tail chain, purr scheduling, stretch, zoomies
  home drive, pounce impulse at finish, wiggle offset),
- `drawCreature(canvas:engine:)` — the full creature paint (body variant, ears/tail/
  whiskers, feet, face priority chain) copied from its file.

Shared draw code (hearts row, flying heart, mini hearts, clock text, done banner, progress
bar + segment pop, ground shadow, Zs, confetti, milestone flash) lives in `SharedRenderer`
since both files are identical there (modulo palette + pop color + flash alpha 0.16/0.15).

## 5. Resolved ambiguities & native deltas (documented decisions)

1. **Native adaptations from the mission doc (override prototype):** no CRT stage/scanlines/
   vignette by default (optional "Cabinet" setting draws a small CRT frame); controls strip
   is hover-revealed when idle/running and pinned while paused (prototype showed it always
   when idle); hearts row = *today's completed sessions* persisted (prototype: in-memory
   count); scroll clamp 1–90 min (same as prototype); keyboard = global hotkey instead of
   Space/R/M on a focused web page.
2. **Blink in panic:** Pip *schedules* blinks during panic (file has no `!panic` guard) and
   its face chain tests `blinking` before `panic`, so a blink flickers closed-eyes even
   mid-panic; Mochi does not schedule new blinks during panic. Reproduced per character.
3. **Celebrate hop loop is Pip-only.** Mochi's file has no `lastAutoHop`; its finish is
   pounce → zoomies (0.9–3.2 s) → loaf. Mission §5 lists the hop loop generically; files win.
4. **Milestone "minute"** sets the 90 ms flash too (all three set `flashT`); only half/
   quarter hop. Buzz for minute in both characters.
5. **`wakeUntil` on start** = now + 3000 ms (files), 2600 ms after milestones.
6. **Mochi flash alpha** is 0.15 (Pip 0.16) — file constants kept.
7. **Pip Z-glyphs drift** sideways (`x += sin(t/400)·1.5·dt`); Mochi's rise straight. Kept.
8. **Shadow width:** Pip excludes squash from the height term (`squashing ? 0 : max(0,−bounce)`);
   Mochi doesn't have the exclusion. Kept per file.
9. **`lastInteract`** updates on: cursor movement within 300 pt of the pal (native
   tightening of "any pointermove in container" — mission §5 explicitly says ≤300 pt),
   pointer down/drag on the pal, scroll over the pal, hotkey/menu actions, wall impacts
   (file behavior). 
10. **Timer accuracy:** ticks and finish come from `DispatchSourceTimer` (wall-clock
    aligned), not the frame loop; on `NSWorkspace.didWakeNotification` remaining is
    recomputed from `endAt`; if it elapsed during sleep → quiet finish (fanfare at 50%
    volume, no confetti hop suppression otherwise).
11. **Multi-display:** physics bounds are the `visibleFrame` of the screen containing
    `S.pos` (re-evaluated when not in flight); flight bounces keep the pal on its current
    screen; dragging can cross screens; on screen-parameter changes `home`/`pos` are
    clamped back into the nearest screen; last position per screen stored by
    `NSScreen` display UUID.
12. **Hover** = cursor inside the creature's 168×144 pt canvas rect or the visible controls
    strip (the prototype's wrapper hover = canvas + buttons; glow was `pointerEvents:none`).
13. **Click-through:** panel default `ignoresMouseEvents = true`; the frame loop polls
    `NSEvent.mouseLocation` (~display-link cadence, ≥12 Hz, ≤60 Hz — satisfies the ~30 Hz
    intent without a global monitor) and flips interactivity when the cursor is over the
    creature rect / visible strip. Modes: hover (default) / hold-⌥ / always-interactive.
14. **Notifications/SMAppService** are guarded behind `Bundle.main.bundleIdentifier` — a
    bare `swift run` binary skips them gracefully; the bundled .app gets them.
15. **Pat sound:** Pip plays `pat` on release; Mochi's file plays no release sound — its
    purr loop starts via `purring` (patT) and repeats every 1450 ms while purring ≤1500 ms.
    Reproduced exactly (one purr per pat, effectively).
16. **Mochi kneading** requires `happy && !walking && mode == idle` — happens in the ~3.6 s
    idle window after auto-reset (happyUntil outlives done). Kept.
17. **RNG:** all `Math.random()` sites use an injected seeded generator; the app seeds from
    entropy, tests fix the seed.
18. **`fmt`** = `ceil(ms/1000)` → `m:ss`, identical.
19. **Hearts flight target slot** = `min(hearts, 7)`; on landing `hearts += 1` + blip. With
    persisted hearts ≥ 8 the row stays at 8 (`min(hearts,8)`), like the prototype.
20. **Menu-bar icon**: 1-bit mini portrait of the active character; `isTemplate` when idle,
    colored when running; optional `12:34` text next to it (setting).

## 6. Frame cadence & energy

`RenderLoop` uses `NSView.displayLink(target:selector:)` → CADisplayLink with
`preferredFrameRateRange` switched by policy: 60 (dragging, flight, hop airborne, done-
celebration, panic, particles alive, <1.5 s since state change, cursor within 300 pt),
30 (running/idle at rest), 12 (sleeping/bored-loaf settled). Paused when panel hidden,
screen locked, display asleep, terminating. The engine's `step` is cheap (µs); the canvas
redraw is 10 KB; `setFrameOrigin` is skipped when movement < 0.05 pt. The timer never
depends on cadence.

## 7. Testing

- `TimerCoreTests`: tick volume curve at 10.5/60/20/45 s boundaries; milestones fire
  exactly once incl. across pause/resume; settle target timing (10 s / 75 s / wakeUntil
  rules); abandon >15 s rule; wall-clock jump (simulated sleep) finishes with ±50 ms.
- `PhysicsTests`: spring convergence/damping, throw threshold 650 & cap 2600, restitution
  0.72 bounce, flight exit <140 → home clamp 90, hop impulse/land timing, squash mapping.
- `RenderSnapshotTests`: drive `PalEngine` + renderers with a fixed seed into every state
  listed in the mission (§12) and write `Tests/snapshots/*.png` (56×48 and ×3 nearest
  upscale); assert stability against committed goldens.

## 8. Milestones

M1 panel+canvas+Pip idle → M2 physics+controls → M3 timer+audio → M4 personality+menubar+
persistence → M5 Mochi → M6 energy/a11y/snapshots → M7 packaging. Commit + build + test +
screenshot evidence after each. After each milestone, an adversarial spec-compliance review
(agents diffing code against the prototype files section by section) gates the commit.
