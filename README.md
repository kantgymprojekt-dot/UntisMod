# Untis Mobile – native iOS frontend

This is a native SwiftUI project targeting iOS 16 and later. It is an unofficial Untis client whose look is based on the Untis Mobile Android package **6.8.3 (versionCode 2467)**. It can log in to a school's WebUntis server (JSON-RPC) and also still contains the offline demo week.

## Open and run

1. Open `UntisMobile.xcodeproj` in Xcode 26 or later to compile the native iOS 26 Liquid Glass API. The app deployment target remains iOS 16; earlier iOS versions use an ultra-thin material fallback.
2. Select the `UntisMobile` scheme and an iOS 16+ simulator or device.
3. Set your Apple development team under Signing & Capabilities.
4. Build and run.

No third-party packages are required. Without logging in, the app runs the offline demo week; with a school login it loads the real timetable from WebUntis.

## Source layout

| File | Purpose |
| --- | --- |
| `UntisCloneApp.swift` | App entry point |
| `ContentView.swift` | Main screen, header, menus, date strip, Home and Profile tabs |
| `TimetableGrid.swift` | Timetable grid, pinch-to-zoom, swiping, lesson badges |
| `LessonDetailView.swift` | Lesson detail page (opaque Untis-style page, no system glass sheet) |
| `LoginView.swift` | School search and login |
| `AppModel.swift` | Live Untis state: session, week cache, class selection, JSON-to-entry conversion |
| `UntisAPI.swift` | WebUntis JSON-RPC client and keychain wrapper |
| `Models.swift` | Demo data, edit-code store, calendar helpers, display model |
| `Sheets.swift` | Editor, edit code, date picker, class picker, options, help, info |
| `Theme.swift` | Palette, colour helpers, icons, formatters |

## UI source

Icons (`Assets.xcassets/untis_ic_*`, converted from the 6.8.3 vector drawables to SVG), the app icon (`icon.png` of the xapk), colours, and wording (Home / Timetable / Profile, Go to Date, View, Options, Help, Period info, Log out …) come from the `Untis_6_8_3.xapk` (`resources.arsc`, `res/drawable`, `res/menu`). The bottom bar is a system `TabView` (Liquid Glass on iOS 26, hold-and-drag included).

## Untis login (JSON-RPC)

- The Profile tab (and the first launch) offers **Log in**. Search for the school, then enter the WebUntis user name and password.
- Schools are found through `mobile.webuntis.com/ms/schoolquery2` (`searchSchool`); the session uses `https://<server>/WebUntis/jsonrpc.do?school=<loginName>` with `authenticate`, `getTimegridUnits`, `getKlassen` and `getTimetable`.
- The timetable itself is loaded like the official app does it, from the REST view API (`/WebUntis/api/rest/view/v1/timetable/entries`), which includes teacher names and exam periods. If a school blocks it, the app falls back to the JSON-RPC `getTimetable`.
- The password is stored in the iOS keychain, never in `UserDefaults`. If the Untis session expires, the app signs in again once and retries.
- The title in the timetable header opens the class picker; **My timetable** returns to the logged-in account. If a school does not allow students to call `getKlassen`, the picker shows the server's error and **My timetable** still works.
- Live data is read-only. The edit code, Edit Mode and Reset only apply to the offline demo week.

## Timetable behaviour

- **Swipe** left or right to move by one page: one school day in Day view, the shown number of days in 2/3 Days, one week in Week view. Weekends are skipped. Pull down to refresh.
- **Pinch** to zoom (70 % – 300 %). The zoom level is saved. The menu also has Zoom in / out / Reset.
- **Badges** show, top to bottom, teacher, subject and room. A single period only shows its room once zoomed in (`LessonBlockView.roomZoomThreshold`, 1.3×). Double periods (adjacent identical periods are merged) always show the room.
- **Cancelled** lessons get a red outline, a hatch pattern and strikethrough. **Exams** get a brown/amber outline with the exam icon. **Changes** (substitution, room change) get a green outline with the original value struck through.
- Lessons that run in parallel in the same period are shown side by side.

## What is implemented (original offline prototype)

