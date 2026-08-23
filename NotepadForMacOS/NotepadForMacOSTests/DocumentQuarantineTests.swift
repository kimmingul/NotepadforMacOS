import XCTest
@testable import Notepad

/// 문서를 **여는** 동작이 파일을 건드리지 않는지 지키는 회귀 테스트.
///
/// 배경: 예전에는 문서를 열 때 `URL.bookmarkData(options: [.withSecurityScope])`로
/// 쓰기 가능 보안 스코프 북마크를 만들었다. 그 API는 쓰기 확장 토큰을 얻기 위해 대상 파일을
/// `open(O_RDWR)`로 열고, App Sandbox는 그 쓰기 의도 open에 `com.apple.quarantine`을
/// 전파한다. 내용은 바뀌지 않으므로 mtime은 그대로인데 격리 속성만 붙어, 그 뒤로 Finder에서
/// 파일을 열 때마다 (Notepad든 TextEdit이든) Gatekeeper 문서 검사 대화상자가 떴다.
///
/// 주의: 테스트 호스트도 샌드박스 앱이라 여기서 **새로 만든** 파일에는 macOS가
/// `com.apple.quarantine`을 붙이고, 샌드박스 안에서는 그 속성을 제거할 수 없다. 그래서 이
/// 테스트들은 "속성이 없다"가 아니라 **여는 동작이 파일을 전혀 건드리지 않는다**(격리 기록과
/// mtime이 그대로)를 검증한다. 격리가 애초에 붙지 않는다는 증명은 샌드박스 밖에서 기준선을
/// 만들 수 있는 실제 앱 바이너리 테스트로 수행한다.
@MainActor
final class DocumentQuarantineTests: XCTestCase {

    private func makeTempFile(_ contents: String, ext: String = "txt") throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("qtn-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("sample.\(ext)")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func quarantineValue(of url: URL) -> String? {
        url.withUnsafeFileSystemRepresentation { path -> String? in
            guard let path else { return nil }
            let size = getxattr(path, "com.apple.quarantine", nil, 0, 0, 0)
            guard size > 0 else { return nil }
            var buffer = [UInt8](repeating: 0, count: size)
            guard getxattr(path, "com.apple.quarantine", &buffer, size, 0, 0) == size else { return nil }
            return String(decoding: buffer, as: UTF8.self)
        }
    }

    private func modificationDate(of url: URL) throws -> Date {
        try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date ?? .distantPast
    }

    /// 열기만 했을 때: 격리 기록과 mtime이 모두 그대로여야 한다.
    /// (쓰기 의도 open이 되살아나면 격리 기록이 새로 찍히거나 갱신된다.)
    func testOpeningDocumentDoesNotTouchFile() throws {
        let url = try makeTempFile("열기 전용 확인\n")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let quarantineBefore = quarantineValue(of: url)
        let mtimeBefore = try modificationDate(of: url)

        let manager = TabManager(sessionID: UUID())

        XCTAssertTrue(manager.openFile(url: url))
        XCTAssertEqual(manager.selectedTab?.content, "열기 전용 확인\n")

        XCTAssertEqual(
            quarantineValue(of: url),
            quarantineBefore,
            "문서를 읽기만 했는데 격리 기록이 변했다 — 쓰기 모드 open이 되살아났다"
        )
        XCTAssertEqual(try modificationDate(of: url), mtimeBefore, "읽기만 했는데 mtime이 변했다")
    }

    /// 여는 시점의 북마크는 읽기 전용이어야 한다(쓰기 토큰을 만들면 격리가 전파된다).
    func testOpenCreatesReadOnlyBookmark() throws {
        let url = try makeTempFile("북마크 권한 확인\n")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let manager = TabManager(sessionID: UUID())
        XCTAssertTrue(manager.openFile(url: url))

        let tab = try XCTUnwrap(manager.selectedTab)
        XCTAssertNotNil(tab.securityScopedBookmark, "재실행 후 읽기 위해 북마크는 있어야 한다")
        XCTAssertFalse(tab.bookmarkAllowsWriting, "여는 시점 북마크는 읽기 전용이어야 한다")
    }

