# BizNote 1.22 App Store Release

## Version

- Version: 1.22
- Build: 5
- Category: Business
- Encryption: Uses only standard Apple platform encryption. No non-exempt encryption.

## What's New - Korean

업무일지, 회의록, 행사, 명함 관리 흐름을 개선했습니다.

- 업무일지에서 같은 날 회의록이 회의 일시 기준으로 표시되도록 개선했습니다.
- 회의록의 참석자 불러오기, 회의 시작/종료 시간 입력, 메모 편집 경험을 개선했습니다.
- 행사 상세 화면에서 로고 이미지를 사진앱 또는 파일앱에서 더 쉽게 선택할 수 있도록 개선했습니다.
- 행사 노트의 명함/연락처 불러오기 흐름을 정리했습니다.
- 명함을 여러 장 한 번에 스캔하고 저장할 수 있도록 개선했습니다.
- 명함 OCR에서 회사명 인식 정확도를 개선했습니다.
- iPad 2컬럼 화면에서 노트 선택 시 상세 화면으로 이동하지 않던 문제를 수정했습니다.

## What's New - English

This update improves work logs, meeting minutes, exhibitions, and business card management.

- Work logs now show same-day meeting notes based on the meeting date and time.
- Improved meeting participant import, start/end time entry, and memo editing.
- Exhibition logos can now be selected more easily from Photos or Files.
- Unified business card and contact import flows in event notes.
- Added support for scanning and saving multiple business cards at once.
- Improved company name recognition in business card OCR.
- Fixed an iPad two-column layout issue where selecting a note did not open its detail view.

## App Review Notes - Korean

BizNote는 업무일지, 회의록, 행사 정보, 명함을 관리하는 비즈니스 노트 앱입니다.

이번 버전은 기존 기능 개선 및 버그 수정 업데이트입니다. 명함 스캔은 카메라 권한을 사용하며, 행사 로고 및 이미지 선택은 사용자가 직접 선택한 사진 또는 파일에만 접근합니다. 연락처 불러오기는 시스템 연락처 선택기를 통해 사용자가 선택한 연락처만 앱으로 전달됩니다.

테스트 권장 경로:

1. 노트 탭에서 회의록을 생성하고 참석자 불러오기 아이콘을 눌러 명함 또는 연락처 가져오기를 확인합니다.
2. 행사 탭에서 행사를 선택한 뒤 편집 모드로 들어가 로고 이미지 칸을 눌러 사진앱/파일앱 선택 메뉴를 확인합니다.
3. 명함관리 탭에서 여러 장의 명함을 스캔하거나 사진에서 가져와 저장합니다.
4. iPad 세로 화면의 2컬럼 레이아웃에서 노트 리스트 항목을 눌러 상세 화면으로 이동하는지 확인합니다.

## App Review Notes - English

BizNote is a business note app for managing work logs, meeting minutes, exhibition information, and business cards.

Version 1.22 is a feature improvement and bug fix update. Business card scanning uses camera access. Exhibition logo and image selection only accesses photos or files explicitly selected by the user. Contact import uses the system contact picker, and only the selected contact is passed to the app.

Suggested review flow:

1. Create a meeting note and tap the participant import icon to verify importing from scanned business cards or Contacts.
2. Open an exhibition, enter edit mode, and tap the logo image box to choose an image from Photos or Files.
3. Open business card management and scan or import multiple business card images.
4. On iPad in portrait two-column layout, tap a note list row and verify that the detail view opens.

## Release Checklist

- [x] `BizNote/Info.plist` updated to version 1.22, build 5.
- [x] `project.yml` updated to version 1.22, build 5.
- [x] Settings fallback app version updated to 1.22.
- [ ] In Xcode project settings, confirm MARKETING_VERSION = 1.22 and CURRENT_PROJECT_VERSION = 5 without manually editing `project.pbxproj`.
- [ ] Archive with Release configuration.
- [ ] Upload archive to App Store Connect.
- [ ] Create App Store Connect version 1.22 if it does not already exist.
- [ ] Paste localized What's New text.
- [ ] Submit for App Review.
