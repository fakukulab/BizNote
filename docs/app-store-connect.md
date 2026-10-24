# BizNote App Store Connect Information

## App Information

App Name: BizNote

Platform: iOS

Bundle ID: com.fakuku.biznote

SKU: biznote-ios

Primary Category: Business

Secondary Category: Productivity

Price: Free

Age Rating: 4+

## URLs

Privacy Policy URL: https://fakukulab.github.io/BizNote/privacy-policy/

Support URL: https://fakukulab.github.io/BizNote/support/

Marketing URL: https://fakukulab.github.io/BizNote/

## Subtitle

Business notes and card scanner

## Promotional Text

Create business notes, scan business cards, organize meetings and events, and export your work from one simple app.

## Description

BizNote helps you manage business notes, meeting minutes, event notes, work logs, and business card information in one place.

Create notes by type, customize note templates, scan business cards with on-device OCR, and keep important contact details organized. You can also record meeting locations, manage event information, attach images, and export supported data through the system share sheet.

BizNote does not require an account and shows non-personalized ads. Data is stored on your device, and iCloud sync is available through your personal iCloud account when enabled.

## Keywords

business note,meeting,minutes,work log,business card,OCR,contact,scanner,event,note,productivity,iCloud,export,PDF,CSV

## What's New

Initial release.

## Copyright

2026 Fakuku Lab

## App Review Information

Sign-in required: No

Test account required: No

Notes for reviewer:

BizNote is an iOS and iPadOS business note app. All core features are available without signing in.

The reviewer can create notes from the note list, choose a note type, scan or import a business card image, review OCR results, save business card information, optionally save it to Contacts, use location input for meeting or event notes, review iCloud/Calendar/Reminders settings, and export supported data through the system share sheet.

The app contains ads from Google AdMob (non-personalized; an App Tracking Transparency prompt is shown at launch). It does not contain other analytics SDKs, tracking SDKs, subscriptions, in-app purchases, or external payment.

User data is stored on the device. If iCloud sync is enabled, data may sync through the user's personal iCloud account using Apple's CloudKit service. The developer does not operate a separate server for collecting user data from the app.

## App Privacy Answers

Source of truth: the privacy manifest that ships inside the Google Mobile Ads SDK (`GoogleMobileAds.framework/PrivacyInfo.xcprivacy`) and Google's data disclosure guide (https://developers.google.com/admob/ios/privacy/data-disclosure). The app's own `PrivacyInfo.xcprivacy` mirrors it. Re-check both whenever the SDK is updated.

Do you or your third-party partners collect data from this app? **Yes** (collected only by the Google Mobile Ads SDK; the developer collects nothing on a server).

| Data type (App Store Connect) | Linked to user | Used to track | Purposes |
|---|---|---|---|
| Identifiers > Device ID | Yes | **Yes** | Third-Party Advertising, Developer's Advertising or Marketing, Analytics |
| Usage Data > Advertising Data | Yes | No | Third-Party Advertising, Developer's Advertising or Marketing, Analytics |
| Usage Data > Product Interaction | Yes | No | Third-Party Advertising, Developer's Advertising or Marketing, Analytics |
| Location > Coarse Location | Yes | No | Third-Party Advertising, Developer's Advertising or Marketing, Analytics |
| Diagnostics > Performance Data | No | No | Third-Party Advertising, Developer's Advertising or Marketing, Analytics |
| Diagnostics > Crash Data | No | No | Analytics |
| Diagnostics > Other Diagnostic Data | No | No | Third-Party Advertising, Developer's Advertising or Marketing, Analytics |

Notes:

- Ads are requested as non-personalized, but the Device ID is declared as used for tracking because that is how the SDK declares it. The app therefore shows the App Tracking Transparency prompt (`NSUserTrackingUsageDescription`) before starting the SDK, and every feature works whether the user allows or denies it.
- Notes, business cards, scanned images, attachments, and Event Mode visitor information are stored on the device (and in the user's iCloud if enabled). They are not collected by the developer or shared with the SDK, so they are not declared.
- Product personalization: No. Developer analytics: none beyond the SDK diagnostics above.

## Permissions Summary

Camera: Used to scan business cards.

Photos: Used when the user selects images for business cards or event information.

Contacts: Used to import contact information, detect duplicate contacts, or save business card information to Contacts.

Location: Used only when the user chooses to insert the current location into a meeting or event note.

Calendars: Used only when the user enables event integration.

Reminders: Used only when the user enables task integration.

## Screenshots Needed

iPhone screenshots:

- Main note list
- New note type selection
- Meeting or event note editor
- Business card scan/result screen
- Settings or export screen

iPad screenshots:

- Sidebar and note list
- Note detail editor
- Business card management screen
- Settings screen

