# BizNote

BizNote is an iPhone and iPad SwiftUI app for business notes and business card management: work logs, meeting minutes, event notes, custom note templates, and scanned business card records.

- Bundle ID: `com.fakuku.biznote`
- CloudKit container: `iCloud.com.fakuku.biznote`
- Team ID: `8S2Y83DCGM`
- Minimum iOS: 17.0 (iPhone and iPad)
- Xcode: 27+

## Project

- App source: `BizNote/`
- Xcode project: `BizNote.xcodeproj`
- XcodeGen config: `project.yml`
- Tests: `BizNoteTests/`
- Website and App Store notes: `docs/`

Source layout inside `BizNote/`:

- `Models/` – SwiftData models (notes, business cards, categories, templates, event data)
- `Services/` – OCR, business card parsing, Contacts / Calendar / Reminders sync, Excel export, iCloud settings
- `Views/` – SwiftUI views
- `Utilities/` – shared helpers
- `Resources/` – localized strings and assets

## Build

```sh
xcodebuild -project BizNote.xcodeproj \
    -scheme BizNote \
    -destination 'generic/platform=iOS' \
    -configuration Debug \
    build
```

CloudKit features require signing with the Apple Developer team listed above.

## Docs

`docs/` holds the GitHub Pages (Jekyll) site files and App Store submission notes:

- `docs/index.md`, `docs/support.md`, `docs/privacy-policy.md` – website pages
- `docs/app-store-connect.md`, `docs/app-review-notes.md`, `docs/submission-handoff.md` – App Store Connect metadata and review notes

Release notes are kept at the repository root as `ReleaseNotes-*.md`.

## Notes

- Signing certificates and provisioning profiles (`*.cer`, `*.mobileprovision`, `*.certSigningRequest`) must not be committed. Keep them outside this repository.
- BizNote does not require login. It shows non-personalized Google AdMob ads and does not use ad personalization.
