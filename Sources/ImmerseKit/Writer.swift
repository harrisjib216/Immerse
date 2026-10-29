import FoundationModels

/// Something that writes text from instructions and a prompt. The app uses the on-device model; the tests use a
/// writer that answers from a script.
public protocol Writer: Sendable {
    func write(_ prompt: String, instructions: String) async throws -> String
    /// The text so far, each time it grows.
    func stream(_ prompt: String, instructions: String) -> AsyncThrowingStream<String, any Error>
    /// `text` the way a native speaker would say it, or `text` itself if it was already right. `isWoman` says who
    /// wrote it, where that's known, since French, Spanish, Italian and Portuguese agree words with the speaker.
    func correct(_ text: String, in language: LearningLanguage, isWoman: Bool?) async throws -> String
}

/// Writes with Apple's on-device foundation model. Nothing leaves the device, and there's no account or key.
public struct OnDeviceWriter: Writer {
    public init() {}

    /// Guided generation with a single field keeps the model from wrapping the post in "Sure! Here's a post:" or
    /// in quotation marks.
    @Generable
    struct Draft {
        @Guide(description: "Only the text itself, in the language you were told to write in")
        var text: String
    }

    /// The longest post, at C1 in French, is about 200 tokens. The limit stops the rare reply that repeats itself
    /// until the context window is full.
    private let options = GenerationOptions(temperature: 0.8, maximumResponseTokens: 400)

    public func write(_ prompt: String, instructions: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        return try await session.respond(to: prompt, generating: Draft.self, options: options).content.text
    }

    public func stream(_ prompt: String, instructions: String) -> AsyncThrowingStream<String, any Error> {
        let options = options
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let session = LanguageModelSession(instructions: instructions)
                    for try await snapshot in session.streamResponse(to: prompt, generating: Draft.self, options: options) {
                        if let text = snapshot.content.text { continuation.yield(text) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @Generable
    struct Rewrite {
        @Guide(description: "The comment rewritten the way a native speaker would say it. Identical if it was already correct.")
        var text: String
        @Guide(description: "Whether the original comment had a grammar, spelling or agreement mistake. Style and word choice are not mistakes.")
        var hadMistake: Bool
    }

    /// Rewrites a learner's comment the way a native speaker would say it.
    ///
    /// Tried on 16 comments while building this, the rewrite fixed all 8 that had a mistake (`es roto` → `está roto`,
    /// `gusta` → `me gusta`, `j'ai allé` → `je suis allé`) and left 7 of the 8 correct ones alone. The eighth came back
    /// reworded for style, which is why the app says a native speaker "might say" it.
    ///
    /// `hadMistake` came back false for all 8 mistakes, even while the rewrite fixed them, so the app goes by whether
    /// the words changed. The field stays because the rewrites were more conservative with it there.
    public func correct(_ text: String, in language: LearningLanguage, isWoman: Bool?) async throws -> String {
        let session = LanguageModelSession(instructions: "You are a native speaker of \(language.promptName) who helps learners.")
        let writer = isWoman.map { " The writer is a \($0 ? "woman" : "man"), so words describing the writer agree with that." } ?? ""
        return try await session.respond(
            to: "A learner wrote this comment in \(language.promptName).\(writer)\n\(text)", generating: Rewrite.self,
            options: GenerationOptions(temperature: 0, maximumResponseTokens: 200)
        ).content.text
    }

    /// Whether this device can run the model, and why not.
    public static var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    /// The languages the model on this device writes.
    public static func supports(_ language: LearningLanguage) -> Bool {
        SystemLanguageModel.default.supportedLanguages.contains { $0.languageCode == language.locale.languageCode }
    }

    /// Loads the model ahead of the first post, so the feed starts sooner.
    public static func prewarm() {
        LanguageModelSession().prewarm()
    }
}
