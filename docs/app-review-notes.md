# App Review Notes

## App Overview

BizNote is an iOS and iPadOS business note app for creating work logs, meeting minutes, event notes, custom note templates, and business card records.

The app does not require login, account creation, subscription, in-app purchase, or external payment.

The first release is intended to be free.

## Test Account

No test account is required.

## Features to Test

1. Launch the app.
2. Create a new note from the note list.
3. Select a note type such as work log, meeting minutes, event note, or custom note.
4. Enter note details and save.
5. Open the business card area.
6. Scan a business card with the camera or select a business card image from Photos.
7. Review OCR results and save the business card.
8. Optionally save business card details to Contacts.
9. Open settings and review iCloud sync, Calendar, and Reminders integration options.
10. Export supported data as PDF or CSV through the system share sheet.

## Privacy Summary

The app stores user-created notes, business card data, scanned images, attachments, event information, app settings, and optional location text on the user's device.

If enabled by the user, iCloud sync uses the user's personal iCloud account and Apple's CloudKit service.

The developer does not operate a separate server for collecting user data from the app.

The app does not include advertising SDKs, analytics SDKs, tracking SDKs, or third-party dependencies.

## Permission Usage

Camera: Scanning business cards.

Photos: Selecting business card or event images.

Contacts: Importing contact information, checking duplicates, and saving business card information.

Location: Inserting the current location into meeting or event notes when requested by the user.

Calendars: Adding event information to Calendar when the user enables integration.

Reminders: Adding task information to Reminders when the user enables integration.

## Notes for Reviewer

All core functionality is available without signing in.

Network communication is limited to Apple system services used by enabled features, such as iCloud/CloudKit and MapKit/location services.
