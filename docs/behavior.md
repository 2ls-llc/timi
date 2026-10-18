# Timi behavior reference

This document lists the behaviors of Timi and the constants that control them.
Most values come from the prototype, `Prototype/mochi-timer.jsx`. The
[design notes](design.md) explain each change from the prototype.

Most items name the checks that cover them:

- **unit**: a unit test in `Tests/`
- **snapshot**: a golden image test, against `Tests/snapshots/golden-*.png`
- **live**: a check in the running app, with the debug console and with the
  images of the panel that it saved in `Tests/snapshots/`
- **dump**: an ASCII dump of the canvas from the debug console
- **review**: a section-by-section review against the prototype
- **measured**: a measurement on a release build

## Principles

- Timi shows each timer state with her body and her voice. She hides the clock
  most of the time. Checked by: live, snapshot.
- She settles and sleeps while you work. She wakes for milestones and for the
  last minute. She never demands attention. Checked by: unit, live.
- Between sessions, she is a toy. You can drag her, fling her, and pat her, and
  she bounces off the screen edges. Checked by: unit, live.
- On a release build on Apple silicon, Timi uses this much CPU. Checked by:
  measured.
  - Idle: 1.4–2.2%, with an average under 2%
  - Napping: 0.9–1.5%
  - Running: about 3%
  - Finish: 9.3% at most
- The pixels stay crisp at an integer scale. Timi does not lower the volume of
  other audio. She has no Dock icon and makes no network connections.
- Sprites never rotate, and squash is only along the axes. Scaling is
  nearest-neighbor. All drawing happens inside the 56×48 canvas. Checked by:
  snapshot.

## Platform

- The package uses Swift tools version 5.10. AppKit makes the shell, and
  SwiftUI makes only the Settings window.
- Timi needs macOS 14 or later. `Packaging/build.sh` makes a universal build.
- `swift build` works. `Packaging/project.yml` can make an Xcode project with
  XcodeGen.
- The only third-party dependency is KeyboardShortcuts.
- Timi is an `LSUIElement` app. The bundled build uses the App Sandbox and the
  Hardened Runtime.

## Panel

- The panel is a borderless, non-activating `NSPanel` at the `.floating` level.
  It is clear and has no shadow. It stays visible when the app is not active
  (`hidesOnDeactivate = false`).
- The panel shows on all Spaces and over full-screen apps, and it is not in the
  window cycle. The flags are `canJoinAllSpaces`, `fullScreenAuxiliary`, and
  `ignoresCycle`.
- The panel is 340×300 pt. It holds the cat, the transparent margins, and space
  for the controls strip. The margins are 86 pt at each side, 98 pt at the
  bottom, and 58 pt at the top.
- By default, the panel ignores clicks, so each click goes to the window below.
  The app reads the pointer at the frame rate: at least 12 Hz, and 60 Hz when
  the pointer is near.
  - In hover mode, the panel accepts clicks while the pointer is over the hit
    area or the visible strip. The hit area is 88×84 pt around the drawn cat.
  - In ⌥ mode, the panel accepts clicks while you hold ⌥.
  - In always mode, the panel always accepts clicks.
- Physics sets the position through `setFrameOrigin`. A drag pulls Timi toward
  the pointer with a spring (stiffness 380, damping 26). Checked by: unit, live.
- The walls are the `visibleFrame` of the current screen. When the screen setup
  changes, the app returns `home` (the point where Timi rests) to a screen.
  Checked by: live.
- Timi has no frame around her. A glow breathes behind her, with an opacity from
  0.35 to 0.65. While she sleeps, the glow is at 0.45 of that value. By default
  there is no CRT stage. The optional Cabinet Frame adds one. Checked by: live
  (`cabinet-on.png`).
- The controls strip shows on hover. The fade takes 300 ms. Checked by: live
  (`hero-hover.png`, `strip-paused.png`).
  - While the timer is idle, the strip has the presets, the custom chip, and
    mute.
  - While the timer runs, it has pause, mute, and reset.
  - During a pause, it stays visible.
  - The selected chip has a solid fill.
  - The chips use the typography of the prototype: 11 pt monospace, in
    uppercase.
- A scroll over Timi while the timer is idle changes the length by 1 minute per
  step. The range is 1–90 minutes, and each step plays a blip. Checked by: unit,
  live.

## Rendering

