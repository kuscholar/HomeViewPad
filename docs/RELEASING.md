# Source releases

## First source preview: v0.1.0

Use a **source preview / prerelease**, not a stable or App Store release. The project had no published tags/releases at the start of the 2026-10-24 audit. The first prerelease uses the validated source plus documentation-only evidence updates. Version 0.1.0 reflects the early scope; hardware limitations remain visible. MARKETING_VERSION is defined in `scripts/generate_project.py` and generated into the project. CURRENT_PROJECT_VERSION remains 1 for this first source release.

## Release checklist

- [ ] Confirm exact candidate commit, clean checkout, destination `kuscholar/HomeViewPad`, and no unrelated changes.
- [ ] Run the real-time commit guard before any commit/tag; never change dates to satisfy the window.
- [ ] Regenerate the project twice and inspect generated settings; preserve ignored local signing.
- [ ] Run the full HomePad scheme on a synthetic-photo simulator and separately run Release weather tests and an unsigned iPad SDK Release build.
- [ ] Inspect any changed layouts; record exact results and failures in VALIDATION.md. Link the actual remote CI run for the candidate commit, never infer CI from local success.
- [ ] Review privacy-sensitive code, entitlements, permissions, attribution, and tracked files for credentials or personal content.
- [ ] Reconcile CHANGELOG and both README languages with actual capabilities and hardware evidence.
- [ ] Create a draft release for the exact candidate SHA if any release gate remains unresolved. Set prerelease; attach no personal artifacts, signing assets, or purported installable binary.
- [ ] Publish only when authorized and the candidate's required checks pass. Never move an existing tag to hide a failure. A later fix gets a new version.

Documentation-only follow-ups need not repeat unchanged app tests; cite the tested source and actual CI scope. An optional live-service failure must be disclosed; it must not be relabeled as a passing full suite. Hardware gaps may remain for a clearly labeled source preview, but never for a claim of certified device behavior.

## Build a source archive

Download the source archive for the tag from GitHub Releases or clone and check out that tag. Open HomePad.xcodeproj with the HomePad scheme and an iPad simulator; launch with `--demo`. There are no package dependencies or distributed signing credentials. See CONTRIBUTING.md for reproducible tests. Real iPad installation requires your own bundle ID/team; WeatherKit in Release also requires the appropriate Apple account capabilities and provisioning, as documented in README.md.

## Release-note template

State the exact commit and source-only preview status, user-visible features, actual tested configurations/counts, remote CI URL, installation instructions, and unresolved hardware/service/OS limitations. Link CHANGELOG, VALIDATION and HARDWARE_CHECKLIST. Do not label an unsigned build as an installable IPA, or advertise download/user counts that were not measured.
