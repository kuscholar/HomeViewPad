# Physical hardware validation — NOT YET VERIFIED

Simulator success does not establish any of the following. Use an iPad and a HomePod mini owned by you, with a disposable/test accessory where practical.

- [ ] Select a personal signing team and unique bundle identifier. Confirm HomeKit entitlement provisioning succeeds, install on iPad, and launch without signing warnings.
- [ ] Deny Home permission; verify denied state and Settings recovery. Grant, return, retry, and verify the correct home's actual accessories appear.
- [ ] Check multiple homes and home selection. Revoke permission while suspended and verify no stale controls or personal data remain visible on return.
- [ ] Switch a test light on/off repeatedly; compare physical state and the Apple Home app. Disconnect accessory power/Wi-Fi and confirm offline status; restore and retry.
- [ ] Adjust supported brightness, thermostat target temperature and fan speed within device-advertised bounds; verify the device and Apple Home agree. Test rejected writes, missing metadata and write-success/read-back-failure.
- [ ] Read temperature/humidity and compare with Apple Home. Validate units and service names for each vendor.
- [ ] Inspect a harmless scene in Apple Home, cancel its HomeViewPad confirmation, then run it. Verify every physical effect and completion/error reporting. Check scene rejection from a restricted shared-home account.
- [ ] Open a supported HomeKit camera, confirm video, close, reopen, background, and return. Confirm no background stream remains. Test unavailable/offline camera and retry. Verify that opening a HomeKit camera does not transmit audio or itself request microphone permission (standby has a separate opt-in permission).
- [ ] Configure HomePod mini in Apple Home; verify hub status and supported Thread routing independently. Do not credit HomeViewPad with those functions.
- [ ] Choose a downloaded audio file, select HomePod mini via AirPlay, play/pause, interrupt, and change routes. Validate codec failure and lost-speaker behavior. Test selecting and dismissing Files repeatedly.
- [ ] Grant full and limited Photos access; select a named album/Allowed photos, verify rotation and pause behavior, change the allowed set, delete the selected album/photo in Photos, and revoke access in Settings while suspended. Check no old image returns; test iCloud download failure/retry and library edits.
- [ ] Pick a large/iCloud photo, cancel the picker, replace it, relaunch, and remove it. Confirm removal after relaunch and inspect storage growth.
- [ ] Confirm first launch opens Overview. Deny/allow approximate location, verify Philadelphia fallback/current city, manually select a different city, revoke location in Settings, and verify recovery. Check current model weather, °C/°F, offline/stale labeling and foreground refresh on the physical iPad.
- [ ] Deny and grant calendar/reminder permissions separately. Test empty stores, all-day events, time-zone changes, duplicate titles, and revocation. Confirm shared-display opt-in and hiding when disabled.
- [ ] Verify thermostat up/down arrows against the actual target temperature and advertised step/range; confirm read-back, bound/offline/busy disabling, and no write from read-only sensors or vertical swipes.
- [ ] Test near/far, portrait/landscape, split view, largest Dynamic Type, VoiceOver, Voice Control, external keyboard, Reduce Motion and increased contrast. Verify touch targets and text remain usable.
- [ ] Enable foreground-awake; verify it resets on leaving HomeViewPad. Validate Guided Access manually if wanted. Observe long-running heat, power, OLED/LCD wear considerations, charging and mounting under actual conditions.

No physical-device, HomePod, camera, AirPlay, EventKit-permission, or long-duration hardware validation is claimed by the simulator suite.

## Foreground standby — physical wake validation in progress

On 2026-10-15, the owner's iPad Pro 11-inch (iPadOS 26.6) showed its dashboard after idle expiry, an orange microphone indicator, and the input-confirmed “Microphone active” status. End-to-end face/sound wake, physical brightness restoration and power measurements remain unverified; keep the checklist below open until those observations are recorded.

- [ ] In Sound mode, allow brief quiet calibration, then try normal speech and a short clap at several distances. Confirm actual brightness restoration and a “Sound detected” result. Compare Low/Standard/High sensitivity and false wakes with steady fans, TV and intermittent household noise. Use optional input/trigger levels when a sound is missed; microphone indication alone is not successful-wake evidence.

- [ ] Check default-off behavior and the independent Keep screen awake option. Enable standby, wait each idle delay, verify the dashboard remains visible at minimum brightness, then touch once: original brightness returns and no underlying HomeKit action fires. Leave the app, disable standby, lock manually and return; verify brightness restoration and sensor shutdown. A manual lock must still require normal system authentication.
- [ ] Deny/grant/revoke microphone and camera permissions independently. Unsupported TrueDepth must never use a regular front/rear camera. Sound-only mode must never activate the camera. Confirm microphone indicator while listening and camera indicator only during a short check. Demo must request neither permission and activate neither sensor.
- [ ] Test sound calibration in quiet/noisy rooms, with TV, speech, footsteps and silent arrivals. Measure false wakes/misses. Check TrueDepth face/depth alignment in all four orientations, close/far distances, glasses, varied lighting and a dark room. The nominal 0.2–2 m gate is not a verified detection range.
- [ ] Time capture startup/shutdown on success, no face, timeout, repeated sound, backgrounding and interruption. Verify the three-second cancellation request and 15-second failed-check cooldown. Confirm old callbacks cannot wake or restart capture after cancellation.
- [ ] Test playback/AirPlay, incoming audio interruptions, headphone/Bluetooth route changes, and permission prompts. Confirm standby pauses during app playback, audio-session settings recover, and input failures restore brightness and show an error instead of leaving a dimmed display.
- [ ] Compare at least 30 minutes of idle display, sound-only and sound + TrueDepth standby: power, warmth, brightness stability, LCD glow/OLED behavior and privacy indicators. Do not claim true display-off or energy savings without measurements.
