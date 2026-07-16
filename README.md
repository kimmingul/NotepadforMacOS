# Notepad for macOS

[![Release](https://img.shields.io/github/v/release/kimmingul/NotepadforMacOS?label=release)](https://github.com/kimmingul/NotepadforMacOS/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Windows 11 **기본 메모장** 수준의 익숙함을 목표로 한 macOS 플레인 텍스트 편집기입니다. Swift + SwiftUI로 작성되었습니다.

**최신 버전:** [v1.1.0](https://github.com/kimmingul/NotepadforMacOS/releases/tag/v1.1.0) (Developer ID 서명 · 공증)  
**사이트:** [GitHub Pages](https://kimmingul.github.io/NotepadforMacOS/) · **릴리즈 노트:** [v1.1](docs/releases/RELEASE_NOTES_v1.1.md)

**Developer:** Min-Gul Kim, MD, PhD (Jeonbuk National University Medical School)

---

## 주요 목표

- 플레인 텍스트 전용 (rich-text, Markdown formatting, AI 기능 배제)
- 멀티 탭 + **세션 자동 복원** (미저장 내용 포함, Windows 11 Notepad와 유사)
- 한국어 편의: EUC-KR · UTF-8/BOM · UTF-16 인코딩
- Win11 기본 메모장 수준 편집 보조: **맞춤법 검사** · 선택적 자동 수정 · 시작 안내
- 빠르고 단순한 사용성 · 네트워크 없음 · 데이터 수집 없음

### 의도적 비목표

- AI (Rewrite / Summarize / Write 등)
- Markdown 렌더 · 굵게/기울임 · 표 · 이미지
- 네트워크 · 계정 · 텔레메트리

---

## v1.1 하이라이트

| 기능 | 설명 |
|------|------|
| 맞춤법 검사 | 기본 켜짐, macOS 시스템 사전, 네트워크 없음 |
| 자동 수정 | 기본 꺼짐, 설정·편집 메뉴에서 토글 |
| 확장자 예외 | `log`, `json`, `swift` 등에서 검사 생략 (목록 편집 가능) |
| Welcome / What's New | 첫 실행 안내, 업그레이드 시 새 기능, 도움말에서 다시 열기 |
| 상태 표시줄 | 줄/열 클릭 → 줄로 이동, 인코딩 다시 열기/변환 구분 |
| 글꼴 안내 | 기본 크기와 확대/축소 관계 명확화 (재설정 = 14 pt) |

전체 변경: [RELEASE_NOTES_v1.1.md](docs/releases/RELEASE_NOTES_v1.1.md)

---

## 기능 요약

- 다중 탭 (드래그 재정렬, Ctrl+Tab), 미저장 탭 `*` 표시
- 세션 복원 / 시작 시 이전 세션 또는 새 세션
- 인라인 찾기·바꾸기, 줄로 이동, 시간/날짜(F5), 인쇄·페이지 설정
- 인코딩 열기/저장/다시 열기/변환 (표현 불가 문자 경고)
- 샌드박스 + 보안 스코프 북마크, 한글/CJK IME 안전 커밋
- 한국어 / 영어 현지화

---

## 개발 환경

- Swift 5 / SwiftUI + AppKit (`NSTextView` 기반 에디터)
- Apple Silicon (arm64)
- Xcode 26 이상

## 프로젝트 구조

```
notepad_macOS/
├── README.md  HOW_TO_BUILD.md  TEST_MATRIX.md  LICENSE  build.sh
├── index.html                  # GitHub Pages (root)
├── docs/releases/              # 릴리즈 노트
├── Design/                     # 참고용 아이콘 원본
└── NotepadForMacOS/
    ├── Notepad.entitlements
    ├── NotepadForMacOS.xcodeproj
    ├── NotepadForMacOS/        # 앱 소스 (파일 시스템 동기화 그룹)
    │   ├── App/  Models/  ViewModels/  Services/  Views/
    │   └── Assets.xcassets  en.lproj/  ko.lproj/
    └── NotepadForMacOSTests/
```

> 새 소스 파일은 동기화 그룹에 자동 포함됩니다. `project.pbxproj`를 수동으로 고칠 필요가 없습니다.

## 빌드 / 실행

```bash
./build.sh                 # 디버그
./build.sh release         # 릴리스 (Hardened Runtime)
./build.sh test            # 단위 테스트
./build.sh dist            # 배포용 dist/Notepad.dmg
./build.sh open            # Xcode 열기
```

Xcode: `NotepadForMacOS/NotepadForMacOS.xcodeproj` → `Cmd+R`.

## 주요 동작 (Windows 11 Notepad와 유사)

- 탭을 닫지 않고 종료 → 다음 실행 시 탭·수정 내용 복원
- 설정: 시작 시 이전 세션 계속 / 새 세션
- 미저장 탭 제목에 `*`
- 복원 시 원본 파일을 못 읽으면 빈 내용으로 **자동 덮어쓰지 않음**

## 인코딩

- UTF-8 (기본), UTF-8 with BOM, EUC-KR, UTF-16 LE/BE
- 열기/저장 시 인코딩 선택
- 상태바: 인코딩으로 다시 열기, 현재 내용 변환 (표현 불가 경고)

## 단축키

| 동작 | 단축키 |
|------|--------|
| 새 탭 | `Cmd + T` |
| 새 창 | `Cmd + Shift + N` |
| 열기 | `Cmd + O` |
| 저장 / 다른 이름으로 저장 | `Cmd + S` / `Cmd + Shift + S` |
| 페이지 설정 / 인쇄 | `Cmd + Shift + P` / `Cmd + P` |
| 찾기 (인라인) | `Cmd + F` |
| 다음 / 이전 찾기 | `Cmd + G` / `Cmd + Shift + G` |
| 줄로 이동 | `Cmd + L` |
| 시간/날짜 삽입 | `F5` |
| 자동 줄 바꿈 | `Cmd + Shift + W` |
| 확대 / 축소 / 재설정 | `Cmd + +` / `Cmd + -` / `Cmd + 0` |
| 다음 / 이전 탭 | `Ctrl + Tab` / `Ctrl + Shift + Tab` |
| 탭 닫기 | `Cmd + W` |

## 배포 (Developer ID + 공증)

```bash
export DEVID_APP="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="notary-profile"   # xcrun notarytool store-credentials
./build.sh dist
```

환경 변수가 없으면 ad-hoc 서명 DMG만 생성합니다. 공증된 빌드는 [Releases](https://github.com/kimmingul/NotepadforMacOS/releases)에서 받을 수 있습니다.

## 개발 상태

- 멀티 탭 · 세션 복원 · 인라인 찾기/바꾸기 · 인쇄 · 인코딩
- **v1.1:** 맞춤법 · 자동 수정 · 확장자 예외 · Welcome / What's New · 상태바 폴리시
- 샌드박스 · 보안 스코프 북마크 · IME 안전 · 단위 테스트

## 개발자

**Min-Gul Kim, MD, PhD** — Professor, Jeonbuk National University Medical School  
Email: mgkim@jbnu.ac.kr

## 라이선스

[MIT License](LICENSE) · Copyright © 2026 Min-Gul Kim.
