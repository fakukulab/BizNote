# BizNote Submission Handoff

Use this when archiving and submitting BizNote from a Mac with a non-beta Xcode installation.

## Required Local Setup

- Use current stable Xcode, not `/Applications/Xcode-beta.app`.
- Sign in to Xcode with the Apple Developer account for Team ID `8S2Y83DCGM`.
- Open `BizNote.xcodeproj`.
- Select the `BizNote` scheme.
- Confirm the target bundle identifier is `com.fakuku.biznote`.
- Confirm signing is Automatic and Team is `8S2Y83DCGM`.

## Apple Developer Portal Checks

- App ID `com.fakuku.biznote` exists.
- iCloud capability is enabled for the App ID.
- CloudKit container `iCloud.com.fakuku.biznote` exists.
- The CloudKit container is attached to the App ID.
- CloudKit schema needed by SwiftData has been deployed to Production before review, if the app has already created schema in Development.

## App Store Connect Values

Use `docs/app-store-connect.md` for the App Store Connect listing text, review notes, privacy answers, keywords, and screenshot checklist.

Recommended initial values:

- Version: `1.0`
- Build: `1`
- Category: Business
- Secondary category: Productivity
- Price: Free
- Sign-in required: No
- Encryption: Uses only standard Apple platform encryption, no non-exempt custom encryption
- Tracking: No

## Validation Before Archive

Run these from the repository root on the submission Mac:

```sh
xcodebuild -project BizNote.xcodeproj -scheme BizNote -configuration Release -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

Then in Xcode:

1. Select `Any iOS Device`.
2. Run `Product > Clean Build Folder`.
3. Run `Product > Archive`.
4. In Organizer, validate the archive before upload.
5. Upload to App Store Connect.

## Manual QA Pass

Before upload, install a Release build on a real device and check:

- App launches cleanly on a fresh install.
- Create, edit, favorite, search, and delete notes.
- Create each built-in note type: work log, meeting minutes, exhibition.
- Create a custom category and custom note template.
- Scan or import a business card image and confirm OCR result can be saved.
- Contacts permission denial and approval flows do not block the app.
- Current-location insertion works after location permission approval.
- Calendar sync works only after enabling the integration.
- Reminder sync works only after enabling the integration.
- Export opens the system share sheet.
- iCloud sync setting is visible and does not crash on launch.

## Known State From This Mac

- Xcode MCP Debug build succeeded.
- App icon is `1024x1024` and has no alpha channel.
- `PrivacyInfo.xcprivacy` is included as a target resource.
- `PrivacyInfo.xcprivacy` declares no tracking and the UserDefaults required reason API reason `CA92.1`.
- Local Release `xcodebuild` on this Mac failed because the installed Xcode beta could not load SwiftUI/SwiftData macro implementations. Treat that as an environment issue unless the stable-Xcode build reproduces it.

## Do Not Regenerate Carelessly

`project.yml` is now aligned with the current submission settings. If using XcodeGen on the submission Mac, regenerate only after confirming these values remain:

- `PRODUCT_BUNDLE_IDENTIFIER: com.fakuku.biznote`
- `DEVELOPMENT_TEAM: 8S2Y83DCGM`
- `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`
- `PrivacyInfo.xcprivacy` is included in resources
- All permission usage descriptions are present in `BizNote/Info.plist`
