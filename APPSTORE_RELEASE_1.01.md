# BizNote App Store Release 1.01

## Release State

| Item | Value |
| --- | --- |
| App | BizNote |
| Bundle ID | `com.fakuku.biznote` |
| Marketing version | `1.01` |
| Build number | `2` |
| Development team | `8S2Y83DCGM` |
| Signing | Automatic |
| Platforms | iPhone, iPad |
| Minimum iOS | iOS 17.0 |

## Included Changes

- Settings > Apple app integration is localized as `Apple App Sync` in English.
- Apple App Sync detail strings are localized in English.
- Korean strings are unchanged.
- Settings > Version displays `1.01`.
- `InfoPlist.xcstrings` includes English purpose strings for permission prompts.

## Release Notes

Korean:

```text
버그 수정 및 영어 표시 문구를 개선했습니다.
```

English:

```text
Bug fixes and English localization improvements.
```

## Move To Release Mac

Use a Mac with a public, non-beta Xcode release that supports the target SDK required for App Store submission.

Transfer the full project folder or push/pull the repository. On the release Mac, confirm these files are present:

- `BizNote/Info.plist`
- `BizNote/Resources/Localizable.xcstrings`
- `BizNote/Resources/InfoPlist.xcstrings`
- `BizNote/Views/Settings/SettingsView.swift`
- `BizNote.xcodeproj`

## Xcode Archive And Upload

1. Open `BizNote.xcodeproj` in the public release version of Xcode.
2. Select the `BizNote` scheme.
3. Select `Any iOS Device` or a generic iOS device destination.
4. Confirm Signing & Capabilities uses team `8S2Y83DCGM`.
5. Confirm Version is `1.01` and Build is `2`.
6. Choose `Product > Archive`.
7. In Organizer, select the new archive.
8. Click `Validate App` and fix any validation errors.
9. Click `Distribute App`.
10. Select `TestFlight & App Store` or `App Store Connect`, depending on the Xcode UI.
11. Keep automatic signing enabled.
12. Upload with symbols enabled.
13. Wait until App Store Connect finishes processing build `2`.

## App Store Connect Submission

1. Open App Store Connect.
2. Select BizNote.
3. Create a new iOS version `1.01` if it does not already exist.
4. Select uploaded build `2`.
5. Add the release notes above for Korean and English locales.
6. Review App Privacy answers before submission. The app requests access to camera, contacts, calendar, reminders, location, and photo library, so the privacy questionnaire must match the app's actual data use.
7. Confirm export compliance. `ITSAppUsesNonExemptEncryption` is set to `false`.
8. Submit for App Review.

## Local Validation Completed

- Debug build succeeded on this Mac after the release changes.
- English app UI strings requested for Apple App Sync are translated.
- English Info.plist permission strings are translated.

## Notes

- Do not upload an archive built with beta Xcode for App Store review.
- If App Store Connect rejects build `2` because it already exists, increment the build number to `3`, archive again, and upload that build under version `1.01`.
