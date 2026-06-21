# Notepad for macOS

Windows 11의 최신 내장 Notepad와 최대한 비슷한 동작의 macOS용 플레인 텍스트 에디터입니다.

**Developer:** Min-Gul Kim, MD, PhD (Jeonbuk National University Medical School)

## 주요 목표
- 플레인 텍스트 전용 (rich-text, Markdown formatting, AI 기능 완전 배제)
- 멀티 탭 지원
- **세션 자동 복원**: 저장하지 않은 내용 포함, 재부팅 후에도 이전 탭 + 내용 복원 (Windows 11 Notepad와 최대한 동일 동작)
- 한국어 사용자 편의: 인코딩 변경/변환 기능 강화 (EUC-KR, UTF-8 등)
- 빠르고 단순한 사용성

## 개발 환경
- Swift + SwiftUI
- Apple Silicon (M 시리즈) 우선 지원
- 최소 macOS: 13.0 (Ventura) 이상 권장
- Xcode 최신 버전

## 프로젝트 초기 설정 방법 (Xcode)

1. Xcode에서 **File > New > Project** 선택
2. **macOS > App** 템플릿 선택
3. 설정:
   - Product Name: `Notepad for macOS`
   - Organization Identifier: `com.yourname` (또는 적당한 값, 예: `com.min`)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Use Core Data / Tests: 필요에 따라 (초기에는 해제 추천)
4. 프로젝트 생성 후:
   - 기본으로 생성된 `ContentView.swift`, `Notepad_for_macOSApp.swift` 등을 **삭제**
   - 이 저장소의 `Notepad for macOS/Notepad for macOS/` 폴더 안의 모든 `.swift` 파일을 프로젝트 타겟에 추가 (드래그)
   - `Assets.xcassets` 는 기존 것을 유지하거나 덮어쓰기
5. **Build Settings**:
   - Deployment Target: macOS 13.0 또는 14.0
   - Architectures: `Standard` (Universal) 또는 Apple Silicon 전용으로 설정 가능
6. **Info.plist** (필요시):
   - Bundle identifier 확인
   - 직접 배포이므로 App Sandbox는 기본 off (또는 필요에 따라)

7. 실행: `Cmd + R`

## 주요 동작 특징 (Windows 11 Notepad와 유사하게)
- 탭을 닫지 않고 앱 종료 → 다음 실행 시 모든 탭 + 수정 내용 복원
- 설정에서 "시작 시 동작" 변경 가능 (이전 세션 계속 / 새 세션)
- 저장하지 않은 탭은 제목에 `*` 표시
- 실제 파일에는 저장되지 않은 상태로 복원됨

## 인코딩 지원 (추가 기능)
- UTF-8 (기본, no BOM)
- UTF-8 with BOM
- EUC-KR (한국어 레거시)
- 기타 (추가 예정)
- 파일 열기/저장 시 인코딩 선택
- 열린 탭에서 "인코딩으로 다시 열기", "현재 내용 변환"

## 단축키 (기본)
- Cmd + T 또는 Cmd + N : 새 탭
- Cmd + O : 열기
- Cmd + S : 저장
- Cmd + Shift + S : 다른 이름으로 저장
- Cmd + W : 탭 닫기
- Cmd + F : 찾기
- Cmd + G : 줄 이동
- Cmd + + / Cmd + - : 확대/축소
- F5 : 시간/날짜 삽입

## 빌드 및 배포
- 직접 배포 목적
- Xcode에서 Archive 후 .app 추출해서 배포
- Apple Silicon (arm64) 바이너리 포함

## 개발 상태
초기 스켈레톤 구현 완료 (2026-06-20)

구현된 주요 기능:
- 멀티 탭 + 커스텀 탭 바 (* 표시)
- NSTextView 기반 에디터 (폰트 크기, word wrap 대응)
- **세션 자동 복원** (저장 안 한 내용 포함, 재시작 후 복원) — Windows 11 Notepad와 최대한 유사
- 인코딩 (UTF-8, UTF-8 BOM, EUC-KR, UTF-16)
  - Status bar에서 Reopen as / Convert to 지원
- 기본 File (New Tab, Open, Save, Save As)
- Edit (Find/Replace 기초, Go to Line, Time/Date)
- View (Word Wrap, Zoom, Status Bar toggle)
- Settings (시작 동작, 폰트 크기)
- Apple Silicon 네이티브

TODO (다음 단계):
- 정확한 Line/Column 표시 (커서 위치 추적)
- Save As 시 인코딩 선택 UI
- 더 나은 Find (정규식, 다음/이전)
- 창 다중 지원 개선
- 큰 파일 성능 + 세션 백업 강화

Xcode 프로젝트를 생성한 뒤 이 폴더 안의 파일들을 타겟에 추가하세요.

## 개발자

**Min-Gul Kim, MD, PhD**  
Professor at Jeonbuk National University Medical School  
Email: mgkim@jbnu.ac.kr

## 라이선스

이 프로젝트는 [MIT License](LICENSE) 하에 배포됩니다.

Copyright © 2026 Min-Gul Kim. All rights reserved.

## 연락 및 기여

버그 리포트, 제안, 기여는 언제든 환영합니다.

---

이 README는 프로젝트 초기화 시 작성되었습니다. 구현이 진행됨에 따라 업데이트됩니다.
