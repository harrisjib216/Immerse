import Foundation
import FoundationModels

/// What a word means where it was used, and the sentence it was in.
public struct Meaning: Equatable, Sendable {
    public let word: String
    public let sentence: String
}

extension OnDeviceWriter {
    /// The sentence comes first, then the words in its translation that stand for the word. Asked for the word's
    /// meaning first, the model gave Japanese, Korean and Chinese words back untranslated (`出勤` for `出勤`); picking
    /// them out of a translation it has already written gives "go to work".
    @Generable
    struct InContext {
        @Guide(description: "The sentence translated naturally")
        var sentence: String
        @Guide(description: "The word or words in that translation that stand for the word asked about, one to three words")
        var word: String
    }

    /// The meaning of `word` in `sentence`, in the reader's language.
    ///
    /// A word on its own is ambiguous: the Translation framework turns `fui` into "I was" or "I went" depending on
    /// nothing. With the sentence beside it, the model picks the one that was meant, and `riego` comes back as
    /// "watering system" rather than "irrigation".
    public func meaning(of word: String, in sentence: String, from language: LearningLanguage, into reader: String) async throws -> Meaning {
        let session = LanguageModelSession(instructions: "You translate \(language.promptName) into \(reader) for someone learning the language.")
        let answer = try await session.respond(
            to: "Sentence: \(sentence)\nWord: \(word)\nTranslate the sentence into \(reader), then give the \(reader) words in it that stand for the word.", generating: InContext.self,
            options: GenerationOptions(temperature: 0)
        ).content
        return Meaning(word: Self.withoutOriginal(word, in: answer.word), sentence: answer.sentence)
    }

    /// Takes the original word out of an answer like "出勤 - going to work", which the model sometimes gives for
    /// Japanese and Korean.
    static func withoutOriginal(_ word: String, in answer: String) -> String {
        let trimmed = answer.replacingOccurrences(of: word, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—:·,()")))
        return trimmed.isEmpty ? answer : trimmed
    }

    /// `text` in the reader's language. The app uses the Translation framework for whole posts, and this where that
    /// can't run, such as in the simulator.
    public func translate(_ text: String, from language: LearningLanguage, into reader: String) async throws -> String {
        let session = LanguageModelSession(instructions: "You translate \(language.promptName) into \(reader). Translate naturally and completely.")
        return try await session.respond(to: text, generating: Draft.self, options: GenerationOptions(temperature: 0)).content.text
    }
}