- A five-day timetable with a period/time rail, date strip, week navigation, and Day / 2 Days / 3 Days / Week views.
- Exactly three bottom tabs: Home, Timetable, and Profile, using original Untis vector icons.
- Local JSON persistence of periods and lessons in `UserDefaults`.
- Add, edit, and delete lesson sheets.
- Normal, cancelled, room-change, substitution, and exam/info lesson states.
- For a cancelled lesson, choose visible strikethrough or hidden. A hidden lesson remains stored and appears as a restorable slot only while Edit Mode is active.
- Original subject, teacher, and room fields for change comparisons.
- Full-device background painting with safe-area-aware content, an iPhone full-screen layout, and iPad full-screen launch configuration.
- Liquid Glass capsules on the floating bottom navigation and top-right information/menu controls on iOS 26+, with a translucent material fallback on iOS 16–25. The timetable cards remain in Untis styling.
- A four-digit local edit code (demo week only). The menu shows **Set code** until a code is saved, then **Enter code**. Correct entry starts Edit Mode automatically.
- Three incorrect attempts trigger a five-minute lockout. Attempt count and lockout expiry are persisted across launches.
- Reset to default restores the sample timetable but does not erase the edit code.
- Local options for cancelled lessons, rooms, and subject colours.

## APK-derived reference material

`Reference/OriginalAPKParts/` contains the exact base and configuration APK splits supplied in this conversation. The base manifest reports package `com.grupet.web.app`, version `6.8.3`, version code `2467`.

`UntisMobile/Assets.xcassets` contains the original Untis vector drawable artwork converted to scalable PDF assets, the current logo images, the timetable widget preview, and widget cancellation illustrations. The original source APKs remain in `Reference` because Android XML drawables, resources.arsc, and DEX bytecode are Android-specific and cannot be compiled directly into an iOS app.

The light/dark palette values in `ContentView.swift` are taken from the APK's `resources.arsc`, including:

- `untis_ui_timetableBackground`: `#F5F5F5` (light) / `#000000` (dark)
- `untis_ui_timetableTimegridBackground`: `#FFFFFF` / `#161616`
- `untis_ui_title`: `#414D55` / `#F3F5F7`
- `untis_ui_orange`: `#FF6033`
- `domain_state_cancellation_bg` / border: `#FFF3F3` / `#DF0047`
- `domain_state_change_bg` / border: `#E4FFF3` / `#00926D`
- `domain_state_exam_bg` / border: `#FFF7D9` / `#9F532D`

The bundled `timetable_widget_preview` is the APK's widget preview. It is not a screenshot of the complete in-app timetable. The active timetable implementation is partly Compose/DEX-backed; this project is a native SwiftUI reconstruction using APK-derived resources and strings, not a byte-for-byte translation of Android runtime code.

## Local storage and code-gate notes

Timetable data is JSON-encoded in `UserDefaults`. The four-digit edit code is not stored as plaintext: a random salt and SHA-256 digest are stored instead. Since a four-digit code has a small search space and the app is an offline frontend, this gate is intended as an editing deterrent, not as high-assurance authentication. The lockout is enforced locally and persists across app launches.

## Fidelity note

This first native build uses verified APK palette values, vector icons, tab labels, timetable terminology, and status colors. Some layout measurements and lesson sample data are reconstructed because the APK's live timetable layout is partly generated by Android/Compose at runtime and the supplied APK package contains a widget preview rather than a full-screen timetable screenshot. A final pixel-level match requires comparison against the live 6.8.3 timetable screen on a device.

## Build verification status

The login, week loading, zoom, swiping and the new badge and detail views were written without access to Xcode, the iOS SDK or the network, so they have **not been compiled or run**, and the Untis calls have not been tried against a real school server. Build the project (Xcode, or the included GitHub Actions workflow) and fix any compiler messages first; the Untis JSON field names (`orgname`, `lstype`, `code`) are the most likely thing to need small adjustments per school.

## Resource selection

The app's asset catalog was generated from the supplied 6.8.3 package's non-night drawable resources and source logo/widget images. It contains the original vector artwork as scalable PDF assets; the app references the current Untis logo, navigation glyphs, menu/edit glyphs, cancellation glyph, exam glyph, and hidden-lesson glyph. The source APK splits and a resource inventory are kept under `Reference/` for auditing. Android-specific files are reference-only and are not added to the iOS target.

## Build an IPA from Windows with GitHub Actions

A ready-to-run workflow is included at `.github/workflows/build-unsigned-ipa.yml`. It uses a GitHub-hosted macOS 26 runner with Xcode to compile a device build and package `Untis-unsigned.ipa`. The IPA must be re-signed before installing on an iPhone. See `docs/WINDOWS_GITHUB_ACTIONS_IPA.md` for the step-by-step Windows instructions. The workflow does not use signing secrets or consume a device sideload slot; installation is a separate step.

Before sideloading, replace the example `PRODUCT_BUNDLE_IDENTIFIER` (`com.example.untismobileclone`) with a unique identifier for your app. Never store Apple ID passwords, signing certificates, or private keys in the repository or workflow.
