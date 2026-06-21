import SwiftUI

struct FindReplaceSheet: View {
    @Binding var findText: String
    @Binding var replaceText: String

    var onFind: (String, Bool) -> Void   // text, matchCase
    var onReplace: (String, String, Bool) -> Void
    var onReplaceAll: (String, String, Bool) -> Void

    @State private var matchCase: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find / Replace")
                .font(.headline)

            TextField("Find", text: $findText)
                .textFieldStyle(.roundedBorder)

            TextField("Replace with", text: $replaceText)
                .textFieldStyle(.roundedBorder)

            Toggle("Match case", isOn: $matchCase)

            HStack {
                Button("Find") {
                    if !findText.isEmpty {
                        onFind(findText, matchCase)
                    }
                }
                .keyboardShortcut(.return, modifiers: [])

                Button("Replace") {
                    if !findText.isEmpty {
                        onReplace(findText, replaceText, matchCase)
                    }
                }

                Button("Replace All") {
                    if !findText.isEmpty {
                        onReplaceAll(findText, replaceText, matchCase)
                    }
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 380)
    }
}
