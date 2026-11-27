# Applying this Untis patch on Windows

Extract this ZIP directly into the root of your existing GitHub repository and choose **overwrite/replace** when Windows asks. The archive's `UntisMobile/` directory is already at the ZIP root.

Keep your existing `.github/`, `UntisMobile.xcodeproj/`, and `docs/` folders.

Then use GitHub Desktop to commit and push. A push to `main` triggers the existing GitHub Actions IPA workflow.

Files included:
- `UntisMobile/ContentView.swift` — Set code / Enter code menu, swipe animations, pinch zoom, teacher and exam rendering, today-only orange dates, interactive Liquid Glass.
- `UntisMobile/Models.swift` — sample timetable exams and local passcode/timetable persistence.
- `UntisMobile/Assets.xcassets/AppIcon.appiconset/` — app icon from the uploaded `Untis 6.8.3.xapk` manifest `icon.png`.
- `UntisMobile/Assets.xcassets/untis_logo.imageset/` and `untis_logo_round.imageset/` — logos from that XAPK.
- `README.md` — current revision notes and source provenance.

The uploaded `Untis-unsigned-IPA(1).zip` contains a compiled app artifact, not editable SwiftUI source. These source changes must be rebuilt by GitHub Actions to create a new IPA.
