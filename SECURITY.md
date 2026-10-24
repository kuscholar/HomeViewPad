# Security and privacy

## Reporting a vulnerability

Please use [GitHub private vulnerability reporting](https://github.com/kuscholar/HomeViewPad/security/advisories/new). Include the affected commit/build, reproduction using a test home or synthetic data, expected versus actual behavior, and possible impact. Do not include signing keys, tokens, personal photographs, home identifiers, or live camera footage. Do not post exploitable details publicly while a report is being assessed. If private reporting is unavailable, open an issue asking for a private contact without disclosing vulnerability details.

The project is maintained by a volunteer. There is no guaranteed response time or paid security support. The current main branch is the supported development line; early previews have no long-term support or security certification. A confirmed fix should include a focused regression test and a sanitized advisory/release note when appropriate.

## Review boundaries

HomeKit commands can affect a real home. Validate control changes against advertised write permissions, bounds, reachability, read-back, and stale-callback cancellation. Existing scenes can include actions the app does not directly edit; retain explicit confirmation. Never use demo fixtures to mask a live error.

Review permission denial/revocation and foreground transitions for HomeKit, Photos, location, EventKit, microphone, camera, and audio. Home data stays with HomeKit; selected preferences and imported photos remain local. Imported photos may be included in ordinary device backups. Shared-screen content can be seen by anyone nearby. See [data lifecycle](docs/ARCHITECTURE.md).

Release weather uses Apple services. Debug can send approximate coordinates and city searches to Open-Meteo; it is not a fully offline app. Standby processes temporary sound/face/depth data on device and must not save or transmit it. There is no app-owned backend, analytics SDK, or credential store.

CI must not receive personal signing material or home data. Use fresh simulators and synthetic images; review artifacts before publication. Keep action dependencies pinned, workflow permissions read-only, and untrusted PR execution separate from privileged operations. A source review or passing simulator suite is not a penetration test, hardware safety certification, or proof of sensor teardown timing.
