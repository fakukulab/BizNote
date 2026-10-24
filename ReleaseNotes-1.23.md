# BizNote 1.23 App Store Release

## Version

- Version: 1.23
- Build: 6
- Category: Business
- Encryption: Uses only standard Apple platform encryption. No non-exempt encryption.

## What's New - Korean

이번 버전은 사용 중 발견된 문제를 수정한 버그픽스 업데이트입니다.

- iPhone에서 명함 스캔 후 명함 이미지가 저장되지 않을 수 있던 문제를 수정했습니다.
- iPad 3열 화면에서 노트 선택 시 중간 리스트의 선택 표시가 유지되지 않던 문제를 수정했습니다.
- 메모 편집 도구가 메모 입력칸 안쪽에 바로 보이도록 위치를 조정했습니다.
- Event 캘린더에서 월 이동 시 하단 행사 리스트의 검색 시작 월도 함께 변경되도록 수정했습니다.
- 명함 관리의 연락처 관련 문구와 불필요한 중복 확인 UI를 정리했습니다.

## What's New - English

This is a bug fix update.

- Fixed an issue where scanned business card images might not be saved on iPhone.
- Fixed note selection highlighting in the iPad three-column layout.
- Moved memo editing controls into the memo field area for easier access.
- Updated Event calendar month navigation so the event list search start month follows the displayed calendar month.
- Cleaned up Contacts wording and removed unnecessary duplicate-check UI in business card management.

## App Review Notes - Korean

BizNote는 업무일지, 회의록, 행사 정보, 명함을 관리하는 비즈니스 노트 앱입니다.

이번 버전은 버그픽스 업데이트입니다. 명함 스캔은 카메라 권한을 사용하며, 연락처 추가는 사용자가 명시적으로 선택한 경우에만 시스템 연락처 권한을 요청합니다. 행사 일정 연동은 사용자가 설정한 캘린더/미리 알림 연동 옵션에 따라 동작합니다.

테스트 권장 경로:

1. 명함관리 탭에서 명함을 스캔하거나 사진에서 가져온 뒤 저장하고, 상세 화면 상단에 명함 이미지가 표시되는지 확인합니다.
2. iPad 가로 화면의 3열 레이아웃에서 노트 리스트 항목을 선택하고 선택 표시가 유지되는지 확인합니다.
3. 노트 상세 화면의 메모 입력칸에서 편집 도구가 입력칸 안쪽에 표시되는지 확인합니다.
4. Event 화면에서 월간 캘린더의 이전/다음 월 버튼을 누르고, 하단 기간 검색 시작 월이 같은 월로 변경되는지 확인합니다.

## App Review Notes - English

BizNote is a business note app for managing work logs, meeting minutes, exhibition information, and business cards.

Version 1.23 is a bug fix update. Business card scanning uses camera access. Contacts permission is requested only when the user explicitly adds business card details to Contacts. Calendar and reminder integration follows the user's integration settings.

Suggested review flow:

1. Open business card management, scan or import a business card image, save it, and verify that the image appears at the top of the detail screen.
2. On iPad in three-column landscape layout, select a note list row and verify that the selection highlight remains visible.
3. Open a note detail screen and verify that memo editing controls are visible inside the memo field area.
4. In the Event screen, move the monthly calendar to the previous or next month and verify that the event list search start month changes to the same month.

## Release Checklist

- [x] `BizNote/Info.plist` updated to version 1.23, build 6.
- [x] `project.yml` updated to version 1.23, build 6.
- [x] Settings fallback app version updated to 1.23.
- [ ] In Xcode project settings, confirm MARKETING_VERSION = 1.23 and CURRENT_PROJECT_VERSION = 6.
- [ ] Archive with Release configuration.
- [ ] Upload archive to App Store Connect.
- [ ] Create App Store Connect version 1.23 if it does not already exist.
- [ ] Paste localized What's New text.
- [ ] Submit for App Review.
