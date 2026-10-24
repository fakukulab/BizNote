# BizNote 1.24 심사 제출용 변경 내용

## 한국어

BizNote 1.24에서는 명함 스캔, 노트 작성, 회의록, 행사노트, iPad 레이아웃의 안정성과 사용성을 개선했습니다.

- 모든 노트 리스트의 일자가 실제 작성일이 아닌 오늘 날짜로 표시되던 문제를 수정했습니다.
- 명함 스캔 후 인식된 명함 정보가 저장되지 않거나 명함 관리 목록에 표시되지 않던 문제를 수정했습니다.
- iPhone에서 명함 이미지가 저장되지 않던 문제를 수정했습니다.
- 여러 장의 명함을 연속으로 스캔할 때 각 명함별 OCR 및 파싱 결과가 올바르게 반영되도록 개선했습니다.
- 한국어/영어 명함 OCR 인식 및 파싱 규칙을 보강했습니다.
- 명함 관리 화면의 iPad 레이아웃을 개선했습니다.
  - iPad 세로 화면에서는 2열 레이아웃을 유지합니다.
  - iPad 가로 화면에서는 사이드바, 목록, 상세의 3열 레이아웃을 지원합니다.
  - 화면 회전 시 선택한 사이드바 메뉴를 유지한 상태로 레이아웃만 전환되도록 개선했습니다.
- 명함 관리 3열 레이아웃에서 상세 영역이 “노트 없음”으로 잘못 표시되던 문제를 수정했습니다.
- 회의록의 안건, 논의사항, 결정사항을 항목 단위로 입력하고 수정할 수 있도록 개선했습니다.
- 회의록의 안건, 논의사항, 결정사항 항목을 위아래로 재정렬할 수 있도록 개선했습니다.
- 회의록의 온라인 미팅 링크를 클릭 가능한 링크로 표시하고, 최근 위치 목록에는 저장되지 않도록 수정했습니다.
- 회의록과 행사노트의 후속조치 입력 UI를 정리했습니다.
- 행사노트의 방문 부스 및 방문객 연락처 입력 UI를 개선했습니다.
  - 입력칸 테두리를 제거했습니다.
  - 국가, 회사, 이름, 직함, 이메일, 휴대폰, 메모 사이의 구분선을 정리했습니다.
  - 폰트 색상, 크기, 정렬을 통일했습니다.
- 행사 세부정보 화면의 편집 버튼을 아이콘으로 변경했습니다.
- 주요 아이콘 버튼과 메뉴의 접근성 라벨을 개선했습니다.
- 업무 일지의 “업무 날짜” 문구를 “업무 일자”로 변경했습니다.
- 한국어 화면에서 “Recent”가 “최근”으로 표시되도록 수정했습니다.

## English

BizNote 1.24 improves the stability and usability of business card scanning, notes, meeting minutes, exhibition notes, and iPad layouts.

- Fixed an issue where note lists could show today’s date instead of the actual creation date.
- Fixed an issue where scanned business card information was not saved or displayed in the business card list.
- Fixed an issue where business card images were not saved on iPhone.
- Improved OCR and parsing result handling when scanning multiple business cards in sequence.
- Enhanced Korean and English business card OCR recognition and parsing rules.
- Improved the iPad layout for business card management.
  - iPad portrait keeps the 2-column layout.
  - iPad landscape supports a 3-column layout with sidebar, list, and detail.
  - The selected sidebar menu is preserved when rotating the device.
- Fixed an issue where the business card detail area incorrectly showed “No Notes” in the 3-column layout.
- Improved meeting minutes so agenda, discussion points, and decisions can be entered and edited as individual items.
- Added reordering support for agenda, discussion, and decision items in meeting minutes.
- Online meeting links in meeting minutes are now displayed as clickable links and are excluded from recent location history.
- Refined follow-up input UI in meeting minutes and exhibition notes.
- Improved visited booth and visitor contact input UI in exhibition notes.
  - Removed input field borders.
  - Added clearer separators between country, company, name, title, email, mobile phone, and memo fields.
  - Unified font color, size, and alignment.
- Changed the edit button on the exhibition detail screen to an icon.
- Improved accessibility labels for key icon buttons and menus.
- Updated Korean wording from “업무 날짜” to “업무 일자”.
- Fixed Korean localization so “Recent” is displayed as “최근”.

## App Store Connect Release Notes

### Korean

명함 스캔, 회의록, 행사노트, iPad 레이아웃의 안정성과 사용성을 개선했습니다.

- 명함 스캔 후 저장 및 목록 표시 문제 수정
- 여러 장의 명함 연속 스캔 시 OCR 결과 반영 개선
- 한국어/영어 명함 OCR 인식 및 파싱 규칙 보강
- 노트 리스트 날짜 표시 오류 수정
- 회의록 안건/논의사항/결정사항 입력 및 재정렬 개선
- 온라인 미팅 링크 연결 및 최근 목록 제외 처리
- 행사노트 방문 부스/방문객 연락처 입력 UI 개선
- iPad 가로 3열, 세로 2열 레이아웃 개선
- 주요 아이콘 버튼 및 메뉴 접근성 개선

### English

Improved the stability and usability of business card scanning, meeting minutes, exhibition notes, and iPad layouts.

- Fixed business card scan saving and list display issues
- Improved OCR result handling for consecutive business card scans
- Enhanced Korean and English business card OCR parsing rules
- Fixed note list date display issues
- Improved agenda, discussion, and decision item editing and reordering in meeting minutes
- Added clickable online meeting links and excluded them from recent location history
- Improved visited booth and visitor contact input UI in exhibition notes
- Improved iPad 3-column landscape and 2-column portrait layouts
- Improved accessibility for key icon buttons and menus
