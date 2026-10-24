# Roadmap

This is an early source preview, maintained on a best-effort basis. These are priorities, not promised dates or shipped features. No AI features, hosted backend, subscription, or new dependency is planned for application optics.

## Next evidence to collect

- Real HomeKit light writes, offline recovery, permission revocation, and scene cancellation/completion. Record accessory model, OS, expected/observed results, and sanitized failures.
- Authorized WeatherKit data on a signed physical device, including attribution, approximate location, denial, stale data, and provider isolation in Release.
- Foreground standby brightness restoration, sensor shutdown, audio interruptions, and a measured long-duration display run. No energy-saving claim before measurement.
- Compatibility on the oldest available iPadOS 17 device/runtime, with VoiceOver and largest Dynamic Type. The deployment target alone is not compatibility evidence.

## Bounded contributor opportunities

These can become issues after scope is agreed; they are not completed work or adoption evidence.

| Candidate | Acceptance evidence | Suitable for |
| --- | --- | --- |
| English/Chinese setup parity | Follow both build guides from a fresh clone; correct only demonstrated differences | First documentation contribution |
| VoiceOver navigation audit | Record labels/order for Overview, Home, and Settings with synthetic content; propose focused fixes | Accessibility testing |
| Weather decoder edge cases | Add a fixture only for a demonstrated malformed-response gap; assert explicit unavailable behavior | Swift unit-test contribution |
| Hardware report | Complete one scenario in HARDWARE_CHECKLIST with reproducible steps and no personal data | Device owners |

Discuss broader HomeKit adapters before implementation. HomeViewPad remains a dashboard, not a home hub or replacement for Apple's Home setup, Siri, Intercom, or Apple Music.
