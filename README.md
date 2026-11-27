# Untis — native iOS frontend

This is a native SwiftUI project targeting iOS 16 and later. Its visual resources come from the uploaded `Untis 6.8.3.xapk` (package `com.grupet.web.app`, version code `2467`). The project includes `UntisAPI.swift`, a native transport layer for the WebUntis endpoint and JSON-RPC method names identified in that XAPK.

## Open and run

1. Open `UntisMobile.xcodeproj` in Xcode 26 or later.
2. Select the `UntisMobile` scheme and an iOS 16+ simulator or device.
3. Set your Apple development team under Signing & Capabilities.
4. Build and run.

The app display name is `Untis`. No third-party packages are required. The API transport source is included in the Xcode target, but the school-search/login screens and authenticated timetable synchronization are not yet wired to it; this package must not be treated as a finished connected WebUntis client.

## Changes in this revision

- Restored the first three-dot-menu action: `Set code` before a code is saved, then `Enter code` afterward.
- Removed the class chooser interaction; `08B` is now a static class label.
- The timetable menu contains no Refresh or Zoom buttons. Pinch-to-zoom remains available directly on the timetable.
- Added animated horizontal paging: swipe left/right to move forward/backward, using a sliding transition.
- Only the real current day/date is orange. Other day/date labels remain white in dark appearance.
- Normal lesson cards use the XAPK-style slate surface. Cancelled, room-change/substitution, and exam cards use their own status fills.
- Teacher abbreviation/name text uses a higher-contrast secondary text colour and is always rendered; an empty replacement-teacher field falls back to the original teacher, and shows an em dash only if both are empty.
- Exam cards always display the exam/info label and an info line; an empty info field gets a visible fallback. The default sample week includes an exam in the Thursday timetable as a visual test case.
- The AppIcon and in-app logos are refreshed from the current XAPK's `icon.png` and `mipmap` launcher assets. Exam cards use a compact layout so the status, teacher, room, and a one-line info hint fit inside the period row.
- Preserved native iOS 26 Liquid Glass with the interactive press response on the bottom navigation capsule, plus the iOS 16–25 material fallback.
- Exactly three bottom tabs remain: Home, Timetable, and Profile.

## Existing functionality retained

- Five-day local timetable with a period/time rail and Day / 2 Days / 3 Days / Week views.
- JSON-encoded timetable persistence in `UserDefaults`.
- Add, edit, and delete lesson sheets.
- Normal, cancelled, room-change, substitution, and exam/info lesson states.
- For cancelled lessons, choose visible strikethrough or hidden. Hidden lessons remain stored and can be restored in Edit Mode.
- Original subject, teacher, and room fields for change comparisons.
- Four-digit local edit code; three incorrect attempts trigger a five-minute lockout. Code hash, salt, attempt count, and lockout expiry are saved locally.
- Reset to default restores the sample timetable but does not erase the edit code.

## WebUntis API transport included

`UntisMobile/UntisAPI.swift` is included in the Xcode project and Sources build phase. It contains school-search, login-metadata, JSON-RPC transport, and method wrappers for `getAuthToken`, `getUserData2017`, `getTimetable2017`, `getPeriodData2017`, and `getExams2017`, using endpoint and method names observed in the supplied XAPK. It deliberately does not guess the undocumented authentication payload, credential hashing/OTP handshake, response DTO mappings, or session lifecycle. The current SwiftUI screens do not yet invoke this API client. Before using real school credentials, the login and token flow must be completed and tested against the intended school server. Credentials must not be placed in UserDefaults or GitHub Actions logs.

## XAPK-only visual source

`UntisMobile/Assets.xcassets` uses artwork, logo variants, and icon resources extracted from the uploaded `Untis 6.8.3.xapk`. `Reference/OriginalAPKParts/`, `Reference/XAPK_Manifest.json`, `Reference/ResourceInventory.json`, and `Reference/SHA256SUMS.txt` preserve the uploaded XAPK's split APKs and provenance.

The separately uploaded `Untis-unsigned-IPA(1).zip` contains only a compiled `Untis-unsigned.ipa` and build-info text. It contains no editable SwiftUI source and has not been used as a visual-resource source. This project is rebuilt from the prior SwiftUI source project, with the current XAPK as its only visual reference.

The XAPK package reports:
- Package: `com.grupet.web.app`
- App name: `Untis`
- Version: `6.8.3`
- Version code: `2467`

The XAPK base APK's SHA-256 is recorded in `Reference/SHA256SUMS.txt`. Its UI includes Android XML and Compose-generated/runtime layouts; Android code cannot be copied directly into SwiftUI. The app is a native SwiftUI recreation using the XAPK's current resource assets and layout references. The XAPK does not bundle an individual school's live teacher roster or personal timetable; because this frontend has no backend, the built-in week uses sample teacher abbreviations, and any teacher values stored in the local lesson are now shown with a high-contrast style.

## Build an IPA from Windows with GitHub Actions

A GitHub Actions workflow is included at `.github/workflows/build-unsigned-ipa.yml`. It uses a GitHub-hosted macOS runner with Xcode to compile a device build and package `Untis-unsigned.ipa`. The IPA must be re-signed before installing on an iPhone. See `docs/WINDOWS_GITHUB_ACTIONS_IPA.md` for Windows instructions.