    /// 저장할 때만 실제로 파일이 바뀌고, 그때 쓰기 가능 북마크로 승급된다.
    func testSaveWritesContentAndUpgradesBookmark() throws {
        let url = try makeTempFile("원본\n")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let manager = TabManager(sessionID: UUID())
        XCTAssertTrue(manager.openFile(url: url))
        let id = try XCTUnwrap(manager.selectedTabID)

        manager.updateContent(for: id, newContent: "수정된 내용\n")
        XCTAssertEqual(manager.saveTab(id), .saved)

        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "수정된 내용\n")

        let tab = try XCTUnwrap(manager.document(with: id))
        XCTAssertFalse(tab.isDirty)
        XCTAssertTrue(tab.bookmarkAllowsWriting, "저장 성공 후에는 쓰기 가능 북마크로 승급되어야 한다")
    }

    /// 쓸 수 없는 위치로 저장하면 `.notAuthorized`가 나와야 한다.
    /// (호출 측이 이 값을 보고 재승인 저장 패널을 띄운다.)
    func testSaveToUnwritableLocationReportsNotAuthorized() throws {
        let manager = TabManager(sessionID: UUID())
        manager.newTab(content: "권한 없는 위치\n")
        let id = try XCTUnwrap(manager.selectedTabID)

        // 시스템 볼륨 루트는 샌드박스와 SIP 양쪽에서 막혀 있다.
        let blocked = URL(fileURLWithPath: "/qtn-not-writable-\(UUID().uuidString).txt")
        XCTAssertEqual(manager.saveTab(id, to: blocked), .notAuthorized)

        let tab = try XCTUnwrap(manager.document(with: id))
        XCTAssertNil(tab.fileURL, "실패한 저장이 탭의 경로를 바꾸면 안 된다")
        XCTAssertTrue(tab.isDirty, "실패한 저장은 dirty 상태를 유지해야 한다")
    }

    /// 대상 인코딩으로 표현할 수 없는 문자는 권한 문제와 구분되어야 한다.
    /// (이쪽은 패널이 아니라 경고를 띄워야 한다.)
    func testUnrepresentableCharactersReportEncodingFailure() throws {
        let url = try makeTempFile("원본\n")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let manager = TabManager(sessionID: UUID())
        XCTAssertTrue(manager.openFile(url: url))
        let id = try XCTUnwrap(manager.selectedTabID)

        manager.updateContent(for: id, newContent: "이모지 😀 는 EUC-KR로 표현할 수 없다\n")
        XCTAssertEqual(manager.saveTab(id, encoding: .eucKR), .encodingFailed)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "원본\n", "실패한 저장이 파일을 건드리면 안 된다")
    }

    /// 세션 복원은 북마크의 쓰기 권한 여부를 그대로 유지해야 한다.
    /// (읽기 전용이 쓰기 가능으로 넓어지면 복원 읽기에서 다시 격리가 전파된다.)
    func testSessionRoundtripPreservesReadOnlyBookmarkFlag() throws {
        let url = try makeTempFile("복원 확인\n")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = SessionStore.shared
        store.shouldRestorePreviousSession = true
        let sessionID = UUID()
        defer { store.clearSession(sessionID: sessionID) }

        var doc = Document(fileURL: url, content: "복원 확인\n")
        doc.securityScopedBookmark = SecurityScopedFile.makeBookmark(for: url, readOnly: true)
        doc.bookmarkAllowsWriting = false

        store.saveSession(tabs: [doc], selectedID: doc.id, sessionID: sessionID)
        let (restored, _) = store.loadSession(sessionID: sessionID)

        let tab = try XCTUnwrap(restored.first)
        XCTAssertFalse(tab.bookmarkAllowsWriting, "읽기 전용 북마크가 복원 후 쓰기 가능으로 바뀌었다")
        XCTAssertEqual(tab.fileURL?.standardizedFileURL, url.standardizedFileURL)
    }
}
