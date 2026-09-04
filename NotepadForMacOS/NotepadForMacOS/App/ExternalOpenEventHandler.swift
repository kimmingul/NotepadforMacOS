import AppKit

/// Finder / Dock / 기본 앱으로 들어오는 문서 열기 이벤트(`kAEOpenDocuments`)를 직접 받는다.
///
/// SwiftUI `WindowGroup`은 외부 문서 열기 이벤트에 **새 창을 만들어** 응답한다. 이 앱은 다중
/// 탭이므로 실행 중에 파일을 열면 창이 아니라 탭이 늘어야 한다.
///
/// 창 생성이 프레임워크 쪽 동작이라는 것은 실측으로 확인했다: 이 앱이 아예 열지 않는 타입
/// (`OpenableDocumentType`이 걸러내는 `.png`)을 Finder에서 Notepad로 열어도 탭은 생기지 않고
/// 창만 하나 늘었다. 즉 `ExternalDocumentOpener`의 라우팅을 어떻게 고쳐도 창은 계속 생긴다.
/// 그래서 이벤트 자체를 우리가 받아 `NSApplication`/SwiftUI 경로로 넘기지 않는다.
///
/// 설치 시점: `applicationWillFinishLaunching`(그리고 안전하게 `applicationDidFinishLaunching`에서
/// 한 번 더). SwiftUI보다 먼저 받아야 콜드 런치에서도 프레임워크가 창을 만들지 않는다.
///
/// 그 대가로 문서로 콜드 런치되면 창이 하나도 만들어지지 않는다 — SwiftUI는 문서 런치에서는
/// 기본 창을 만들지 않고 문서 열기 이벤트가 창을 만들기를 기대하기 때문이다(실측: 프로세스는
/// 살아 있고 창 0개). 그 경우는 `EditorWindowOpener`가 앱 자신에게 reopen을 보내 기본 창을
/// 만들고, 창이 붙는 순간 대기 중인 문서가 그 창으로 들어간다.
///
/// 첫 창이 뜬 뒤에 설치하는 방식은 콜드 런치에서 창이 2~3개 생겨(사용자 보고) 철회했다:
/// 이벤트가 이미 SwiftUI에 넘어가 창을 하나 더 만든 뒤였다.
final class ExternalOpenEventHandler: NSObject {
    static let shared = ExternalOpenEventHandler()

    /// 같은 핸들러를 다시 설치해도 무해하다(마지막 설치가 이긴다). 실행 단계마다 호출해
    /// AppKit/SwiftUI가 나중에 자기 핸들러로 덮어쓰더라도 우리가 다시 잡는다.
    func install() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocuments(_:withReply:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )
    }

    @objc
    private func handleOpenDocuments(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        ExternalDocumentOpener.enqueue(ExternalOpenEventHandler.fileURLs(in: event))
    }

    /// odoc 이벤트의 직접 객체에서 파일 URL을 꺼낸다.
    ///
    /// 항목은 alias / bookmark / file URL 등 여러 형태로 올 수 있어 `typeFileURL`로 강제
    /// 변환한다. 변환된 데이터는 UTF-8 URL 문자열이다.
    private static func fileURLs(in event: NSAppleEventDescriptor) -> [URL] {
        guard let list = event.paramDescriptor(forKeyword: keyDirectObject) else { return [] }

        // 항목이 하나면 리스트로 오지 않고 서술자 자체가 그 항목인 경우가 있다.
        guard list.numberOfItems > 0 else {
            return [url(from: list)].compactMap { $0 }
        }

        var urls: [URL] = []
        for index in 1...list.numberOfItems {
            guard let item = list.atIndex(index), let url = url(from: item) else { continue }
            urls.append(url)
        }
        return urls
    }

    private static func url(from descriptor: NSAppleEventDescriptor) -> URL? {
        guard let coerced = descriptor.coerce(toDescriptorType: DescType(typeFileURL)),
              let string = String(data: coerced.data, encoding: .utf8) else { return nil }
        return URL(string: string)
    }
}
