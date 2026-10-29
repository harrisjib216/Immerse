import FoundationModels
import Testing
@testable import ImmerseKit

/// Runs against the real on-device model, where there is one. GitHub's runners don't have Apple Intelligence, so
/// these are skipped there.
@Suite(.enabled(if: SystemLanguageModel.default.isAvailable))
struct LiveTests {
    @Test(arguments: [LearningLanguage.spanish, .japanese, .german])
    func writesAPostInTheLanguage(_ language: LearningLanguage) async throws {
        let engine = FeedEngine(language: language, level: .a2, writer: OnDeviceWriter())
        let post = try await engine.post(by: engine.cast[2], about: Topic.all[0])
        #expect(language.wrote(post.text))
        #expect(!post.text.contains("#"))
    }
}

@Suite(.enabled(if: SystemLanguageModel.default.isAvailable))
struct LiveMeaningTests {
    @Test func aWordMeansWhatItMeansInItsSentence() async throws {
        let meaning = try await OnDeviceWriter().meaning(
            of: "estropeó", in: "Hoy temprano, el horno se estropeó y el pan salió raro.", from: .spanish, into: "English"
        )
        #expect(meaning.word.lowercased().contains("broke"))
        #expect(meaning.sentence.lowercased().contains("oven"))
    }

    @Test func japaneseWordsComeBackTranslated() async throws {
        let meaning = try await OnDeviceWriter().meaning(of: "出勤", in: "早く出勤します。", from: .japanese, into: "English")
        #expect(meaning.word.lowercased().contains("work"))
    }

    @Test(arguments: [
        (LearningLanguage.spanish, "Mi horno también es roto", "está"),
        (.spanish, "Yo también gusta mucho la lluvia", "me"),
        (.french, "Moi aussi j'ai allé là-bas hier", "suis"),
    ])
    func learnerMistakesAreFixed(_ language: LearningLanguage, _ comment: String, _ fix: String) async throws {
        let engine = FeedEngine(language: language, level: .a2, writer: OnDeviceWriter())
        let suggestion = try #require(await engine.suggestion(for: comment))
        #expect(language.changedWords(from: comment, to: suggestion).map { String(suggestion[$0]) }.contains(fix))
    }

    @Test(arguments: [
        (LearningLanguage.spanish, "A mí también me gusta la lluvia, pero no el frío."),
        (.german, "Ich liebe Tomaten aus dem Garten!"),
    ])
    func correctCommentsAreLeftAlone(_ language: LearningLanguage, _ comment: String) async {
        let engine = FeedEngine(language: language, level: .a2, writer: OnDeviceWriter())
        #expect(await engine.suggestion(for: comment) == nil)
    }
}

@Suite(.enabled(if: SystemLanguageModel.default.isAvailable))
struct LivePolishTests {
    @Test func postsAgreeWithWhoWroteThem() async throws {
        let irene = try #require(Cast.person("musician", in: .spanish))
        let engine = FeedEngine(language: .spanish, level: .a2, writer: OnDeviceWriter())
        let polished = await engine.polished("Hoy estuve ocupado limpiando los discos porque llovía mucho.", by: irene, keeping: "ocupado")
        #expect(polished.contains("ocupada"))
    }
}
