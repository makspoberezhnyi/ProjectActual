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
End when something is running. When nothing is, the primary control is one big blind
"Start" button — `StartSessionIntent()` with no category, the same "start now, label it
when you're done" path the app's own quick start uses — with the person's most-used
categories as smaller secondary shortcuts beside it on `.systemMedium` (there's no room
for both on `.systemSmall`, so the blind start is the whole widget there). All three
buttons are App Intents that write to the shared store directly, so none of them open
the app. The Live Activity puts the same timer on the lock screen and in the Dynamic
Island.

Two things worth knowing about widget timers. Use `Text(date, style: .timer)` in the
widget but `Text(timerInterval:countsDown:)` in the Live Activity — on iOS 26 the
`.timer` style renders as "2 minutes" there rather than a ticking clock. And neither
needs waking every second: the text draws itself from a date, so the timeline only
refreshes when the *content* could change.

## Starting from outside the app: Control Center, Lock Screen, Action Button

Three different mechanisms, not one, because iOS draws a real line between them:

- **Control Center and the Lock Screen's two customizable slots** (the ones that
  default to Flashlight and Camera) are both populated by the same thing: a
  `ControlWidget`, iOS 18's Controls API. `ActualWidgets/StartSessionControl.swift`
  adds one — `StartSessionControl`, a single stateless button wired to the same
  `StartSessionIntent()` blind start the widget's own button and Siri use. It needs no
  new extension, entitlement, or Info.plist key: Controls run in the same
  `com.apple.widgetkit-extension` point the widget already declares, so it's just
  another member of `ActualWidgetBundle`. Verified live in the simulator: "Actual" and
  "Start a session" show up correctly in the system's own Control gallery (Control
  Center's "+" → Add a Control), the same picker that also feeds the Lock Screen's
  customization screen — placing it in either spot is the person's own drag-and-drop
  choice in system UI, not something the app can do on their behalf.
- **The Action Button** (iPhone 15 Pro and later) needs no app-side code at all. It's
  configured in Settings → Action Button → Shortcut, and `ActualAppShortcuts`
  (`Shared/Data/SessionIntents.swift`) already registers "Start a session in Actual" as
  a real Shortcut — that's what made Siri and the Shortcuts app work, and it's the same
  registration the Action Button's shortcut picker reads from. Nothing new to build
  here; worth telling people the capability already exists.
