import Foundation
import NaturalLanguage

/// A language you can learn in Immerse. Each one is written by Apple's on-device model, translated by the
/// Translation framework, and has a cast of people who live where it's spoken.
public struct LearningLanguage: Identifiable, Hashable, Sendable {
    /// A BCP 47 identifier, such as `es` or `pt-BR`.
    public let id: String
    /// How the prompts name the language. The model follows English instructions best, so this is in English.
    public let promptName: String
    /// The voice that reads posts aloud.
    public let voice: String
    let recognizerCode: String

    public static let spanish = LearningLanguage(id: "es", promptName: "Spanish as spoken in Spain", voice: "es-ES", recognizerCode: "es")
    public static let french = LearningLanguage(id: "fr", promptName: "French as spoken in France", voice: "fr-FR", recognizerCode: "fr")
    public static let german = LearningLanguage(id: "de", promptName: "German", voice: "de-DE", recognizerCode: "de")
    public static let italian = LearningLanguage(id: "it", promptName: "Italian", voice: "it-IT", recognizerCode: "it")
    public static let portuguese = LearningLanguage(id: "pt-BR", promptName: "Brazilian Portuguese", voice: "pt-BR", recognizerCode: "pt")
    public static let japanese = LearningLanguage(id: "ja", promptName: "Japanese", voice: "ja-JP", recognizerCode: "ja")
    public static let korean = LearningLanguage(id: "ko", promptName: "Korean", voice: "ko-KR", recognizerCode: "ko")
    public static let chinese = LearningLanguage(id: "zh-Hans", promptName: "Mandarin Chinese in simplified characters", voice: "zh-CN", recognizerCode: "zh-Hans")
    public static let dutch = LearningLanguage(id: "nl", promptName: "Dutch as spoken in the Netherlands", voice: "nl-NL", recognizerCode: "nl")
    public static let turkish = LearningLanguage(id: "tr", promptName: "Turkish", voice: "tr-TR", recognizerCode: "tr")
    public static let vietnamese = LearningLanguage(id: "vi", promptName: "Vietnamese", voice: "vi-VN", recognizerCode: "vi")

    public static let all: [LearningLanguage] = [
        .spanish, .french, .german, .italian, .portuguese, .japanese, .korean, .chinese, .dutch, .turkish, .vietnamese,
    ]

    public static func named(_ id: String) -> LearningLanguage? {
        all.first { $0.id == id }
    }

    public var locale: Locale.Language { Locale.Language(identifier: id) }

    /// The language's name in itself: "Español", "日本語".
    public var nativeName: String {
        let own = Locale(identifier: id)
        return own.localizedString(forIdentifier: id)?.capitalized(with: own) ?? id
    }

    /// The language's name in the reader's language: "Spanish".
    public func name(in locale: Locale = .current) -> String {
        locale.localizedString(forIdentifier: id) ?? promptName
    }

    var naturalLanguage: NLLanguage { NLLanguage(rawValue: recognizerCode) }

    /// Whether `text` reads as this language rather than English.
    ///
    /// The on-device model sometimes drifts into English, or translates its own post at the end. That's the
    /// failure worth catching, so the recognizer only chooses between this language and English. Telling Spanish
    /// from Portuguese in a two-sentence post is where it's least reliable, and the model doesn't make that mistake.
    public func wrote(_ text: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [naturalLanguage, .english]
        recognizer.processString(text)
        return recognizer.dominantLanguage == naturalLanguage
    }
}
