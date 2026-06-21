import SwiftUI

struct GoToLineSheet: View {
    @State private var lineNumber: String = ""
    var onGoTo: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Go to Line")
                .font(.headline)

            TextField("Line number", text: $lineNumber)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    go()
                }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Go") {
                    go()
                }
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 260)
    }

    private func go() {
        if let num = Int(lineNumber), num > 0 {
            onGoTo(num)
        }
        dismiss()
    }
}
