# Actual — iOS app

Personal time estimation. A guess before you start, the real duration measured, and a
personal multiplier fed back into the next guess. Built from the spec in
`Claude outputs/actual-app-concept.md` and the screens in
`Claude outputs/actual-design-reference/`.

## Build and run

```
xcodebuild build -scheme Actual -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test  -scheme Actual -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Requires an iOS simulator runtime (iOS 26.5 is installed). Deployment target is iOS 18.0,
Swift 5 language mode.

## Targets

- `Actual` — the app.
- `ActualWidgets` — home screen widget and Live Activity, an app extension.
- `ActualTests` — unit tests.

`Shared/` is compiled into both the app and the widget: Core, the SwiftData models, the
design tokens, the App Intents, and the shared store. `Actual/` is app-only. Adding a
file to `Shared/` makes it available to both automatically.

The store lives in the **app group** `group.app.actual.Actual`, because a widget runs in
its own sandbox and cannot see the app's private container. **App groups work in the
simulator without a paid Apple Developer account** — the container is created on demand.

## Layout

- `Actual/Core/` — the bias engine and its value types. **Plain Swift, Foundation only.**
  No SwiftUI, SwiftData or CloudKit imports belong here; that boundary is the one piece
  of real insurance against a future platform rewrite, and it is what makes the math
  testable with literals.
- `Actual/Data/` — SwiftData models, and the deterministic seed history.
- `Actual/DesignSystem/` — the tokens from `design-reference/README.md`, plus the shared
  card, chip, button and progress components. Views pull colours from `Theme`, never
  literals.
- `Actual/Features/` — one folder per screen.
- `ActualTests/` — the engine's math, tested directly rather than through the views.

The project uses Xcode 16+ synchronized file groups, so new files under `Actual/` and
`ActualTests/` are picked up automatically. Adding a source file needs no project edit.

## What is built

The core loop, end to end: onboarding → home → estimate capture → running session →
session end → insights. The engine underneath implements estimate capture stages 1–5,
outcome tracking stages 1, 3 and 4, the bias engine stages 1–7, and the display and
insight views.

Quick start (start blind, label at the end), gap-filler suggestions over EventKit,
shared reminder links, and MapKit route baselines for trips are all built. All five
bottom-bar destinations are real screens. History and Profile have no design
reference, so they extend the language the other screens establish rather than
introducing a new one. Profile names what is not wired up yet in plain text instead of
showing switches that would do nothing, and its delete action sets `hasClearedData` so
the seed does not reinstate what was deliberately removed.

Trips end themselves. `TripMonitor` watches an active trip in the background and closes
the session on arrival, with no tap. Two mechanisms together: continuous updates give
the resolution to judge a dwell, and a monitored region wakes the app if iOS terminated
it. `TripProgressDetector` holds the decision logic as pure Swift so it is testable
without driving anywhere.

**Background location needs no paid Apple Developer account.** `UIBackgroundModes`,
`allowsBackgroundLocationUpdates` and region monitoring are Info.plist keys and ordinary
API, not entitlements. CloudKit and associated domains are the things that do need one.

Widgets and the Live Activity are built. The widget shows a live timer with a one-tap
End when something is running, and the person's most-used starts when nothing is. Both
buttons are App Intents that write to the shared store directly, so neither opens the
app. The Live Activity puts the same timer on the lock screen and in the Dynamic Island.

Two things worth knowing about widget timers. Use `Text(date, style: .timer)` in the
widget but `Text(timerInterval:countsDown:)` in the Live Activity — on iOS 26 the
`.timer` style renders as "2 minutes" there rather than a ticking clock. And neither
needs waking every second: the text draws itself from a date, so the timeline only
refreshes when the *content* could change.

Not built yet: voice's microphone and Siri layers, widgets and Live Activities, the
Watch and Mac targets, CloudKit sync, procrastination nudges, passive app tracking,
gamification.

**Unverified:** the Live Activity's End button did not respond to synthetic taps in the
simulator. The same intent works from the home screen widget, so the intent itself is
sound, but the lock screen button is worth trying by hand on a real device.

## Insight trend lines

Tapping any row on Insights opens `CategoryTrendView`, a Swift Charts line of the same
multiplier the ranking already shows, plotted over time via
`BiasEngine.multiplierHistory(for:from:)`. That method recomputes the recency-weighted
multiplier as of every instance, oldest to newest, using the exact same math as
`output(for:from:)` — the last point on the chart always matches the current ranked
number, and every earlier point is what the person would genuinely have seen at that
time, not a smoothed reconstruction.

## Passive app tracking

`Shared/Core/Passive/` holds the real, tested half: `AppUsageInterval` (open/close, on
device, nothing about content), `PassiveUsageAnalyzer` (buckets into `DayPart` —
morning/afternoon/evening/night — and finds a dominant part only when one genuinely
holds a majority, never manufacturing a pattern that is not there), and
`SeededAppUsageProvider` for demo data.

`Actual/Features/Passive/PassiveTrackingView.swift` is the opt-in UI: every app starts
unselected, a persistent indicator appears on Home the moment any app is on, and the
trend renders as "Mostly morning today" style text plus a day-part bar.

**The OS hook is the one piece not built, and cannot be — not just "not yet Apple
Developer."** Detecting that an app is open without inspecting its content is exactly
what `FamilyControls` + `DeviceActivity` are for, but `FamilyControls` — including the
app picker itself — needs the `com.apple.developer.family-controls` entitlement, which
Apple grants by manual review through a request form, separately from and not
guaranteed by a paid Developer Program membership. It also cannot be tested in the
simulator even once granted; it needs a physical device with Screen Time configured.
`Actual/Features/Passive/DeviceActivityUsageProvider.swift` documents the exact adapter
shape to write once that entitlement lands — conforming it to `AppUsageProviding` is
the entire remaining integration, nothing above that protocol changes.

## Live trip map and route baseline refresh

`TripMonitor` now records `route: [RoutePoint]` alongside phase tracking, throttled to
persist every 5th accepted fix (`Session.routeData`, JSON-encoded). `TripMapView` draws
it live with MapKit's `MapPolyline` — start pin, current-position dot, a stat card with
running time and distance — reachable from the active-session screen once a trip has
fixes to show. `RouteSummaryView` draws the same line non-interactively on the session
end screen once the trip has closed, the way an activity app shows a finished route.

Verified with a real simulated drive: the polyline grew from real GPS samples, distance
and time tracked correctly, and the session-end screen carried the completed route.

The baseline number also refetches at GPS-detected departure, not just at the tap that
started the trip — prep time between starting and actually leaving was making the
original number stale. A true "refresh 15–30 minutes before a trip planned in advance"
does not apply structurally yet: trips in this app start immediately when tapped, there
is no scheduled-for-later trip object for a pre-departure timer to watch.

## Reminder completion ping

`sharesCompletion` (off by default) is now a real toggle in `ReceiveReminderView`, and
`SentReminder` is a new model that gives the *sender's* device something to update —
previously, sending a reminder recorded nothing locally, so there was nowhere for a
ping to land. `ShareReminderView` persists one the moment Share Link is tapped.

The ping itself travels as a second link kind, `actual://ping/<shareID>`, generated on
session end only when the session traces back to a reminder with `sharesCompletion` on
(`Session.sourceReminderShareID` makes that link), and handled via `.onOpenURL` on
whichever device opens it. No content crosses, only the boolean fact and when: never
the guess, never how long it actually took.

