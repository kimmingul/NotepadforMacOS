import SwiftUI

/// Windows 11 Notepad 스타일의 **비모달** 인라인 찾기/바꾸기 막대.
/// 에디터 위에 표시되며 편집을 막지 않는다. 방향 탐색(▲▼), 대/소문자 구분,
/// 둘러 찾기(wrap), 일치 개수, 바꾸기 토글을 제공한다.
struct FindBarView: View {
    @Binding var findText: String
    @Binding var replaceText: String
    @Binding var matchCase: Bool
    @Binding var wrapAround: Bool
    @Binding var showReplace: Bool

    let matchCount: Int

    var onFindNext: () -> Void
    var onFindPrevious: () -> Void
    var onReplace: () -> Void
    var onReplaceAll: () -> Void
    var onClose: () -> Void

    @FocusState private var findFieldFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Button {
                    showReplace.toggle()
                } label: {
                    Image(systemName: showReplace ? "chevron.down" : "chevron.right")
                        .frame(width: 14)
                }
                .buttonStyle(.borderless)
                .help(String(localized: "Toggle Replace"))

                TextField(String(localized: "Find"), text: $findText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 160)
                    .focused($findFieldFocused)
                    .onSubmit { onFindNext() }

                Text(matchCountLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 70, alignment: .leading)

                Button(action: onFindPrevious) { Image(systemName: "chevron.up") }
                    .buttonStyle(.borderless)
                    .disabled(findText.isEmpty)
                    .help(String(localized: "Find Previous"))

                Button(action: onFindNext) { Image(systemName: "chevron.down") }
                    .buttonStyle(.borderless)
                    .disabled(findText.isEmpty)
                    .help(String(localized: "Find Next"))

                Toggle(String(localized: "Match case"), isOn: $matchCase)
                    .toggleStyle(.checkbox)
                Toggle(String(localized: "Wrap around"), isOn: $wrapAround)
                    .toggleStyle(.checkbox)

                Spacer(minLength: 8)

                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.cancelAction)
                    .help(String(localized: "Done"))
            }

            if showReplace {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right").frame(width: 14).opacity(0) // 정렬 맞춤
                    TextField(String(localized: "Replace with"), text: $replaceText)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 160)
                        .onSubmit { onReplace() }
                    Button(String(localized: "Replace"), action: onReplace)
                        .disabled(findText.isEmpty)
                    Button(String(localized: "Replace All"), action: onReplaceAll)
                        .disabled(findText.isEmpty)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
        .onAppear { findFieldFocused = true }
    }

    private var matchCountLabel: String {
        if findText.isEmpty { return "" }
        if matchCount == 0 { return String(localized: "No results") }
        return String(format: String(localized: "%d matches"), matchCount)
    }
}