- **Camera Control** (the iPhone 16 series' dedicated hardware button) is not one of
  these. Its public API, `AVCaptureEventInteraction`, only delivers press events to a
  view that is already on screen and frontmost in the app that adopts it — there is no
  supported way for a third-party app to have it launch or trigger an action system-wide
  the way Controls or the Action Button do. It's built for a camera-style shutter
  gesture inside an already-open app, not a global shortcut, so it isn't a path to
  "start a session without opening the app" and nothing here tries to use it as one.

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

## Passive app tracking — pulled from the UI

There is no reachable "Screen time" screen right now. There was one
(`Actual/Features/Passive/PassiveTrackingView.swift`), and it looked real — an opt-in
per-app toggle, a persistent Home indicator, "Mostly morning today" trend text — but
every number behind it came from `SeededAppUsageProvider`, a deterministic fake
generator, not anything actually observed on the device. That is indistinguishable from
real tracking by looking at it, which is exactly the problem: it was pulled the moment
that was noticed, rather than left running under the excuse that the OS hook will
land eventually. `Actual/Features/Profile/ProfileView.swift`'s "Not connected yet" list
now names it in plain text alongside iCloud sync and Siri, the same honest-line
treatment the rest of that list already uses for things that are not wired up.

`Shared/Core/Passive/AppUsageInterval.swift` (the `AppUsageProviding` protocol and the
plain interval type) and `PassiveUsageAnalyzer.swift` (day-part bucketing, dominant-part
detection) are untouched and still covered by `PassiveUsageTests` — that half was never
the dishonest part, it is real, tested logic with nothing to plug into it yet.
`SeededAppUsageProvider.swift` and `TrackableApp` (the fake generator and the
hand-picked candidate list) are deleted, not just disconnected, since nothing honest
was ever going to read from them.

**The OS hook is the one piece not built, and cannot be — not just "not yet Apple
Developer."** Detecting that an app is open without inspecting its content is exactly
what `FamilyControls` + `DeviceActivity` are for, but `FamilyControls` — including the
app picker itself — needs the `com.apple.developer.family-controls` entitlement, which
Apple grants by manual review through a request form, separately from and not
guaranteed by a paid Developer Program membership. It also cannot be tested in the
simulator even once granted; it needs a physical device with Screen Time configured.
`Actual/Features/Passive/DeviceActivityUsageProvider.swift` still documents the exact
adapter shape to write once that entitlement lands and a real `PassiveTrackingView`
gets rebuilt against it — conforming it to `AppUsageProviding` is the entire remaining
integration, nothing in the analyzer changes.

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

## Deleting

Two deletions, both from where the thing being deleted actually lives: "Delete this
session" on `SessionDetailView` (`RootView.deleteSession`), and a small "x" on each row
of Profile's "Reminders you've sent" (`ProfileView`, confirmed via alert). Neither
cascades — deleting a session does not touch a `ReceivedReminder` that pointed at it via
`sourceReminderShareID`, and deleting a `SentReminder` just means a future completion
ping for that link finds no match and quietly does nothing, the same graceful-absence
behaviour the ping already relies on elsewhere.

## Capture as a review step, not an instant start

`startAgain` used to create and open a session immediately — no chance to look at the
guess before the clock started, which is exactly backwards from every other capture
path in the app. It now opens the same `EstimateCaptureView` a fresh "+" does,
pre-filled via `EstimateCaptureView.Prefill`, so the estimate is something to confirm
or edit, not something already committed.

This surfaced two real SwiftUI bugs worth knowing about if a similar prefill pattern
gets used elsewhere:

- **A custom `init` seeding `@State` only takes effect on a genuinely new view
  identity.** Re-presenting a `.sheet` can reuse the previous presentation's `@State`
  storage rather than re-running `init`, so a new `prefill` value silently never lands
  — the fields keep whatever was there last time. `.sheet(item:)`, keyed on a fresh
  `Identifiable` value per presentation, sidesteps this by construction: a new identity
  is definitionally a new presentation.
- **Dismissing one sheet and presenting another in the same synchronous action is not
  guaranteed ordering.** The capture sheet's content closure was directly observed
  (via logging) evaluating with a stale, nil prefill a few milliseconds after the
  correct value had already been written — moving the second sheet's presentation onto
  the next run loop tick did not fix it either. What actually fixed it was not having
  two separate pieces of state (`isPresented: Bool` + a prefill read inside the
  closure) that could disagree about timing at all: `RootView.CaptureRequest` folds
  both into one `Identifiable` value, so there is nothing left to race.

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

The compact pill used to balloon out to nearly the full screen width instead of a tight
capsule around the sensor housing — confirmed live in the simulator, not just a
suspicion. The cause was `Text(timerInterval:)` being given an open-ended range ending
at `Date.distantFuture` (year 4001): the view sizes itself for the *widest* value the
interval could ever show, not the current one, so it was reserving layout width for a
number with dozens of digits. `SessionLiveActivity.elapsedRange(from:)` bounds every
`timerInterval` (compact, expanded, and lock screen) to 24 hours from `startedAt`
instead — `countsDown: false` still just counts up the same as before, the bound only
caps what the layout system has to plan for. The compact trailing region also carries an
explicit 44pt `.frame` now rather than relying on `.minimumScaleFactor` alone to keep it
pinned tight. Measured against Apple's own documented compact-island width (~235pt) on
the simulator: it now lands within a few points of that, down from ~348pt (87% of the
402pt screen) before the fix.

The expanded presentation was also simplified to one row — a leading dot+timer with the
title underneath, and one big circular stop button on the trailing side, the same shape
as the system's own screen-recording Live Activity — replacing a three-region layout
(title/context, timer, and a separate bottom row with the expected duration and a small
"End" pill) that read as cluttered and was clipping the first glyph of the title against
the island's own rounded corner. The stop button reuses the exact glyph from the in-app
End button (`SessionActiveView.endButton`): a small rounded-square icon on a filled
circle. Verified live in the simulator, both compact and expanded. The Live Activity's
own End button not responding to synthetic taps in the simulator (noted elsewhere in
this file) is unrelated to this pass — that's an input-injection limitation, not a
layout one — and is still worth trying by hand on a real device.

## Appearance: light, dark, or system

Every `Theme` colour (`Shared/DesignSystem/Theme.swift`) is a `Color` built from
`UIColor { traitCollection in ... }` rather than a fixed hex value, so it resolves
against whatever trait collection is actually drawing it — light and dark are two
values on the same token, not two themes maintained in parallel. That is what lets the
picker in Profile → Appearance (System/Light/Dark, `AppearanceMode`, stored under
`appearanceMode`) flip every screen at once: nothing below `RootView` needs to know the
setting exists. Defaults to Dark, matching how the app looked before this existed, so
nobody's screen changes underneath them without asking.

`RootView.applyWindowAppearance()` is the single source of truth, walking every
connected `UIWindowScene`'s windows and setting `overrideUserInterfaceStyle` directly,
deliberately not paired with `.preferredColorScheme`. That modifier only sets an
environment value — a `sheet` or `fullScreenCover` gets its own presentation controller
this app's dynamic `UIColor`-backed tokens resolve their `UITraitCollection` against
directly, which the environment override does not reliably reach on its own; skipping
the window-level walk reproduces as a sheet or the active-session cover rendering
completely blank, correct background but every `Theme.ink` text token resolving to the
same value as the background it sits on.

"System" specifically stayed broken after that fix, always forcing dark regardless of
the device's real setting. The cause was upstream of any of this code: the project had
`INFOPLIST_KEY_UIUserInterfaceStyle = Dark` baked into both build configurations from
when the app was dark-only, which sets the *app-wide default* a window falls back to
whenever nothing overrides it — exactly what choosing "System" resolves to
(`.unspecified`). An explicit `.light` or `.dark` selection always won regardless, which
is exactly why only "System" looked broken while the other two didn't. Confirmed by
logging every layer at once — `UIScreen.main`, `UITraitCollection.current`, a window's
own resolved trait, even one that had never been touched by any of this code — and
finding them all agreeing on dark, with that plist default as the one thing they had in
common. `INFOPLIST_KEY_UIStatusBarStyle = UIStatusBarStyleLightContent` sat right next
to it, the same dark-only assumption applied to the status bar specifically; removed for
the same reason. Both are gone from the project settings now — `applyWindowAppearance`
is what decides appearance, not a static build setting left over from before the toggle
existed.

The translucent washes (`line`, `track`, `badge`, `pill`, `accentDim`) needed their own
light values rather than a blanket flip — they're white-at-low-opacity in dark mode,
which would render as a literal white smear on a light background rather than a subtle
wash. Light mode uses the same washes in black instead, via `Color.dynamicOpacity`.

Typography got a modest across-the-board bump at the same time — `Typeface`'s functions
apply a fixed 1.08× scale to whatever size they're called with, so every screen reads
slightly larger without a per-call-site pass through the whole design system.

## Custom category icons

A category created by typing a name that matches nothing existing used to fall back to
a plain, unlabelled circle forever — `TaskCategory`'s own default, with no way to change
it afterward. `CategoryIconPicker` (`Actual/Features/Capture/`) is a curated, scrollable
row of SF Symbols in the same mostly-unfilled style the seeded categories already use
(`laptopcomputer`, `car.fill`, `envelope`, `cart`, `phone`, `book` — see `SeedData`), and
it shows up in both places a session can actually create a new category: `EstimateCaptureView`,
the moment what's typed stops matching anything existing, and `SessionResolutionView`'s
"what was this" step at the end of a quick start, the same moment.

The choice only means anything the instant a category is actually created —
`SessionOperations.resolveCategory` takes an optional `symbolName`, applies it only on
the create path, and an existing match keeps whatever icon it already had regardless of
what the caller passes. `SessionDraft.symbolName` and `SessionResolutionView.onResolve`'s
extra parameter carry the choice from each screen down to that one call, `nil` whenever
the typed name matched something existing and the picker never appeared to begin with.

`CategoryIconPicker` also has an emoji entry slot ahead of the curated SF Symbol row: a
plain `TextField` whose displayed and accepted value is only ever whatever the person's
own emoji keyboard produces, reached through the system's own keyboard switcher exactly
like typing an emoji into Messages — there is no public, supported way to force the
emoji keyboard open on its own, so this doesn't try. `symbolName` on `TaskCategory` holds
either kind of icon in the same field; `String.isEmojiIcon` (`Shared/DesignSystem/CategoryIcon.swift`)
is what tells them apart at render time, and `CategoryIconView` — shared with the widget
target, since a quick-start button there shows the same icon — draws an `Image(systemName:)`
or a plain `Text` accordingly. There is no way to make an emoji match the SF Symbols'
monochrome line style: an SF Symbol is a vector path this app can recolour and weight to
fit `Theme`, an emoji is fixed, pre-rendered colour artwork (Apple's Color Emoji font)
with no path to restyle, so a picked emoji renders exactly as picked, full colour,
everywhere `CategoryIconView` is used.

## Editable profile

Name and photo are real settings now rather than the seed's fixed "Marta" — Profile's
header is a button that opens `EditProfileView` (`Actual/Features/Profile/`), and both
fields bind straight to `@AppStorage` (`displayName`, `profilePhotoData`) and apply
live, the same no-separate-save-step pattern the appearance picker already uses.
`displayName` was already there, quietly unreachable — `ShareReminderView` has read it
as the sender's name on every reminder link since before this existed, just with
nothing in the app ever writing to it. Home's greeting reads the same key, so a name
changed once updates both places without needing to know about each other.

A photo is picked via `PhotosPicker`, then square-cropped and compressed to a 240×240
JPEG (`ProfilePhoto.processed(_:)`) before it ever reaches `UserDefaults` — a
straight-from-the-library photo can run several megabytes, and `@AppStorage` is not the
place for that. No photo falls back to the first letter of `displayName`
(`ProfilePhoto.initial(for:)`), shared between the small header avatar and the larger
one in the edit screen rather than duplicated.

## Liquid Glass

`BottomBar` floats now rather than spanning edge-to-edge: a `Capsule` filled with
`.ultraThinMaterial`, inset from both the screen edges and the safe area, so content
scrolls visibly behind it instead of disappearing under an opaque strip — the same
footprint reduction a system Liquid Glass tab bar gets for free. This app's bar is a
hand-built `HStack`, not a real `TabView`, so there is no single modifier that turns the
whole thing into system chrome; `.ultraThinMaterial` is what stands in for the
container's own glass on every iOS version this app supports.

The centre "+" is the one circle in the bar, deliberately, using the real iOS 26
`.glass` button style on iOS 26+ (falling back to a plain filled circle below that).
Deliberately plain `.glass`, never `.glassProminent`: prominent fills with the tint
colour and always draws its content in white, which on this app's near-white dark-mode
`Theme.accent` left the "+" almost invisible against its own background in testing.
Plain glass draws the icon in whatever colour it's actually given (`Theme.ink`).

The four tabs went through a second pass after first shipping each one in its own small
glass circle too, matching the "+" — visually it read as too heavy, the icons ended up
small relative to their bubbles, and five circles of near-identical size buried the one
that's actually an action rather than a destination. They went flat: icon over a small
label, sitting directly on the bar's shared glass with no circle of their own, and the
label is a real accessibility and legibility win a bare icon row didn't have.

A third pass added a `.regularMaterial` pill back in behind whichever tab is actually
selected — colour alone (`Theme.ink` versus `Theme.inkFaint`) turned out too subtle a
signal once every tab sat equally flat against the bar; going fully flat traded away
legibility of *which* tab is current for the sake of not looking heavy. `.regularMaterial`
specifically, not the bar's own `.ultraThinMaterial`: stacking the same material on top
of itself barely reads as a distinct shape, where the more opaque one visibly sits on
the bar's glass rather than blending into it. A fixed-radius `RoundedRectangle`, not
`Capsule()` — at this height a capsule's ends round so aggressively they crowd the
label, and on the first and last tab the curve sits close enough to the bar's own edge
to look pinched.

The pill slides between tabs now rather than fading out in one place and back in at
another, via `matchedGeometryEffect` — the same shared namespace `id` on either side of
a `withAnimation` change is what tells SwiftUI to interpolate the frame between two
positions instead of cross-dissolving, stretching briefly across whatever tab sits
between the old and new selection along the way. Modelled on a reference video of
another app's tab bar the person sent — matched the pill shape, the stretch-through-the-
middle motion, and the `.bouncy` spring, deliberately not the reference's blue selected-
state colour, which stayed `Theme.ink` to match the rest of the app's monochrome
palette. The "+" stays the one circle that's always present regardless of selection,
since it isn't a destination toggling on and off, it's a constant action. The pill grew
taller and rounder across two follow-up passes — the row itself went from 44pt to 48pt,
the pill dropped its vertical padding entirely to fill that full height rather than
sitting visibly inset from it, and its corner radius went from 16 to 20 to match: a
flatter radius would look under-rounded at the new height, and a full `Capsule()` still
isn't right for the same reason noted above, crowding the label at the sides.

Each tab's icon also carries `.symbolEffect(.bounce, value: isSelected)` — a real,
built-in SF Symbol animation (iOS 17+), not a hand-rolled one. Apple doesn't ship
anything like a general animation-asset library the way Lottie does, but symbol
effects are the one place it does provide ready-made presets (`.bounce`, `.pulse`,
`.wiggle`, `.variableColor`, `.replace`, and others), free with a single modifier.
Layered on top of the pill's slide rather than replacing it, so selecting a tab gets
both the shared pill moving and a small bounce on the icon landing on it.

History's icon changed from `line.3.horizontal` to `clock.arrow.circlepath` in the same
pass — a hamburger glyph reads as "menu," not "a log of what already happened," and the
label alone shouldn't have to carry a mismatch the icon could just not have. Profile
moved to `person.crop.circle.fill`, closer in shape to the actual avatar circle now
sitting above it in the Profile header.

Checked directly against this project's exact Xcode/SDK build (`strings` on the compiled
`SwiftUI.swiftmodule`) before relying on any of this: `.glass` and `.glassProminent`
button styles are real and present, but `.glassEffect()` and `GlassEffectContainer` are
not — so nothing here calls either of those. A real `TabView` would get the full native
Liquid Glass tab bar chrome (including `tabBarMinimizeBehavior`, confirmed present in
this SDK) for free, but this app's centre "+" is not a real tab — it always opens a
sheet, never a destination — which is what a genuine `TabView`/`Tab` migration would
have to solve first. Worth revisiting if that migration ever happens; not attempted
here given how load-bearing `RootView`'s existing sheet-timing logic already is.

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