- The canvas is 56×48 RGBA8. It becomes a `CGImage` on a `CALayer`, with the
  `.nearest` filter, at 168×144 pt (3 pt per pixel). At rest the scale is an
  integer. Checked by: snapshot.
- Squash, stretch, and scale use only `CATransform3D`. Checked by: live.
- The frame rate is 60, 30, or 12 fps, by the policy in the
  [design notes](design.md#frame-rate-and-energy). Sleep Zs do not cause
  60 fps. The `CADisplayLink` stops when the panel is hidden, when the screen
  locks, when the screens sleep, and when the app quits. Checked by: measured.
- The timer does not depend on the frame rate. It uses the wall clock and a
  `DispatchSourceTimer`. Checked by: unit.
- The `♥×n` tally is at the top left, and the clock is right-aligned on the same
  line, at y=2. The tally counts to 99. The tally heart flashes for 130 ms when
  a heart lands. Checked by: snapshot, live (`tally-idle.png`,
  `tally-flight.png`, `tally-landed.png`).
- The clock uses the 3×5 font. Checked by: snapshot, live.
  - The clock shows while the timer is idle or paused, and while the pointer
    is over the halo. It also shows in the last 61 s of a run. It never shows
    in the done state.
  - While the timer runs, the colon shows for 500 ms and then hides for 500 ms.
  - During the hunt, the clock alternates between red and the text color every
    250 ms.
- The progress bar has 20 segments of 1×3 px at (8 + i·2, 41). Checked by:
  snapshot, live.
  - The number of filled segments is ceil(remaining fraction × 20).
  - The bar is amber when 60 s or less remain. During the hunt, it alternates
    colors.
  - A segment that empties shows the pop color (`segPop` in the palette) for
    130 ms.
- The renderer draws the cat with its left edge at x = 21, plus the wiggle
  offset. Its top row depends on the body variant. Checked by: snapshot, dump.
- The ground shadow is on row y=31. Checked by: snapshot, dump.
  - Its width is 9 − h px, where h = min(4, |lift| + max(0, −bounce)).
  - The shadow is not visible while you hold Timi, or while she flies after a
    fling. During a hop, the shadow is narrower.
- The milestone flash lasts 90 ms, with an alpha of 0.15. Checked by: review.
- The font glyphs, and the advance width (glyph width + 1), match the
  prototype. Checked by: snapshot, dump.
- The sprites match the prototype exactly. Checked by: snapshot, dump.

## Timer

- The modes are idle, running, paused, and done. `endAt` is a wall-clock time.
  The remaining time is `endAt − now`. Checked by: unit.
- The presets are 30 s, 5 min, 15 min, and 25 min. The default is 25 min. A
  custom length can be from 0.5 to 90 min. Checked by: unit.
- A tap is a press with less than 6 px of movement and less than 450 ms of
  time. Checked by: unit.
  - In the idle state, a tap starts the timer. While the timer runs, a tap
    pauses it. During a pause, a tap resumes it.
  - In the done state, a tap resets the timer.
- A hold of 450 ms or more is a pat. A pat never changes the timer. Checked by:
  unit.
- A `DispatchSourceTimer` makes one tick at each second boundary. Checked by:
  unit, review.
  - The ticks are loud for the first 20 seconds.
  - They fade between 20 and 45 seconds, and they are silent after that.
  - In the last minute, they return gradually over the first 5 seconds.
  - During the hunt, their pitch rises.
- The milestones are half, quarter, and minute. Each one fires once. Checked by:
  unit, review.
  - Half needs a session of 30 s or more. Quarter needs 4 min or more. Minute
    needs more than 150 s.
  - Each milestone plays a sound and shows the flash. Half and quarter also make
    Timi hop.
  - Each milestone keeps Timi awake for 2.6 s.
- The hunt is the last 10 s. The wiggle is the last 3.5 s. Checked by: unit,
  snapshot.
- Timi settles only when all of these conditions are true. Checked by: unit,
  live.
  - The timer runs.
  - The pointer is not over the halo.
  - You do not hold or fling her.
  - The time is later than `wakeUntil`.
  - The last interaction was more than 10 s ago.
  - More than 75 s remain.
- The settle value (0 to 1) eases toward its target. It rises at a rate of
  0.35 per second and falls at a rate of 2.8 per second. From 0, it reaches 0.6
  after about 2.6 s. Checked by: unit.
  - Timi sleeps when the value is more than 0.6. Sleepy and wake sounds play.
  - When she wakes, an exclamation mark shows for 450 ms.
- These events update the interaction time (`lastInteract`). Checked by: unit.
  - Pointer movement within 300 pt
  - A pointer down, or a drag
  - The hotkey, or a menu command
  - A scroll
  - A wall impact
- After 30 s of idle time with no interaction, Timi becomes bored. She loafs,
  and her fidgets stop. Checked by: unit, snapshot.
- The finish has these parts. Checked by: unit, live.
  - The fanfare plays. 28 pieces of confetti appear, and 16 more appear at
    600 ms.
  - Timi pounces with a hop impulse of −50 and a sideways speed of 260 pt/s,
    toward the center of the screen.
  - She mews 700 ms after the finish. The flying heart starts at +1100 ms.
  - She is happy for 10 s. The banner `NYA!` shows for 2.2 s and alternates its
    color every 180 ms.
  - `home` moves to 20 pt above the center of the screen.
  - The timer resets by itself after 6.4 s.
- If the notification setting is on and Timi is out of sight, a notification
  shows when the session finishes. Timi is out of sight when she is hidden,
  while the screen locks, or while the screens sleep. Checked by: live.
- If you reset a session after more than 15 s, the session counts as
  abandoned. Timi is sad for 5 s and makes the "mrrp" sound. Checked by: unit,
  live.
- On `didWakeNotification`, the app computes the remaining time again. A
  deadline that passed during sleep gives a quiet finish, with the fanfare at
  50% volume. Checked by: unit.

## Physics

| Item | Value | Checked by |
|---|---|---|
| Home spring | Stiffness 90, damping 11 | unit |
| Drag spring | Stiffness 380, damping 26 | unit |
| Zoomies spring | Stiffness 200, damping 16 | review |
| Damping | Exponential | unit |
| Scale spring | Stiffness 240, damping 13. The hover scale is 1.06, and the start scale is 0.8. | review |
| Throw | A release faster than 650 pt/s starts a flight. The speed cap is 2600 pt/s. | unit, live |
| Flight drag | 1.5 | unit, live |
| Bounce half-size | 78 pt | unit, live |
| Restitution | 0.72 | unit, live |
| Impact | The strength is the speed divided by 1400, clamped to 0.2–1. An impact sets the scale to 1 − 0.18 × strength or less, and plays a boing. Timi hisses when the strength is more than 0.55. | unit, live |
| Flight end | A flight ends when the speed falls below 140 pt/s. | unit, live |
| Home insets | Top 90 pt, sides 125 pt, bottom 120 pt | unit, live |
| Squash | The strength is clamp(speed × 0.0004, 0, 0.16). The axis of the larger velocity component stretches by 1 + strength. The other axis shrinks by 1 − 0.6 × strength. | unit |
| Hop gravity | 260 | unit |
| Hop impulses | Start −30. Half and quarter milestones −34. Fidget hop −32. Finish −50. | unit |
| Walking | Faster than 90 pt/s. The feet alternate every 130 ms, and the body leans 1 px. | snapshot, dump |
| Held | The feet dangle and alternate every 260 ms. The eyes look down. | snapshot, dump |
| Worried | During each flight, and during a drag faster than 420 pt/s. The eyes are wide, and the mouth does not show. | snapshot, dump |

- A landing is hard when the hop height in the previous frame was more than
  0.6 px above the ground (`hopY < −0.6`). A hard landing gives a squash of
  100 ms, dust, and a thud. Small hops land quietly at 60 fps, as in the
  prototype. Checked by: unit.
- The breath period depends on the mode. Checked by: review.
  - Idle: 3.2 s. Paused: 5.5 s. Done: 1.0 s. Hunt: 0.5 s.
  - While the timer runs, the period decreases from 3.2 s to 1.0 s, on a curve
    of the squared progress.
  - Settling makes the period up to 1.8 times longer.
- The breath bounce is 1.1 px, and 0.6 px during the hunt. Timi does not bounce
  while she sleeps or loafs. Checked by: review.
- Fidgets occur every 8–17 s. The five kinds of fidget have the weights 30, 20,
  20, 20, and 10. Checked by: unit, review.
- Reduce Motion is a native addition, because the prototype has no motion
  setting. Sound does not change. Checked by: unit.
  - Timi does not hop, pounce, wiggle, fidget, or blink, and she has no
    zoomies.
  - The canvas shows no confetti, no sleep Zs, no landing dust, and no tail
    puff.
  - Squash is 0.3 of its normal size, and the breath bounce is 0.35 of its
    normal size.

## Personality

- Blinks occur every 2.8–7.8 s. A blink lasts 140 ms. Checked by: unit, review.
  - In 20% of cases, a second blink follows 300 ms later.
  - 25% of blinks are winks.
  - Timi does not blink while she sleeps, with Reduce Motion, or during the
    hunt.
- The eyes follow the pointer when it is within 300 pt. Checked by: unit.
  - The gaze vector points at the pointer, with a length of 4 px. It eases
    toward its target at a rate of 6 per second.
  - The eye offset is the gaze divided by 2.4 for x and by 3 for y, rounded,
    and limited to 1 px.
  - The code flips the vertical gaze, because AppKit y increases upward.
  - While you hold Timi, her eyes look down.
- When the pointer enters the halo, her ears perk for 600 ms. Checked by:
  snapshot, dump.
- A pat gives these reactions. Checked by: unit, snapshot, live.
  - A slow blink, with phases at 0, 250, 800, and 1300 ms
  - A blush
  - A pat heart that rises at 7 px/s for 1.1 s
  - A purr, on a cycle of 1450 ms
- Timi is happy for 10 s after a finish. She is not happy while she hunts or
  sleeps. Checked by: unit, snapshot, live.
  - While she is happy and idle and not walking, she kneads, with a step every
    300 ms.
  - When she is sad, her eyes are flat, she frowns, and her ears lie flat.
- Each completed session gives one heart. Checked by: unit, live
  (`tally-landed.png`).
  - The heart flies for 900 ms, on a sine arc of 7 px, into the tally heart.
  - The count increases one frame later, as in the prototype. A blip plays, and
    the tally heart flashes for 130 ms.
  - The tally shows the hearts of today, up to 99. The menu shows the all-time
    total.
- While Timi sleeps, a new Z appears every 1.7 s at (38, 14). Checked by: unit,
  live.
  - Each Z rises straight up at 3.5 px/s and lives for 1.8 s.
  - The canvas opacity is 0.88, and the glow is at 0.45.
- Confetti pieces start at (28, 22). Checked by: unit, review.
  - The start velocity is ±20 for x, and from −30 to −75 for y.
  - Gravity is 65, and each piece lives for 1.4–1.9 s.
  - There are five colors. A piece disappears at y ≥ 47.

## The cat

These details come from the prototype. Checked by: snapshot, review, dump.

- The palette, and a glow tint of (255, 210, 140)
- Five body variants, with the selection rules of the prototype
- Four ear states, the whiskers, the nose, and the mouth
- A tail chain of four segments, with all of its targets and ease rates, the
  tip, and the puff
- While she sleeps, the curled tail is a line across the front of her body
- The hunt: a crouch, wide eyes that do not blink, flat ears, and a wiggle
  every 80 ms
- The finish: the pounce, the zoomies, and the loaf
- The zoomies: from 0.9 s to 3.2 s after the finish, the home target swings
  left and right on `sin((t − doneT − 900) / 135)`
- Kneading
- The cat voice: meow, mew, trill, mrrp, purr, and hiss

## Audio

- The synth runs on an `AVAudioSourceNode`. Checked by: unit, measured.
  - The master gain is 0.5, followed by a 7.5 kHz low-pass filter.
  - Timi uses the default output device. The mute state persists.
  - The `sq` envelope rises in 4 ms. It holds that level until 60% of the note
    duration. Then it falls linearly to silence.
  - The audio engine pauses when it is silent.
- Each sound recipe matches the prototype. Checked by: unit, review.
  - The boing bend has an attack of 12 ms.
  - The purr has amplitude modulation at 23 Hz. The code does not clamp the
    modulated gain, so it can go below zero, as in WebAudio. So the throb
    continues after the gain fades, until the voice ends at 1.45 s.
  - The hiss is noise through a high-pass biquad filter.
- While Timi is out of sight, the ticks and the milestone sounds do not play.
  The finish fanfare still plays.
- Timi does not take exclusive control of audio. She uses only the default
  output.

## Menu bar, hotkey, Settings, and storage

- The status item shows a pixel portrait of Timi. When the timer is idle or
  done, the portrait is a template image. While a session runs and during a
  pause, it is in color, and an optional `mm:ss` time shows next to it.
- The menu has these items:
  - The first item, which changes with the timer state: **Start**, **Pause**,
    **Resume**, or **Reset**, with the current hotkey
  - **Reset**
  - The presets, and **Custom…**
  - **Sound**, **Show Timi** or **Hide Timi**, and **Cabinet Frame (CRT Look)**
  - **Launch at Login**, and **Show Tips**
  - A line with the hearts of today, the all-time total, and the streak
  - **Settings…**, and **Quit Timi**
- The global hotkey uses KeyboardShortcuts. The default is ⌃⌥T. The
  specification asked for ⌃⌥Space, but macOS uses that key combination to
  select the next input source. Settings has a hotkey recorder.
- The SwiftUI Settings window has all of the specified controls and an About
  section. Checked by: live (the layout).
- The app stores its data in two places. Checked by: live (the file contents,
  and a restore after a relaunch).
  - The settings are in `UserDefaults`.
  - `sessions.json` keeps one record for each session: `startedAt`,
    `durationMs`, `completed`, `character`, and `completedAt`.
  - A session counts for the day that it finished.
  - The app computes the hearts of today, the all-time total, and the streak
    from this file.
- The app saves the settings and the session records at each change, so a quit
  does not lose them.
- The app asks for notification permission when your first interaction closes
  the first-run hint. If that did not happen, it asks when the first session
  starts. Only the bundled app can show notifications.
- The app handles more than one screen, screen sleep, a locked screen, and
  Spaces (`canJoinAllSpaces`).

## Packaging

- The bundle ID is `com.2ls.timi`. The app is `Timi.app`, and the cask token is
  `timi`.
- `build.sh` makes a universal app (x86_64 and arm64) with the sandbox
  entitlement. The app starts and runs. `notarize.sh` notarizes a signed build.
  `release.sh` makes the zip and its sha256.
- The Homebrew cask is in `2ls-llc/homebrew-tap`. Its caveats explain how to
  open a build that Apple did not notarize.
- `release.yml` runs the tests and the build. When the signing secrets exist,
  it signs and notarizes the app. When they do not exist, it makes an ad-hoc
  build with a release note.
- `release.yml` then publishes the release. When `TAP_GITHUB_TOKEN` exists, it
  also opens a pull request on the tap. `ci.yml` runs the tests and the build
  on each push to `main` and on each pull request.
- For a build that Apple did not notarize, the README, the cask caveats, and
  the release notes give the Open Anyway steps. Homebrew 7 removed the
  `--no-quarantine` option.

## Quality

- The snapshot tests check 13 golden images. Each image exists at 1× and 3×.
  - The states are idle, running with the clock hidden, the done banner, held,
    and wall impact.
  - The other states are pat, sad, bored loaf, nap, hunt crouch, wiggle,
    zoomies, and loaf.
  - The hunt image covers the hunt state (`panic` in the code), and the nap
    image covers sleep.
  - On a 2× screen, each canvas pixel is 6 device pixels, by construction.
- A tap during a hop or a bounce counts. Checked by: unit.
- The timer is accurate to ±50 ms over 90 minutes, also across sleep and wake.
  Checked by: unit (exact wall-clock arithmetic).
- Reduce Motion works as the Physics section describes. Checked by: unit.
- VoiceOver reads Timi as a labeled button with a live value. Each chip has a
  label.
- For contrast, Timi draws a 1 px outline. The outline is on by default, and
  Settings has a toggle for it. The system Increase Contrast setting forces it
  on. The golden images show the outline on a white background.
- The panel is non-activating. Timi is an `LSUIElement` app, so she has no Dock
  icon and no entry in the ⌘-Tab switcher.

## Gaps in the checks

- No check used a screenshot of the real desktop, because the Screen Recording
  permission blocked it. The evidence images render the layer tree of the panel
  instead. They show the same content, without the desktop behind it.
- Notifications and the login item ran only as code paths, because they need
  the signed bundle.
- DSP unit tests and live playback check the audio. No test checks the output
  of the speakers.
- On a 1× screen, crisp pixels follow from the integer 3 pt cells. Only a 2×
  screen was available for the checks.
