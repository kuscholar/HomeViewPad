# Contributing to HomeViewPad

HomeViewPad is a small, independent SwiftUI iPad app. Focused bug fixes, accessibility improvements, tests, translations, and carefully documented device results are welcome. Read [AGENTS.md](AGENTS.md), [architecture](docs/ARCHITECTURE.md), and the [roadmap](docs/ROADMAP.md) first.

## Build and reproduce

Use macOS, Xcode, Python 3, and an installed iPad simulator runtime. No third-party packages, API key, signing certificate, or Apple developer membership is needed for simulator work. The deployment target is iPadOS 17; that is not a claim that every supported OS has been tested. See [validation](docs/VALIDATION.md) for actual toolchains.

```sh
git clone https://github.com/kuscholar/HomeViewPad.git
cd HomeViewPad
open HomePad.xcodeproj
```

Choose HomePad and an iPad simulator. Add `--demo` to the scheme's launch arguments for labeled, deterministic accessory/weather fixtures. Demo never initializes HMHomeManager or starts standby sensors. Photos still require explicit selection/permission; use synthetic fixtures, never a personal photo library for public evidence.

For repeatable tests, create a dedicated simulator (the script prints its UUID), boot it, and seed original gradient images:

```sh
python3 scripts/create_test_simulator.py
xcrun simctl boot SIMULATOR_UUID
xcrun simctl bootstatus SIMULATOR_UUID -b
python3 scripts/seed_test_photos.py SIMULATOR_UUID
xcrun simctl location SIMULATOR_UUID set 39.9526,-75.1652
sh scripts/test.sh SIMULATOR_UUID
```

`test.sh` defaults to the complete suite, including three live weather/geocoding UI tests. `test.sh UUID ci` excludes those three external-service checks explicitly; `test.sh UUID network` runs only those checks. `test.sh UUID release` runs the Release weather tests, including the saved-Debug-provider isolation regression. The CI lane still covers demo, controls, photos, navigation, accessibility layouts, standby permissions, and labeled weather fixtures. A green CI lane is not a green complete suite or proof of live WeatherKit availability.

Results are written to a unique temporary directory. Set `RESULT_BUNDLE_PATH` and `DERIVED_DATA_PATH` to retain them elsewhere. The script preserves xcodebuild's exit status and prints the result path even on failure. Inspect the xcresult in Xcode; do not repeatedly rerun a failure until it passes without recording the original failure.

## Make a focused change

1. Fork and branch from current main. Explain the reproducible problem and expected behavior before large scope changes.
2. Keep public Apple APIs, no backend/accounts/tracking, and the current architecture. Never import employer code, credentials, home identifiers, or unlicensed assets.
3. Put personal signing in ignored `Config/Local.xcconfig`; follow the README for physical-device entitlements. Do not commit local provisioning or change shared bundle IDs to your own.
4. After adding Swift files or changing generated settings, edit `scripts/generate_project.py`, regenerate, and inspect the diff. A second generation must produce no changes. Never fix only the generated project.
5. Run the complete HomePad XCTest/XCUITest suite for meaningful behavior changes. Inspect exported screenshots after layout changes. Record exact toolchain, counts, failures, and limitations in `docs/VALIDATION.md`. Hardware results belong in the separate checklist.
6. Run `git diff --check`. Follow the commit window in AGENTS.md: after 22:00 weekdays or anytime weekends, America/New_York. Run `python3 scripts/commit_guard.py` immediately before committing; never backdate. Optional hook: `git config core.hooksPath .githooks`.
7. Open a focused PR with reproduction and test evidence. AI-assisted contributions receive the same human review and validation requirements as other code.

CI uses one standard public-repository macOS runner, no signing secrets, no paid larger runners, bounded runtime/artifact retention, and cancellation of superseded runs. Fork PRs use `pull_request`, never privileged `pull_request_target`. Live-service checks are manually dispatched. A workflow needing first-time contributor approval may remain pending until a maintainer approves it.

## Reports and review

Use the issue templates. Include device/OS, commit, build configuration, and demo versus real mode; remove personal data from logs and images. Security vulnerabilities belong in [private reporting](SECURITY.md), not public issues. Follow the [code of conduct](CODE_OF_CONDUCT.md).

Maintainers reproduce first, then classify reports with existing `bug`, `enhancement`, `documentation`, `question`, or `help wanted` labels. Use `good first issue` only for bounded work with acceptance criteria and a known test path; do not use it for untriaged hardware failures. The roadmap contains candidates, not invented issue activity. Contributions are under the existing MIT license; preserve third-party notices and media provenance.
