#if DEBUG
import ImmerseKit
import SwiftUI

/// Launch arguments that walk the app to a screen, for the README's screenshots:
///
///     -demo-reset -demo-language es -demo-level a2    start a fresh feed
///     -demo-save 2,6                                  save those words from the first post
///     -demo-refresh                                   then write three more posts
///     -demo-word 3                                    open a word in the first post
///     -demo-thread -demo-reply "Yo también…"          open the first post and reply
///     -demo-tab words                                 start on the Words tab
enum Demo {
    static func value(_ name: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-demo-\(name)"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    static func flag(_ name: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains("-demo-\(name)")
    }

    /// Saves words and writes more posts once the first ones are in.
    @MainActor
    static func prepare(_ model: AppModel) async {
        guard let first = await firstPost(model).flatMap({ model.library?.post($0) }), let language = model.library?.language else { return }
        if let indices = value("save")?.split(separator: ",").compactMap({ Int($0) }) {
            let tokens = language.tokens(in: first.text)
            for index in indices where tokens.indices.contains(index) {
                let token = tokens[index]
                let sentence = language.sentence(containing: token.range, in: first.text)
                let meaning = try? await OnDeviceWriter().meaning(of: token.word, in: sentence, from: language, into: model.readerLanguageName)
                model.save(token, from: sentence, translation: meaning?.word)
            }
        }
        if flag("refresh") {
            model.refresh()
            await model.finishWriting()
        }
    }

    /// The newest post, once the feed has finished its first posts.
    @MainActor
    static func firstPost(_ model: AppModel) async -> Post.ID? {
        try? await Task.sleep(for: .milliseconds(300))
        await model.finishWriting()
        return model.library?.posts.first?.id
    }
}
#endif
