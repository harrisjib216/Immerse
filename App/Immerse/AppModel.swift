import Foundation
import FoundationModels
import ImmerseKit
import Observation

@MainActor @Observable
final class AppModel {
    private(set) var library: Library?
    private(set) var availability = OnDeviceWriter.availability
    /// Who's writing a new post right now.
    private(set) var writing: Persona?
    /// Replies to your comments as they're written, by post.
    private(set) var replies: [Post.ID: String] = [:]
    /// People writing a comment on a quiet post, by post.
    private(set) var commenting: [Post.ID: Persona] = [:]
    var failure: String?

    private let file: URL
    private var job: Task<Void, Never>?
    private var random = SystemRandomNumberGenerator()

    init(file: URL = URL.applicationSupportDirectory.appending(path: "library.json")) {
        self.file = file
        #if DEBUG
        if Demo.flag("reset") { try? FileManager.default.removeItem(at: file) }
        #endif
        library = try? JSONDecoder().decode(Library.self, from: Data(contentsOf: file))
        #if DEBUG
        if library == nil, let language = Demo.value("language").flatMap(LearningLanguage.named) {
            library = Library(language: language, level: Demo.value("level").flatMap(Level.init) ?? .a2)
        }
        #endif
    }

    private var engine: FeedEngine? {
        library.map { FeedEngine(language: $0.language, level: $0.level, writer: OnDeviceWriter()) }
    }

    /// The languages the model on this iPhone writes.
    var languages: [LearningLanguage] {
        LearningLanguage.all.filter(OnDeviceWriter.supports)
    }

    /// Where translations go: your own language, or English if your own is the one you're learning.
    var readerLanguage: Locale.Language {
        let own = Locale.current.language
        return own.languageCode == library?.language.locale.languageCode ? Locale.Language(identifier: "en") : own
    }

    /// The reader's language by name, for prompts: "English".
    var readerLanguageName: String {
        readerLanguage.languageCode.flatMap { Locale(identifier: "en").localizedString(forLanguageCode: $0.identifier) } ?? "English"
    }

    func person(_ id: String) -> Persona? {
        library.flatMap { Cast.person(id, in: $0.language) }
    }

    func checkAvailability() {
        availability = OnDeviceWriter.availability
    }

    func start(_ language: LearningLanguage, level: Level) {
        if library == nil {
            library = Library(language: language, level: level)
        } else {
            library?.change(to: language, level: level)
        }
        persist()
        restart()
    }

    func startOver() {
        library?.startOver()
        persist()
        restart()
    }

    /// Writes the first posts when the feed is empty.
    func fill() {
        guard library?.posts.isEmpty == true else { return }
        write(5)
    }

    /// Writes three new posts. They appear one at a time under the typing row.
    func refresh() {
        write(3)
    }

    /// Returns when the posts being written are done.
    func finishWriting() async {
        await job?.value
    }

    /// The posts being written belong to the model, not to the view that asked for them, so switching tabs doesn't
    /// cancel them halfway.
    private func write(_ count: Int) {
        guard job == nil, let engine else { return }
        job = Task {
            await writePosts(count, with: engine)
            job = nil
        }
    }

    /// Stops writing for the old settings and starts the feed for the new ones.
    private func restart() {
        job?.cancel()
        job = nil
        writing = nil
        fill()
    }

    private func writePosts(_ count: Int, with engine: FeedEngine) async {
        defer { writing = nil }
        for _ in 0..<count {
            guard !Task.isCancelled, let library else { return }
            let author = engine.nextAuthor(after: library.posts)
            let topic = engine.nextTopic(for: author, after: library.posts, using: &random)
            writing = author
            do {
                let post = try await engine.post(
                    by: author, about: topic, reusing: library.wordToReuse()?.prompted, after: library.posts
                )
                guard !Task.isCancelled else { return }
                self.library?.add(post)
                persist()
            } catch {
                if !Task.isCancelled { failure = Self.message(for: error) }
                return
            }
        }
    }

    /// Adds your comment, checks it against how a native speaker would say it, then streams the author's reply to
    /// what you meant.
    func comment(_ text: String, on postID: Post.ID) async {
        guard let engine else { return }
        let comment = Comment(author: .you, text: text, date: .now)
        library?.add(comment, to: postID)
        persist()
        replies[postID] = ""
        defer { replies[postID] = nil }
        if let suggestion = await engine.suggestion(for: text) {
            library?.suggest(suggestion, for: comment.id, on: postID)
            persist()
        }
        guard let post = library?.post(postID) else { return }
        do {
            var reply = ""
            for try await partial in engine.reply(to: post) {
                reply = partial
                replies[postID] = partial
            }
            guard !reply.isEmpty else { return }
            library?.add(Comment(author: .persona(post.author), text: reply, date: .now), to: postID)
            persist()
        } catch is CancellationError {
            return
        } catch {
            failure = Self.message(for: error)
        }
    }

    /// Someone else in the cast comments on a post nobody has answered yet, so there's more to read.
    func joinIfQuiet(_ postID: Post.ID) async {
        guard let engine, let post = library?.post(postID), post.comments.isEmpty, commenting[postID] == nil,
              let commenter = engine.commenter(for: post)
        else { return }
        commenting[postID] = commenter
        defer { commenting[postID] = nil }
        // A missing comment is nothing to report, so a failure here stays quiet.
        guard let comment = try? await engine.comment(on: post, by: commenter) else { return }
        library?.add(comment, to: postID)
        persist()
    }

    func toggleLike(_ post: Post.ID) {
        library?.toggleLike(post)
        persist()
    }

    func save(_ token: Token, from sentence: String, translation: String?) {
        library?.save(token, from: sentence, translation: translation)
        persist()
    }

    func forget(_ word: SavedWord.ID) {
        library?.forget(word)
        persist()
    }

    private func persist() {
        guard let library else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(library).write(to: file, options: .atomic)
        } catch {
            failure = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private static func message(for error: any Error) -> String {
        switch error {
        case EngineError.wrongLanguage:
            "The model kept answering in English. Try again."
        case let error as LanguageModelSession.GenerationError:
            switch error {
            case .guardrailViolation, .refusal: "The model wouldn't write that one. Try again."
            case .rateLimited, .concurrentRequests: "The model is busy. Try again in a moment."
            default: error.localizedDescription
            }
        default:
            error.localizedDescription
        }
    }
}
