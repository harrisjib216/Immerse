import ImmerseKit
import SwiftUI

/// Text where every word opens the word sheet.
///
/// Each word is a link in an `AttributedString`, and the `openURL` action catches the tap. That keeps it one `Text`,
/// so it wraps, scales with Dynamic Type and lays out Japanese and Chinese the way the system does, which a row of
/// buttons per word can't.
struct TappableText: View {
    let text: String
    let language: LearningLanguage

    @Environment(AppModel.self) private var model
    @State private var tokens: (text: String, tokens: [Token]) = ("", [])
    @State private var tapped: TappedWord?

    var body: some View {
        Text(attributed)
            .tint(.primary)
            .environment(\.openURL, OpenURLAction { url in
                if let index = Int(url.lastPathComponent), tokens.tokens.indices.contains(index) {
                    open(tokens.tokens[index])
                }
                return .handled
            })
            .task(id: text) {
                tokens = (text, language.tokens(in: text))
                #if DEBUG
                if text == model.library?.posts.first?.text, let index = Demo.value("word").flatMap(Int.init),
                   tokens.tokens.indices.contains(index) {
                    try? await Task.sleep(for: .seconds(1))
                    open(tokens.tokens[index])
                }
                #endif
            }
            .sheet(item: $tapped) { word in
                WordSheet(word: word, language: language)
            }
    }

    private func open(_ token: Token) {
        tapped = TappedWord(token: token, sentence: language.sentence(containing: token.range, in: text))
    }

    private var attributed: AttributedString {
        var string = AttributedString(text)
        // Tokens from an older version of the text would point at the wrong characters.
        guard tokens.text == text else { return string }
        for (index, token) in tokens.tokens.enumerated() {
            guard let range = Range(token.range, in: string) else { continue }
            string[range].link = URL(string: "immerse://word/\(index)")
            if token == tapped?.token {
                string[range].backgroundColor = Color.secondary.opacity(0.25)
            } else if model.library?.saved(token) != nil {
                string[range].backgroundColor = Color.yellow.opacity(0.35)
            }
        }
        return string
    }
}

struct TappedWord: Identifiable {
    let id = UUID()
    let token: Token
    let sentence: String
}
