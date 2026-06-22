# Notepad for macOS — 빌드 & 배포

이 저장소는 완성된 Xcode 프로젝트를 포함합니다. 예전 문서에 있던 "새 프로젝트를 만들고 파일을 드래그" 하는 단계는 더 이상 필요 없습니다. 클론 후 바로 빌드하세요.

## 요구 사항
- macOS (Apple Silicon), Xcode 26 이상
- 커맨드라인 도구 (`xcodebuild`, `sips`, `iconutil`, `hdiutil`)

## 빠른 시작

```bash
git clone <repo> notepad_macOS
cd notepad_macOS

./build.sh            # Debug 빌드
./build.sh release    # Release 빌드 (Hardened Runtime)
./build.sh test       # 단위 테스트 실행
./build.sh dist       # 배포용 dist/Notepad.dmg 생성
./build.sh open       # Xcode에서 열기
./build.sh clean      # 빌드 산출물 정리
```

Xcode에서 작업하려면 `NotepadForMacOS/NotepadForMacOS.xcodeproj`를 열고 `Cmd+R`(실행) / `Cmd+U`(테스트).

## 프로젝트 레이아웃

소스와 리소스는 모두 `NotepadForMacOS/NotepadForMacOS/` 안에 있으며, Xcode의 **파일 시스템 동기화 그룹**으로 타깃에 자동 포함됩니다. 새 `.swift` 파일을 해당 폴더(또는 하위 폴더)에 넣기만 하면 빌드에 포함됩니다 — `project.pbxproj`를 수동 편집할 필요가 없습니다.

```
NotepadForMacOS/NotepadForMacOS/
  App/         # @main, AppDelegate, 메뉴 명령, 문서 동작
  Models/      # Document, LineEnding, TextEncoding
  ViewModels/  # TabManager
  Services/    # SessionStore, SecurityScopedFile
  Views/       # 에디터/탭/상태바/시트/설정 뷰
  Assets.xcassets, en.lproj, ko.lproj, Credits.rtf, LICENSE
```

테스트는 `NotepadForMacOS/NotepadForMacOSTests/` 에 있으며 같은 방식으로 자동 포함됩니다.

## 샌드박스 / 엔타이틀먼트

앱은 App Sandbox를 사용하며 엔타이틀먼트는 `NotepadForMacOS/Notepad.entitlements`에 명시되어 있습니다:
- `com.apple.security.app-sandbox`
- `com.apple.security.files.user-selected.read-write` — 사용자가 연 파일에 저장 허용
- `com.apple.security.files.bookmarks.app-scope` — 재실행 후 접근을 위한 보안 스코프 북마크

Release는 `ENABLE_HARDENED_RUNTIME=YES`, `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`로 빌드되어 `get-task-allow`가 포함되지 않습니다(배포 적합).

## 배포

배포 경로는 둘이며, **서로 다른 인증서**를 씁니다. 헷갈리기 쉬우니 먼저 용어를 정리합니다.

| 인증서 종류 | 용도 | 어디에 쓰나 |
|---|---|---|
| **Apple Development** | 개발/디버깅(내 기기에서 실행) | 평소 `Cmd+R` 빌드 |
| **Apple Distribution** + **Mac Installer Distribution** | **Mac App Store** 제출 | `./build.sh appstore` |
| **Developer ID Application** | **App Store 밖** 직접 배포(공증+DMG) | `./build.sh dist` |

> Apple Developer Program(연 $99) 멤버십이 활성화돼 있어야 위 인증서를 발급할 수 있습니다.
> "Apple Development ID"는 보통 이 멤버십 가입을 뜻하며, 배포용 인증서(위 2·3번)는 별도로 발급해야 합니다.

### A. Mac App Store (`./build.sh appstore`)

준비(각 1회):
1. **인증서**: Xcode → Settings → Accounts → 계정 추가 → **Manage Certificates** →
   `+`로 **Apple Distribution**, **Mac Installer Distribution** 생성. (계정이 로그인돼 있어야
   `-allowProvisioningUpdates`가 프로비저닝 프로파일을 자동 생성합니다.)
2. **App Store Connect**에 앱 레코드 생성: Bundle ID `com.nanumspace.mgkim.NotepadForMacOS` 등록,
   고유한 **앱 이름**(스토어에 "Notepad"는 이미 있을 가능성이 큼 → 예: "MG Notepad"),
   카테고리·개인정보·스크린샷 입력.
3. **업로드 인증**(택1):
   - App Store Connect API 키(권장, 2FA 없음): Users and Access → Integrations → API 키 생성 →
     `AuthKey_XXXX.p8`를 `~/.appstoreconnect/private_keys/`에 저장. `ASC_KEY_ID`, `ASC_ISSUER_ID` 확보.
   - 또는 app-specific password: appleid.apple.com에서 발급 → `ASC_APPLE_ID`, `ASC_APP_PASSWORD`.

실행:
```bash
export APPSTORE_TEAM_ID="ABCDE12345"          # developer.apple.com → Membership
export ASC_KEY_ID="XXXXXXXXXX"                # (API 키 방식일 때)
export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
./build.sh appstore
```
→ Release 아카이브 → `dist/appstore/Notepad.pkg` export → App Store Connect 업로드.
업로드 인증 변수를 안 주면 `.pkg`까지만 만들고 다음 단계를 안내합니다.
업로드 후 App Store Connect에서 빌드 선택 → 메타데이터 확인 → **심사 제출**.

### B. Developer ID — App Store 밖 직접 배포 (`./build.sh dist`)

1. 한 번만: 공증 자격 증명을 keychain 프로파일로 저장
   ```bash
   xcrun notarytool store-credentials notary-profile \
     --apple-id "you@example.com" --team-id TEAMID --password "app-specific-pw"
   ```
2. 환경 변수를 설정하고 `dist` 실행
   ```bash
   export DEVID_APP="Developer ID Application: Your Name (TEAMID)"
   export NOTARY_PROFILE="notary-profile"
   ./build.sh dist
   ```
   → Developer ID로 서명 → `dist/Notepad.dmg` 생성 → 공증 → 스테이플.

환경 변수가 없으면 애드혹 서명 dmg만 만들고 다음 단계를 안내합니다(다른 Mac에서는 Gatekeeper 경고가 날 수 있음).

## 세션 복원 수동 테스트
1. 앱 실행 → 여러 탭에 내용 입력(저장하지 않음)
2. `Cmd+Q`로 종료 → 다시 실행 → 내용이 그대로 복원되는지 확인
3. (권장) Mac 재부팅 후에도 복원되는지 확인
4. EUC-KR: 레거시 `.txt`를 열고 상태바 인코딩 메뉴에서 "EUC-KR로 다시 열기" 확인
