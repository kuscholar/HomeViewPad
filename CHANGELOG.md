# Changelog

Changes describe shipped source, not App Store availability or certified hardware support.

## 0.1.0 — source preview (release candidate)

First versioned source preview; see GitHub Releases for publication status.

### Included

- Native SwiftUI iPadOS 17+ dashboard with Overview, Apple Home controls, scene confirmation, clocks, and PhotoKit photo display.
- Labeled deterministic demo; HomeKit manager and standby sensors remain inactive in demo.
- Optional personal calendar/reminders, HomeKit camera viewing, local audio/system AirPlay, and experimental foreground standby.
- WeatherKit-only Release; Debug provider selection, cancellation, stale-data handling, and approximate foreground location.
- XCTest/XCUITest coverage, standard macOS CI, isolated simulator fixtures, Release regression lane, and explicit optional live-service checks.
- Contribution/security policies, issue/PR templates, hardware reporting protocol, roadmap, and release checklist.

### Corrected

- Chinese demo caption now matches the actual 15-second recording.
- Hardware checklist distinguishes historical installation/launch from pending feature verification.
- Project version is 0.1.0 in both generator and generated settings, replacing the unversioned starter value 1.0.

### Known limitations

Source-only; no App Store listing or signed binary. Physical HomeKit actions, camera streaming, HomePod/AirPlay, authorized WeatherKit readings, standby detection/brightness restoration, and long-running display performance need further device evidence. Simulator CI excludes three live-service checks and does not establish hardware correctness. iPadOS 17 is the deployment target, not a tested compatibility matrix. See docs/VALIDATION.md and docs/HARDWARE_CHECKLIST.md.
