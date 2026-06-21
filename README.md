# Notepad for macOS

Windows 11의 최신 내장 메모장(Notepad)과 최대한 비슷하게 동작하는 macOS용 플레인 텍스트 에디터입니다. Swift + SwiftUI로 작성되었습니다.

**Developer:** Min-Gul Kim, MD, PhD (Jeonbuk National University Medical School)

## 주요 목표
- 플레인 텍스트 전용 (rich-text, Markdown formatting, AI 기능 배제)
- 멀티 탭 지원
- **세션 자동 복원**: 저장하지 않은 내용 포함, 재시작/재부팅 후에도 이전 탭 + 내용 복원 (Windows 11 Notepad와 유사)
- 한국어 사용자 편의: 인코딩 변경/변환 강화 (EUC-KR, UTF-8/BOM, UTF-16)
- 빠르고 단순한 사용성

## 개발 환경
- Swift 5 / SwiftUI + AppKit (NSTextView 기반 에디터)
- Apple Silicon (arm64)
- Xcode 26 이상

## 프로젝트 구조

```
notepad_macOS/
├── README.md  HOW_TO_BUILD.md  TEST_MATRIX.md  LICENSE  build.sh
├── Design/                         # 참고용 아이콘 원본 (앱에 포함되지 않음)
└── NotepadForMacOS/
    ├── Notepad.entitlements        # 샌드박스 엔타이틀먼트 (read-write + 보안 북마크)
    ├── NotepadForMacOS.xcodeproj
    ├── NotepadForMacOS/             # 앱 타깃 (소스 + 리소스, 단일 동기화 그룹)
    │   ├── App/                     # NotepadApp(@main), AppDelegate, Commands, Actions
    │   ├── Models/                  # Document, LineEnding, TextEncoding
    │   ├── ViewModels/              # TabManager
    │   ├── Services/                # SessionStore, SecurityScopedFile
    │   ├── Views/                   # MainEditorView, EditorView, FindReplaceSheet, …
    │   ├── Assets.xcassets/  en.lproj/  ko.lproj/  Credits.rtf  LICENSE
    └── NotepadForMacOSTests/        # 단위 테스트 (동기화 그룹)
```

> 소스 파일을 새로 추가하면 Xcode의 파일 시스템 동기화 그룹이 자동으로 타깃에 포함합니다. 수동으로 `project.pbxproj`를 손볼 필요가 없습니다.

## 빌드 / 실행

```bash
# 디버그 빌드
./build.sh                 # 또는 ./build.sh build
# 릴리스 빌드 (Hardened Runtime, 배포용 엔타이틀먼트)
./build.sh release
# 테스트
./build.sh test
# 배포용 .dmg 생성 (dist/)
./build.sh dist
# Xcode에서 열기
./build.sh open
```

Xcode에서 직접 열려면 `NotepadForMacOS/NotepadForMacOS.xcodeproj`를 열고 `Cmd+R`.

## 주요 동작 (Windows 11 Notepad와 유사)
- 탭을 닫지 않고 앱 종료 → 다음 실행 시 모든 탭 + 수정 내용 복원
- 설정에서 "시작 시 동작" 변경 (이전 세션 계속 / 새 세션)
- 저장하지 않은 탭은 제목에 `*` 표시
- 복원 시 원본 파일을 읽지 못하면 빈 내용으로 **자동 덮어쓰지 않고** 저장 전 확인

## 인코딩
- UTF-8 (기본), UTF-8 with BOM, EUC-KR(한국어 레거시), UTF-16 LE/BE
- 파일 열기/저장 시 인코딩 선택
- 상태바에서 "인코딩으로 다시 열기", "현재 내용 변환"(표현 불가 문자 경고)

## 단축키
| 동작 | 단축키 |
|------|--------|
| 새 탭 | `Cmd + T` |
| 새 창 | `Cmd + Shift + N` |
| 열기 | `Cmd + O` |
| 저장 / 다른 이름으로 저장 | `Cmd + S` / `Cmd + Shift + S` |
| 페이지 설정 / 인쇄 | `Cmd + Shift + P` / `Cmd + P` |
| 찾기(인라인 막대) | `Cmd + F` |
| 다음 찾기 / 이전 찾기 | `Cmd + G` / `Cmd + Shift + G` |
| 줄로 이동 | `Cmd + L` |
| 시간/날짜 삽입 | `F5` |
| 자동 줄 바꿈 토글 | `Cmd + Shift + W` |
| 확대 / 축소 / 재설정 | `Cmd + +` / `Cmd + -` / `Cmd + 0` |
| 다음 탭 / 이전 탭 | `Ctrl + Tab` / `Ctrl + Shift + Tab` |
| 탭 닫기 | `Cmd + W` |

## 배포 (직접 배포 + 공증)

`./build.sh dist`는 릴리스 빌드 후 `dist/Notepad.dmg`를 만듭니다. 다른 Mac에서 Gatekeeper 경고 없이 실행되게 하려면 **Developer ID 서명 + 공증(notarization)** 이 필요합니다. Apple Developer 계정과 인증서를 준비한 뒤 환경 변수를 설정하면 `dist`가 서명·공증·스테이플을 수행합니다:

```bash
export DEVID_APP="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="notary-profile"   # xcrun notarytool store-credentials 로 미리 등록
./build.sh dist
```

환경 변수가 없으면 dmg만 만들고(애드혹 서명) 다음 단계를 안내합니다.

## 개발 상태
- 다중 탭 + 커스텀 탭 바(**드래그 재정렬**, Ctrl+Tab 순환), 세션 자동 복원(미저장 내용 포함)
- NSTextView 기반 에디터(단일 소스 오브 트루스, 실행취소 안전한 찾기/바꾸기·시간삽입·인코딩 재로드)
- **인라인 찾기/바꾸기 막대**(비모달, 일치 개수·방향·대소문자·둘러 찾기)
- 인쇄 + **페이지 설정**
- 인코딩(UTF-8 / BOM / EUC-KR / UTF-16) + 상태바 다시 열기/변환(표현 불가 경고)
- 샌드박스 + 보안 스코프 북마크로 재실행 후 파일 접근/저장
- 멀티 윈도우 세션: 창을 닫으면 해당 세션 정리, 종료 시에는 복원 보존(+ 오래된 세션 GC)
- 한글/CJK 조합 텍스트는 저장 직전 커밋(IME 안전)
- 단위 테스트(인코딩·줄바꿈·문서·세션)

## 개발자
**Min-Gul Kim, MD, PhD** — Professor, Jeonbuk National University Medical School
Email: mgkim@jbnu.ac.kr

## 라이선스
[MIT License](LICENSE) · Copyright © 2026 Min-Gul Kim.
