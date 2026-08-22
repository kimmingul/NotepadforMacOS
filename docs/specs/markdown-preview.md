# Spec: Markdown / HTML Highlight + Preview

## Objective

`.md` / `.markdown` / `.html` / `.htm` 탭에서 **원문 편집은 지금 `NSTextView` 그대로** 두고, 소스 하이라이트와 렌더 미리보기만 추가한다. Typora 위지윅이 아니다.

성공 기준은 아래 Success Criteria. 제품 문장: “플레인 텍스트가 기본. `.md` / `.html`는 원할 때만 미리보기.”

**Status (v1.2.0 / build 3):** 구현됨. `./build.sh test` 통과. 탭바 미리보기 아이콘은 패널이 열려도 `sidebar.right`를 유지한다(`.fill`+강조색은 투명하게 그려져 클릭만 되는 버그가 있었음).

## Assumptions

1. 트리거는 확장자 `.md` / `.markdown` / `.html` / `.htm`. Untitled는 미리보기 없음.
2. Markdown 방언은 Swift Markdown이 제공하는 GFM 부분집합: 제목, 목록, 인용, 코드, 링크, 이미지, 표, 취소선, 체크박스. **수식·Mermaid 없음.**
3. HTML 미리보기는 살균된 마크업만. `<script>`, `javascript:` / `data:`, 이벤트 핸들러 제거. 원격 `<img>` / CSS는 탭 허용 전 차단.
4. 미리보기 열림/닫힘·전체화면은 **창 단위**. 탭을 바꿔도 레이아웃은 유지. `.txt`로 바꾸면 패널은 숨김. 탭바는 창 전체 폭.
5. 로컬 이미지 폴더 권한은 세션에 남긴다. 원격 허용만 탭을 닫으면 리셋.
6. 원격 허용 중에도 `http`/`https`를 WebView에 직접 넣지 않는다. 커스텀 스킴으로만 로드.
7. SPM `swift-markdown` (`Markdown` 제품)을 쓴다. 우리 `Document`와 이름 충돌 → `Markdown.Document`로만 참조.


## Tech Stack

