# Project Actual (Tempo)

**Actual** is an intelligent iOS, watchOS, and macOS application centered around **Tempo**, a conversational AI assistant that helps you track time, manage your schedule, and stay focused.

By utilizing a chat-based interface, users can naturally declare what they are working on, ask for schedule summaries, calculate travel times, and seamlessly sync tasks with Apple Calendar and Reminders.

## Key Features

- **Conversational Time Tracking:** Start a focus session simply by texting your intent (e.g., "Working on the design doc for 45m"). Tempo intelligently parses durations, tasks, and commands.
- **Deep Apple Integrations:**
  - **Calendar & Reminders:** Sync your tracked sessions and upcoming tasks with native Apple services (`EventKit`).
  - **Live Activities & Dynamic Island:** Real-time session progress and countdowns right on your Lock Screen and Dynamic Island (`ActivityKit`).
  - **Widgets:** Home Screen widgets to glance at your current focus session and daily schedule.
  - **watchOS Companion:** Log tasks, extend sessions, or stop tracking directly from your Apple Watch.
- **Location & Travel Estimates:** Ask Tempo how long it takes to travel to your next meeting or a specific destination, integrating directly with `MapKit` and CoreLocation.
- **Routine Engine:** Automate daily workflows and establish focused habits using the built-in Routine Engine.
- **Offline Parsing & Privacy:** Core NLP intent parsing happens safely on-device.

## Architecture

- **`Actual/`**: Main iOS application target containing SwiftUI views, the `TempoConvoEngine`, `ChatParser`, and SwiftData models.
- **`Shared/`**: Shared code between targets, including `LiveActivityManager` and App Intents.
- **`ActualWatch/`**: The watchOS companion app for on-the-wrist time tracking.
- **`ActualWidgets/`**: Widget extensions for Home Screen and Lock Screen widgets.
- **`Supporting/`**: Entitlements and `Info.plist` configurations for all targets.

## Getting Started

1. Open `Actual.xcodeproj` in Xcode.
2. Select the **Actual** iOS scheme.
3. Build and run on a physical device or simulator (iOS 17+ recommended for full SwiftData and Live Activity support).

