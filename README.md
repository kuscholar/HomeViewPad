<p align="center">
  <img src="docs/media/homeviewpad-logo.png" width="128" height="128" alt="HomeViewPad — a glass window into your home">
</p>
<h1 align="center">HomeViewPad</h1>
<p align="center"><strong>We have HomeView at home.</strong><br>An iPad. A HomePod mini. A little rearranging.</p>
<p align="center">
  <img src="https://img.shields.io/badge/iPadOS-17%2B-145C50?style=flat-square" alt="iPadOS 17 or later">
  <img src="https://img.shields.io/badge/Built_with-SwiftUI-145C50?style=flat-square" alt="Built with SwiftUI">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-D6A64D?style=flat-square" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/Status-Early_preview-D6A64D?style=flat-square" alt="Early preview">
</p>
<p align="center">
  <a href="docs/README.zh-CN.md">简体中文</a> · <a href="#the-demo">Watch the demo</a> · <a href="#get-started">Build it</a> · <a href="docs/ARCHITECTURE.md">Privacy</a>
</p>

---

## Before you buy another screen, check the drawer.

[Apple HomeView](https://www.apple.com/apple-homeview/) brings a screen, speakers, and home controls together. We looked around the living room and thought: **hang on, we own most of those nouns.**

HomeViewPad gives a spare iPad a new job: a beautiful Apple Home dashboard, a clock you can read across the room, and a photo frame that finally does something with your albums. Put a HomePod mini beside it—or give them a shared stand—and you've got your own little smart-home corner.

**Some assembly required. Keynote sold separately.**

<p align="center">
  <img src="docs/media/ipad-homepod-use-case.png" width="960" alt="An iPad running HomeViewPad next to a HomePod mini on a sideboard">
  <br><sub>AI-generated setup illustration using an actual app screenshot. Demo data shown.</sub>
</p>

### The highly sophisticated bill of materials

| The part | Its new job |
| :--- | :--- |
| **An iPad you already have** | The screen, the touch controls, and the photo frame. iPadOS 17+. |
| **HomeViewPad** | Glass widgets, Apple Home controls, clocks, and your albums. Native SwiftUI, MIT licensed. |
| **A HomePod mini, if you have one** | Siri, supported home-hub functions, and a speaker—through Apple's own features. |
| **A stand and a power outlet** | The industrial design department. |

The iPad runs the app. HomePod mini works independently in your Apple Home setup; it isn't directly paired with HomeViewPad. This covers everyday dashboard jobs, **not every HomeView feature**: no built-in Siri AI, household recognition, integrated FaceTime, or Intercom. Those distinctions are real, even if the stand is homemade.

## The demo

<p align="center">
  <img src="docs/media/demo.gif" width="880" alt="HomeViewPad in action: thermostat arrows, lights, widget stacks, clock, and a three-photo slideshow">
  <br><sub>Actual iPad simulator recording · Demo accessories · Owner-supplied photos · About 15 seconds</sub>
</p>

Temperature up. Lights off. A different widget. Then your photos get the whole screen.

A 15-second edit of a fresh simulator recording, with faster playback and the long slideshow waits cut out. All three supplied photos appear; the app itself still rotates albums every 30 seconds. It demonstrates the running interface; real HomeKit and HomePod behavior require separate hardware checks. [Recording details →](docs/MEDIA.md)

## A useful screen, even when nobody is tapping it

| **A home at a glance** | **Your photos deserve a bigger audience** |
| :--- | :--- |
| A large climate tile, five smaller widgets, and soft glass over warm gray or teal. Headers and navigation stay tucked away. | Choose an album or a single photo. The photo wall adds a large clock and gentle crossfades. Your camera roll finally gets a living-room residency. |
| **Controls with a purpose** | **A little less interface** |
| Select a home, filter rooms, control supported accessories, and confirm before running a scene. Thermostat arrows follow the device's supported steps and limits. | Swipe between pages and through distinct widget stacks. Position dots appear during switching, then get out of the way. |

Prefer lights out? **Overview** puts just four square widgets on pure black: date, a numbered analog clock, your album, and weather. White type, yellow accents, no glass. It is now the first page. Live weather comes from [Open-Meteo](https://open-meteo.com/): Philadelphia by default, your city after Apple Location Services permission, or a city you choose. Tap weather to search, refresh, or switch °C/°F. Demo weather stays fixed and labeled.

Also included: optional HomeKit camera viewing, opt-in calendar and reminders, local audio playback with the system AirPlay picker, and foreground screen-awake mode. Experimental **Standby and wake** keeps the app unlocked, keeps the dashboard visible at minimum screen brightness, and restores brightness on touch or sound. Sound directly wakes the display by default, with adjustable sensitivity. Optional TrueDepth requires a nearby face after sound; the camera stays off between checks. Demo mode works without accessories and never initializes the real HomeKit manager.

### A few gestures. That's the manual.

| Do this | Get this |
| :--- | :--- |
| Swipe **left / right** | Overview → Home → Clock → Photos → Settings |
| Swipe **up / down inside a widget** | That widget's next or previous item |
| Tap **empty wallpaper** or the photo wall | Navigation: right side in landscape, bottom in portrait |
| Tap **temperature arrows** | Adjust a supported, writable thermostat target |

Animations respect Reduce Motion. Each widget stack has its own content; your light switch doesn't turn into a second clock.

## Get started

**Bring Xcode. The app isn't on the App Store yet.**

```sh
git clone https://github.com/kuscholar/HomeViewPad.git
cd HomeViewPad
open HomePad.xcodeproj
```

Choose the **HomePad** scheme and an iPad simulator running iPadOS 17 or later. Build, run, swipe left to **Home**, and tap **Explore demo**. No third-party packages or home accessories required.

<details>
<summary><strong>Put it on your own iPad</strong></summary>

1. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`.
2. Enter your own unique bundle identifier and development team. The local file is ignored by Git.
3. Connect your iPad and build with the **HomePad** scheme. Your account must support HomeKit provisioning; complete Apple's trust and Developer Mode prompts as needed.
4. Swipe left to **Home**, tap **Connect Apple Home**, grant access, and choose your home. Set up accessories and scenes in Apple's Home app first.
5. Open the photo widget to choose one photo or connect an album. Limited Photos permission displays only your allowed images.

HomePod mini is optional. Add it to your home using Apple's Home app; select it in the system AirPlay picker when playing a local audio file. For Apple Music, use Apple's Music app and its system audio routing.

The display name is **HomeViewPad**; the project, scheme, and source directory retain their original **HomePad** names. Photos rotate every 30 seconds while Home, Overview, or the photo wall is visible, and pause while a panel is open or the app is inactive.

</details>

## Your home doesn't need another account

No app account, app-owned backend, analytics, or tracking SDK. HomeKit, PhotoKit, EventKit, and AirPlay use public Apple APIs and system permissions. Calendar and reminders stay hidden until you opt in.

Weather sends city searches and coordinates to Open-Meteo. Automatic location uses Apple's foreground permission and city lookup; weather coordinates are rounded to about 1 km and automatically detected coordinates are not saved to disk. Manual city and unit choices are saved locally. Offline readings are labeled as cached. The free weather endpoint is for personal/non-commercial use; a commercial release needs a suitable [Open-Meteo plan](https://open-meteo.com/en/pricing) or another licensed provider.

Album photos are loaded on demand; iCloud may download them through PhotoKit. A single imported photo is stored in the app sandbox. The app never edits your Photos library. **A shared screen is still a shared screen:** anyone nearby can see the content you choose to display. [Data lifecycle →](docs/ARCHITECTURE.md)

<details>
<summary><strong>The small print, in normal-sized words</strong></summary>

This is an early independent project, not an Apple product or a complete HomeView replacement. HomeViewPad is not a home hub and cannot access a HomePod microphone, host Siri, send Intercom messages, or embed FaceTime.

It does not create automations or directly edit locks, blinds, or thermostat modes. Existing scenes can contain those actions, so scene execution always asks for confirmation. There is no Apple Music catalog integration or background camera recording. Standby is opt-in under Settings → Standby and wake. It cannot unlock iPad or reopen the app. Enabling standby requests the needed permissions. Missing permissions or microphone failures keep or restore normal brightness and show the reason. The microphone runs while dimmed; TrueDepth checks use the front image and depth for up to three seconds, with system privacy indicators. Quiet arrivals can be missed, and real-device detection, power use, and dark-room performance remain unverified. Devices without TrueDepth can use Sound or touch; there is no regular-camera fallback.

Simulator tests cover app logic and interface flows. Real accessory compatibility, camera streaming, AirPlay, and long-running wall-display behavior still require [hardware validation](docs/HARDWARE_CHECKLIST.md). [What we've actually tested →](docs/VALIDATION.md)

</details>

## Make it yours

Bug reports and focused improvements are welcome. Include your iPad model, iPadOS version, reproduction steps, and whether you're using demo mode or a real home. Remove personal photos, home identifiers, and signing information from reports.

<details>
<summary><strong>Build, test, and record a demo</strong></summary>

Requires macOS and Xcode with an installed iPadOS simulator runtime. See [validated toolchains](docs/VALIDATION.md).

```sh
xcrun simctl list devices available
python3 scripts/seed_test_photos.py SIMULATOR_UUID
sh scripts/test.sh SIMULATOR_UUID
python3 scripts/record_demo.py SIMULATOR_UUID
```

Use a dedicated simulator containing only approved recording photos; synthetic fixtures are available for routine tests. Raw videos, logs, and results stay in ignored `.validation/`.

Regenerate the project with `python3 scripts/generate_project.py` after adding source files. This overwrites generated settings but preserves the separate, ignored `Config/Local.xcconfig`. Keep personal signing overrides there.

Launch arguments: `--demo`, `--state denied|empty|offline|loading`, `--far`, and `--fresh`. `--state` applies only in demo mode.

Follow [AGENTS.md](AGENTS.md): public APIs, original or licensed assets, no employer code or private services. Actual commits are restricted to after 22:00 on weekdays or anytime on weekends in America/New_York. Check with `python3 scripts/commit_guard.py`; never alter timestamps. Enable the optional hook with `git config core.hooksPath .githooks`.

</details>

---

<p align="center"><strong>Give that iPad a room with a view.</strong><br><sub>Built with SwiftUI, spare hardware, and a healthy respect for a good stand.</sub></p>

[MIT license](LICENSE) · [Architecture](docs/ARCHITECTURE.md) · [Validation](docs/VALIDATION.md) · [Media credits](docs/MEDIA.md)

Apple, Apple HomeView, iPad, HomePod mini, HomeKit, and AirPlay belong to Apple Inc. HomeViewPad is an independent project, not affiliated with or endorsed by Apple or other similarly named products. The DIY comparison describes overlapping use cases, not feature parity.