This is the same substitution as the base reminder link — a manually-transported link
standing in for a push notification, because there is no backend to push through — and
is documented as the deliberate design here too, not a stopgap. Verified in two parts:
the receive-and-accept flow with the toggle on works end to end (confirmed live —
"Water the plants" landing in Home's "From others" section from a real generated link);
the link codec itself is covered by unit tests. The full loop — complete a
reminder-sourced session, generate the resulting ping, open it on the sender's device,
confirm `SentReminder.recipientCompletedAt` updates — is exercised by code review and
the passing test suite rather than a live device screenshot of that exact final step.

## Route detail from History and Home

`SessionDetailView` is the same guess/route-said/actual layout `SessionEndView` shows
the instant a session closes, minus the "Done" button — reachable now by tapping any
closed session on History or Home, not only in the few seconds around it ending. This
is what makes a trip's route visible again after the fact: previously the map only
existed transiently, with no way back to it.

Both `HistoryView` and `HomeView` present it as a sheet; each owns its own `@State`
selection and calls back into `RootView` for the one action inside it that touches
shared state (`onStartAgain`).

## Start again

`RootView.startAgain(_:)` repeats a past session — same category, same context — with
the *current* recalibrated estimate rather than freezing in whatever was guessed last
time. Reachable from the "Start again" button on `SessionDetailView`. Deliberately not
a duplicate of `start(_:)`: that one exists to turn typed or spoken text into a
category via `resolveCategory`, this one already has a real `TaskCategory` in hand and
must not re-run name matching against it. Runs through the same tail as any other
start — `open`, `announce` (Live Activity), `fetchBaseline`, `beginTripMonitoring` — so
repeating a trip restarts its GPS watching exactly like starting one fresh would.

## Export and import

`Actual/Data/DataTransfer.swift` is a plain JSON snapshot of every table — categories,
sessions, received and sent reminders — reachable from Profile → Your data. Import
upserts by the same unique key each table already enforces (`TaskCategory.id`,
`Session.uuid`, `shareID`), so importing the same file twice changes nothing the second
time, and importing an export from another device merges into what's here rather than
replacing it. Export writes to a temp file and hands it to `UIActivityViewController`
via a small `UIViewControllerRepresentable` bridge (`ActivityShareSheet`) — SwiftUI's
own `ShareLink` needs its item ready at render time, and export needs to write the file
first, so this is Button-triggered like every other action in the app rather than a
declarative share link.

Six tests cover the merge logic directly against a real in-memory `ModelContext`,
including the two properties that matter most: a repeat import of the same file adds
nothing, and importing into a non-empty store merges rather than replacing.

## Siri

`Shared/Data/SessionIntents.swift` now has an `ActualAppShortcutsProvider` alongside
`StartSessionIntent` / `EndSessionIntent`, discovered automatically — no entitlement,
no Info.plist key. This is the modern App Intents mechanism (iOS 16+), a different
system from the older SiriKit `INIntent` domains that needed `com.apple.developer.siri`,
which is why it works on a free Personal Team the same as a paid one.

`CategoryEntity` (`Shared/Data/CategoryEntity.swift`) makes the person's own categories
something Siri can resolve or ask about. `StartSessionIntent.category` is optional on
purpose: Siri asking "which category?" on every single invocation would be exactly the
friction quick start exists to avoid, so a bare "Hey Siri, start a session in Actual"
falls through to the same blind-start path the app's own quick start uses. **The model
is never asked to parse the number** here either, for the same reason as the deterministic
parser in `Core/Voice/` — Siri's own native duration-parameter resolution is used
instead of any custom parsing.

Verified live: the Shortcuts app shows "Actual" with both shortcuts discoverable, and
running "Start a session" from there wrote a real session into the store, visible on
Home with the correct recalibrated expectation. Real "Hey Siri" wake-word activation
needs physical hardware to verify; the App Intents themselves do not.

Still not wired: the microphone / `SFSpeechRecognizer` path for free-form speech
outside a Siri-structured invocation, and the stage 10 transcription echo.

## Dynamic Island sizing

`SessionLiveActivity`'s compact and expanded trailing regions dropped their fixed
`.frame(maxWidth:)` values in favour of `.minimumScaleFactor` — a guessed pixel width
is exactly what gets clipped by the island's own rounded cutout on real hardware, which
the simulator does not render with the same fidelity. The compact region also passes
`showsHours: false` to `Text(timerInterval:)`, capping the string at "59:59" rather
than letting "1:23:45" appear the moment a session crosses an hour in the tightest
space anywhere in the Dynamic Island. Unverified on physical hardware — worth a look
once running on a device.

## Substitutions worth knowing

Two places where what is built differs from the concept doc, both for want of an Apple
Developer team rather than by preference:

- **Shared reminders carry their payload inside the link,** and that is now the intended
  design rather than a stopgap. The doc calls for CKShare
  with a short token resolved against the sender's own iCloud record. That needs a
  CloudKit container and an associated domain. The value types and both screens are
  shaped for the eventual transport, so swapping it changes nothing above
  `SharedReminderLink`. The optional completion ping back to the sender (stage 6) has
  nowhere to go until then, and is not built.
- **Route baselines are fetched once, when a trip starts.** The doc's stage 2 refresh
  shortly before departure needs scheduled background work, which is not wired up.

Note also that `RouteBaselineService` is deliberately allowed to return nil, and every
screen below it treats that as ordinary. A failed routing call must never block a trip
from starting or closing.

## Testing a trip without driving

```bash
xcrun simctl privacy booted grant location-always app.actual.Actual
xcrun simctl location booted set 52.2297,21.0122          # park at the origin
# start a trip in the app with a destination set, then step along a route:
xcrun simctl location booted set 52.2100,20.9950
# ... and finally hold still at the destination for the dwell
```

Two traps worth knowing. The destination is wherever MapKit's search returned, which is
not necessarily the coordinates you had in mind — check the `begin:` line in the log
below. And CoreLocation stops delivering updates when stationary, which is why the dwell
is confirmed on a timer rather than on further readings.

The trip monitor logs its decisions, since a background feature that silently fails to
start has nothing on screen to look at:

```bash
xcrun simctl spawn booted log show --last 5m \
  --predicate 'subsystem == "app.actual.Actual"' --style compact
```

## Debug launch hooks

`Actual/Features/LaunchOptions.swift`, `#if DEBUG` only, opens the app straight onto a
screen so it can be screenshotted without driving the UI by hand:

```
xcrun simctl launch booted app.actual.Actual -hasOnboarded YES -startOn insights
xcrun simctl launch booted app.actual.Actual -hasOnboarded YES -startOn capture -captureTitle "Work session"
xcrun simctl launch booted app.actual.Actual -hasOnboarded YES -startOn active
xcrun simctl launch booted app.actual.Actual -hasOnboarded YES -startOn end
```

`-startOn end` closes the running session through the same path the End button uses.

The seed only runs against an empty store, so `xcrun simctl uninstall booted
app.actual.Actual` before reinstalling if you change `SeedData` and want it regenerated.

## Voice

Two layers, in `Actual/Core/Voice/` (deterministic, pure Swift) and `Actual/Voice/`
(model-backed). `LayeredVoiceParser` is the entry point.

**The model is never trusted with a number.** Asked for "probably two hours" the
on-device model answers `2`, not `120`. A two hour session logged against a two minute
estimate is a sixty-fold error feeding straight into the bias engine, so
`KeywordVoiceParser.scanDuration` is the sole authority on durations and the model's
figure is discarded. The model is used for language — loose phrasing and the words
naming the activity — and nothing else. If the scanner reads no duration, the command
carries none, because a missing guess is a supported state everywhere in the app and a
fabricated one is silent corruption.

Adding a language means adding a table to `VoiceLexicon`, not writing logic. English,
Russian and Ukrainian ship. Category names are never translated or language-tagged:
matching runs on the person's own names in whatever language they were created.

Not yet wired: the microphone and `SFSpeechRecognizer` transcription, App Intents /
Siri, and the brief transcription echo the concept asks for (stage 10). The parser and
resolver below it are complete and tested.

## What this machine can actually test

Measured on this Mac against the iOS 26.5 simulator, not assumed. Re-check before
relying on it, since it depends on the host being Apple Intelligence capable:

- `SystemLanguageModel.default.availability` reports **available** in the simulator, so
  the Foundation Models parsing layer can be developed and tested here, no device needed.
- `SFSpeechRecognizer` reports 63 supported locales, `isAvailable` true and
  `supportsOnDeviceRecognition` true for en-US. Speech authorization starts at
  `notDetermined` (0), so the app must request it and declare
  `NSSpeechRecognitionUsageDescription` and `NSMicrophoneUsageDescription`.
- The Shortcuts app is present in the simulator (`com.apple.shortcuts`), so App Intents
  can be invoked there.
- Siri wake-word activation ("Hey Siri, start a work session in Actual") is the one part
  that needs real hardware.

So the parser is the part carrying the real risk, and it is fully testable here with
text input and no audio at all. `ModelVoiceParserTests` runs live inference in the
simulator and skips itself automatically where the model is unavailable, so the suite
stays green on machines that cannot run it.

## Conventions

- Nothing displays a hardcoded number. Every figure on screen comes out of the engine,
  computed from seeded history, so the screens exercise the real calculation.
- No number is shown without the history behind it. Below the minimum threshold the
  recalibrated estimate is absent, not zero; low confidence renders muted and says so.
- Closing a session writes immediately. There is no confirmation step anywhere in the
  outcome path, by design.
- Copy stays neutral about how time is spent. It reports, it does not rank.