- 기존: Swift 5, SwiftUI + AppKit `NSTextView`, App Sandbox
- 추가: [swift-markdown](https://github.com/swiftlang/swift-markdown) (`import Markdown`)
- 미리보기: `WKWebView` + `WKURLSchemeHandler` (커스텀 스킴, 예: `notepad-md`)
- 네트워크: `com.apple.security.network.client` (나가는 연결만). 실제 fetch는 탭이 원격 허용일 때만
- 새 타깃/프로세스 없음

근거:

- 파서: “The parser is powered by GitHub-flavored Markdown’s cmark-gfm” — https://swiftlang.github.io/swift-markdown/documentation/markdown/
- 샌드박스: 연 파일만 권한. **폴더를 연 경우에만** 하위 항목으로 확장 — https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox
- 관련 파일: `NSIsRelatedItemType` + `NSFilePresenter`/`NSFileCoordinator`로 문서 옆 지원 파일 접근 — 같은 문서
- 북마크: `bookmarkData(options: .withSecurityScope)` 후 resolve 시 `startAccessingSecurityScopedResource()` 필수 — 같은 문서
- 네트워크: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.client
- 커스텀 리소스: `WKURLSchemeHandler`는 http/https를 가로채지 못함 — https://developer.apple.com/documentation/webkit/wkurlschemehandler

## Commands

```bash
./build.sh              # Debug
./build.sh test         # xcodebuild test, arm64
./build.sh release      # Hardened Runtime
```

Xcode: `NotepadForMacOS/NotepadForMacOS.xcodeproj` · scheme `NotepadForMacOS`.

## Project Structure

기존 계층을 유지한다. 새 파일은 `NotepadForMacOS/NotepadForMacOS/` 아래 (파일시스템 동기화 그룹).

```
Models/
  MarkdownDocumentKind.swift     # .md / .markdown 판별
  PreviewDocumentKind.swift      # .html / .htm + isPreviewable
  SourceHighlightKind.swift      # md / json / xml / html / log
  MarkdownPreviewState.swift     # 창 레이아웃 + 탭별 원격 허용(메모리)
Services/
  MarkdownHTMLRenderer.swift     # AST → 안전한 HTML (이미지 src를 커스텀 스킴으로)
  HTMLPreviewSanitizer.swift     # HTML 미리보기 rewrite / script 제거
  MarkdownImageLoader.swift      # 로컬/원격 바이트. 정책 강제
  MarkdownRelatedFileAccess.swift# related-item 또는 폴더 북마크
Views/
  MarkdownPreviewView.swift      # WKWebView representable, side/full 공용
  MarkdownSourceHighlighter.swift
  MainEditorView.swift           # 전체 폭 탭바 + HSplit / 전체화면
App/
  NotepadCommands.swift          # 토글 / 전체화면 메뉴
  ExternalDocumentOpener.swift   # 기본 브라우저에서 열기
Notepad.entitlements             # network.client
en.lproj / ko.lproj              # 문자열
store/ + README + privacy        # 원격 허용 시에만 네트워크
NotepadForMacOSTests/
  MarkdownHTMLRendererTests.swift
  MarkdownImagePolicyTests.swift
  MarkdownDocumentKindTests.swift
  HTMLPreviewSanitizerTests.swift
```


`SessionStore` / `Document.content` / 인코딩 / IME 커밋 경로는 동작 변경 없음. 세션 JSON에 **폴더 북마크만** 선택 필드 추가(로컬 이미지). 원격 허용 플래그는 저장하지 않음.

## Code Style

기존 패턴: `ObservableObject` 창 상태, `@AppStorage`는 전역 취향만, 탭 상태는 `TabManager` 또는 창 `@State`.

이름 충돌 예:

```swift
import Markdown

enum MarkdownDocumentKind {
    static func isMarkdown(fileURL: URL?) -> Bool {
        guard let ext = fileURL?.pathExtension.lowercased() else { return false }
        return ext == "md" || ext == "markdown"
    }
}

// 파서 문서는 모듈 한정
let parsed = Markdown.Document(parsing: source)
```

이미지 URL은 HTML에 `https://`를 쓰지 않는다.

```html
<img src="notepad-md://img/<percent-encoded-payload>" alt="...">
```

핸들러가 payload를 풀어 로컬 경로 또는 원격 URL로 해석하고, 정책에 안 맞으면 placeholder.

## Testing Strategy

프레임워크: 기존 XCTest (`./build.sh test`).

| 레벨 | 대상 |
|------|------|
| 단위 | 확장자 판별, HTML escape, `javascript:`/`data:` 차단, 상대경로 정규화(`..`로 폴더 탈출 금지), 원격 허용 전/후, 탭 닫힘 시 원격 플래그 리셋 |
| 단위 | 로컬 상대경로가 문서 디렉터리 안으로만 resolve |
| 수동 | `TEST_MATRIX.md`에 섹션 6: 사이드/풀스크린, IME 중 미리보기 깜빡임 없음, 폴더 허용 후 이미지, 원격 버튼, `.txt` 회귀 |

커버리지 숫자 목표 없음. 새 계약은 위 단위 테스트가 막는다.

## Boundaries

**Always**

- `NSTextView`가 편집 소스. 미리보기는 읽기 전용.
- 한글 `hasMarkedText`이면 하이라이트·HTML 재생성 안 함. 커밋 후 디바운스(≈250ms).
- 생성 HTML에 `<script>` 없음. `WKWebView` JS 비활성. raw HTML 블록은 escape해서 보여 줌.
- 원격 fetch는 그 탭 `allowsRemoteImages == true`일 때만.
- `./build.sh test`가 구현 슬라이스마다 통과.

**Ask first**

- SPM 패키지 추가/버전 핀
- entitlement 추가 (이 스펙이 승인되면 `network.client`는 허가된 것으로 본다)
- 세션 매니페스트 필드 추가
- 스토어/개인정보 문구

**Never**

- 인라인 위지윅, 미리보기에서 편집
- 수식, Mermaid, 이미지 붙여넣기/번들
- 전역 원격 허용, 세션에 원격 허용 저장
- `.txt` 미리보기
- `file://` 또는 생 `https://`를 WebView에 로드
- 네트워크 서버 entitlement, 분석 SDK
- 미리보기 켜짐 상태에서 탭바 토글 아이콘을 `.fill`+`Color.accentColor`로 바꿔 투명하게 만들기

## UX

### 레이아웃

창 상태: `enum MarkdownPreviewLayout { case hidden, side, full }`  
기본값: `.hidden`.

- `.side`: 에디터 | 리사이즈 디바이더 | 미리보기. 미리보기 최소 너비 ~240pt.
- `.full`: 같은 `MarkdownPreviewView`, 에디터 숨김. 원문 편집 불가. `Esc` 또는 같은 토글 단축키 → 직전 레이아웃(`hidden`/`side`).
- 미리보기 엔진은 하나. 레이아웃만 바꿈.

`.md`가 아닌 탭이 선택되면 미리보기 크롬을 그리지 않는다. 레이아웃 값은 창에 남아, 다시 `.md`를 고르면 복귀.

### 토글
- 메뉴 View: “미리보기” / “전체 화면 미리보기”
- 단축키: `⌘⌥P` 사이드 토글, `⌘⌥↩` 전체화면 토글
- 상태바: 미리보기 가능 탭에만 Preview / Hide 버튼
- 탭바: `+` 옆 `sidebar.right`. 켜져도 같은 글리프 + 약한 배경. `.fill`+강조색 사용 금지(투명 렌더).
- 미리보기 헤더: 닫기, 전체화면, **원격 이미지(HTML은 CSS 포함) 허용**(탭별), 로컬 실패 시 **이 폴더 접근 허용**, 기본 브라우저

### 라이브 갱신

`TabManager` content 변경 → 디바운스 → HTML 재생성 → `WKWebView`에 같은 scroll 오프셋으로 교체. 조합 중이면 스킵.

### 이미지

1. 상대/`file` 경로: 문서 디렉터리 기준 resolve. `..`로 문서 폴더 밖이면 거부.
2. 접근: 관련 항목(`NSIsRelatedItemType` 이미지 UTI) 시도 → 실패 시 플레이스홀더 + 폴더 허용 버튼. 폴더 `NSOpenPanel`(시작 위치 = 문서 부모) → 디렉터리 보안 스코프 북마크를 그 문서에 저장(세션 복원 포함).
3. `http`/`https`: 기본 플레이스홀더. 그 탭에서 “원격 이미지 허용” 후에만 핸들러가 다운로드. 탭 닫힘/`closeTab`/`resetToFreshTab` 시 플래그 삭제. 같은 파일을 다시 열면 다시 끔.
4. Untitled 또는 `fileURL == nil`: 상대 로컬 이미지 불가.

### 하이라이트

`.md` 탭의 `NSTextView`에만. 제목/코드펜스/인라인코드/링크/강조. `NSLayoutManager` **temporary attributes** (맞춤법 속성과 분리). `updateNSView`가 텍스트를 다시 넣지 않는 기존 불변식 유지.

## Privacy / Store

바이너리에 outgoing network가 생긴다. 기본 동작은 여전히 로컬 전용.

반드시 고칠 문구:

- `store/privacy-policy.md` / `docs/store/privacy-policy.html` / `store/privacy-policy.html` — 원격 이미지·CSS는 사용자가 그 탭에서 허용한 뒤에만. 수집·계정·분석 없음.
- `README.md`, `store/listing-en.md`, `store/listing-ko.md`, `index.html` — “No network unless you allow remote images/CSS in a Markdown or HTML preview tab”.
- App Store 개인정보: 데이터 수집 없음 유지. 네트워크는 사용자 콘텐츠 표시.

## Success Criteria

- [x] `.txt` / Untitled: 미리보기 UI 없음. 세션·인코딩·IME·찾기 회귀 없음.
- [x] `.md` / `.html` 기본: 전체 폭 에디터.
- [x] 사이드 미리보기 열고 닫기 (메뉴, `⌘⌥P`, 탭바, 상태바). 타이핑하면 렌더 갱신. 한글 조합 중 깜빡임 없음.
- [x] 전체화면 미리보기: 소스 숨김, 편집 불가, `Esc`/토글로 복귀.
- [x] 로컬 `![](./x.png)`: 관련 항목 또는 폴더 허용 후 표시. 폴더 밖/`..` 거부.
- [x] 원격 `![](https://…)` / HTML 원격 리소스: 허용 전 차단, 허용 후 표시, 탭 닫으면 다시 차단. 스크립트 없음.
- [x] WebView가 `https://`를 직접 요청하지 않음.
- [x] 소스 하이라이트가 해당 종류에서만, 맞춤법과 공존.
- [x] 탭바 미리보기 아이콘이 패널 열린 뒤에도 보임.
- [x] `./build.sh test` 통과. 개인정보/README/listing/사이트 문구 갱신.

## Open Questions

없음.

## Implementation notes

Shipped in v1.2.0. 탭바는 창 전체 폭을 유지한다. 아이콘을 에디터 열로 옮기지 않는다.

