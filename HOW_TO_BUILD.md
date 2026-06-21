# Notepad for macOS — Xcode 프로젝트 생성 및 빌드 방법

## 1. Xcode에서 새 프로젝트 만들기

1. Xcode 실행 → **File > New > Project...**
2. **macOS** 탭 선택 → **App** 템플릿 선택 → **Next**
3. 프로젝트 설정:
   - **Product Name**: `Notepad for macOS`
   - **Organization Identifier**: `com.min` 또는 원하는 값 (예: `com.yourname`)
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
   - **Storage / Core Data**: 체크 해제 (초기)
4. **Create**

## 2. 기존 파일 교체

생성된 프로젝트에서 아래 파일/그룹을 **삭제**하세요:
- `ContentView.swift`
- `Notepad_for_macOSApp.swift` (또는 프로젝트 이름_App.swift)
- 필요시 Preview Content

그 후 이 저장소의 다음 파일들을 **프로젝트 네비게이터에 드래그해서 추가**:

```
Notepad for macOS/
├── Notepad for macOS/
│   ├── NotepadApp.swift
│   ├── Models/
│   │   ├── TextEncoding.swift
│   │   ├── LineEnding.swift
│   │   └── Document.swift
│   ├── Managers/
│   │   ├── TabManager.swift
│   │   └── SessionStore.swift
│   ├── Views/
│   │   ├── MainEditorView.swift
│   │   ├── EditorView.swift
│   │   ├── TabBar... (이미 Main에 포함)
│   │   ├── FindReplaceSheet.swift
│   │   ├── GoToLineSheet.swift
│   │   └── SettingsView.swift
│   └── Helpers/
│       └── AppDelegate.swift (선택)
```

## 3. 빌드 설정 (Apple Silicon)

- 프로젝트 선택 → **Build Settings**
  - **Deployment** → **macOS Deployment Target**: `13.0` 또는 `14.0`
  - **Architectures**:
    - `Standard Architectures (arm64)`  ← Apple Silicon 전용 (직접 배포 추천)
    - 또는 `Standard Architectures (Apple Silicon, Intel)` (Universal)

- **Signing & Capabilities**: 직접 배포이므로 필요에 따라 "Hardened Runtime"만 체크 (App Store 아님)

## 4. Assets 및 기타

- 기존 `Assets.xcassets` 유지
- App Icon은 나중에 추가

## 5. 실행

- `Cmd + R`
- 메뉴: Notepad for macOS → Settings 에서 "Continue previous session" 토글 테스트

## 6. 세션 복원 테스트 추천

1. 앱 실행
2. 여러 탭 열고 내용 입력 (저장하지 않음)
3. 앱 완전히 종료 (Cmd+Q)
4. 다시 실행 → 내용이 그대로 복원되는지 확인
5. mac 재부팅 후 테스트 (강력 추천)

## 7. 배포

- Xcode → **Product > Archive**
- Organizer에서 Export → "Copy App" 또는 "Developer ID"로 서명해서 .app 배포

## 문제 해결 팁

- 컴파일 에러 "duplicate" : MainEditorView.swift 에 중복 EditorView 정의가 없는지 확인 (이미 제거함)
- EUC-KR 테스트: 한국어로 된 레거시 .txt 파일을 열고 Status Bar의 인코딩 메뉴에서 "EUC-KR" 선택 후 Reopen as 테스트

이제 코드를 계속 다듬겠습니다. 추가 요청 언제든 말씀해주세요!
