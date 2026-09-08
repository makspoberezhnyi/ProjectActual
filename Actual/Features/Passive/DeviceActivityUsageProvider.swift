import Foundation

/// Where the real OS integration goes once it can exist.
///
/// Detecting that a tracked app is open — without ever looking at what is on screen —
/// is exactly what Apple's `DeviceActivity` and `FamilyControls` frameworks are for:
/// a `DeviceActivityMonitor` app extension gets `intervalDidStart` / `intervalDidEnd`
/// callbacks per app or category, entirely on-device, with the raw log never leaving it.
///
/// The reason this file is empty of that implementation: `FamilyControls` — including
/// the app picker used to choose which apps this applies to — requires the
/// `com.apple.developer.family-controls` entitlement, and Apple grants that by manual
/// review through a request form, not automatically alongside a paid Developer Program
/// membership. It cannot be tested in the simulator even once granted; it needs a
/// physical device with Screen Time set up.
///
/// What this app does instead, right now: everything downstream of `AppUsageProviding`
/// is real and tested — the day-part bucketing, the per-app daily timer, the trend
/// detection, the opt-in scope and the persistent indicator the concept requires. Only
/// this one adapter is missing, and conforming it to `AppUsageProviding` is the entire
/// integration surface once the entitlement is approved:
///
///     struct DeviceActivityUsageProvider: AppUsageProviding {
///         func intervals(on day: Date) -> [AppUsageInterval] {
///             // read today's DeviceActivityMonitor callbacks, mapped 1:1 onto
///             // AppUsageInterval — no other file in the app needs to change.
///         }
///     }
enum DeviceActivityUsageProvider {}
