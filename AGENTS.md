# HomeViewPad project rules

This is an independent personal open-source SwiftUI iPad project. Never import employer code, credentials or private services. Use public Apple APIs and original/licensed assets.

Actual Git commits may occur only after 22:00 on weekdays or at any time on weekends in America/New_York. Check the real current time with `python3 scripts/commit_guard.py`. Never fabricate or backdate timestamps. Leave changes uncommitted outside the window. The owner authorizes committing and pushing completed, validated project changes to `https://github.com/kuscholar/HomeViewPad.git` during that same window without asking again. Verify the destination before pushing; never force-push under this standing authorization. Publishing elsewhere or deploying still requires a separately specified destination and authorization.

Keep demo mode visibly labeled and deterministic. Never show demo values as real hardware results. Do not instantiate HMHomeManager in demo mode. Physical HomeKit/HomePod/camera/AirPlay verification is separate from simulator tests.

Run the HomePad scheme's XCTest/XCUITest suite after meaningful behavior changes. Inspect exported screenshots after layout changes. Document tested device/runtime and limitations in docs/VALIDATION.md. The project generator overwrites project settings; preserve intentional changes when regenerating.
