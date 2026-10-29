import Testing
@testable import ImmerseKit

@Suite struct WordsTests {
    @Test(.enabled("needs NaturalLanguage's Spanish dictionary forms") { await LearningLanguage.spanish.prepareDictionaryForms() })
    func spanishWordsCarryTheirDictionaryForm() {
        let tokens = LearningLanguage.spanish.tokens(in: "Hoy fui a la tienda. ¡Compré 2 panes!")
        #expect(tokens.map(\.word) == ["Hoy", "fui", "a", "la", "tienda", "Compré", "panes"])
        #expect(tokens.first { $0.word == "fui" }?.lemma == "ir")
        #expect(tokens.first { $0.word == "Compré" }?.key == "comprar")
        #expect(tokens.first { $0.word == "Hoy" }?.key == "hoy")
    }

    @Test func rangesPointBackIntoTheText() {
        let text = "Die Blumen sind schön."
        for token in LearningLanguage.german.tokens(in: text) {
            #expect(String(text[token.range]) == token.word)
        }
    }

    @Test(.enabled("needs NaturalLanguage's German dictionary forms") { await LearningLanguage.german.prepareDictionaryForms() })
    func savingOneFormFindsTheOthers() {
        let german = LearningLanguage.german
        #expect(german.tokens(in: "Ich bin müde.")[1].key == german.tokens(in: "Wir sind müde.")[1].key)
    }

    @Test func formsOfTheSameWord() {
        let spanish = LearningLanguage.spanish
        #expect(spanish.sameWord("sabroso", "sabrosa"))
        #expect(spanish.sameWord("cansado", "cansadas"))
        #expect(spanish.sameWord("quiero", "quieren"))
        #expect(spanish.sameWord("arreglado", "arreglarla"))
        #expect(!spanish.sameWord("casa", "caso"))
        #expect(!spanish.sameWord("pan", "par"))
        #expect(!LearningLanguage.vietnamese.sameWord("nhà hàng", "nhà hát"))
    }

    @Test func japaneseIsSplitIntoWords() {
        let words = LearningLanguage.japanese.tokens(in: "今日、長いシフトを終えました。").map(\.word)
        #expect(words.first == "今日")
        #expect(words.contains("シフト"))
    }

    @Test func aWordsSentence() throws {
        let text = "Hoy fui a la tienda. Compré pan para mañana. ¡Qué rico!"
        let pan = try #require(LearningLanguage.spanish.tokens(in: text).first { $0.word == "pan" })
        #expect(LearningLanguage.spanish.sentence(containing: pan.range, in: text) == "Compré pan para mañana.")
        let japanese = "今日は雨です。パンを焼きました。"
        let bread = try #require(LearningLanguage.japanese.tokens(in: japanese).first { $0.word == "パン" })
        #expect(LearningLanguage.japanese.sentence(containing: bread.range, in: japanese) == "パンを焼きました。")
    }

    @Test func changedWords() {
        let original = "Mi horno también es roto"
        let corrected = "Mi horno también está roto."
        let changes = LearningLanguage.spanish.changedWords(from: original, to: corrected)
        #expect(changes.map { String(corrected[$0]) } == ["está"])
        let french = "Moi aussi, je suis allé là-bas hier."
        #expect(LearningLanguage.french.changedWords(from: "Moi aussi j'ai allé là-bas hier", to: french).map { String(french[$0]) } == ["je", "suis"])
    }

    @Test func meaningsDontRepeatTheWord() {
        #expect(OnDeviceWriter.withoutOriginal("出勤", in: "出勤 - work, going to work") == "work, going to work")
        #expect(OnDeviceWriter.withoutOriginal("Blumen", in: "flowers") == "flowers")
        #expect(OnDeviceWriter.withoutOriginal("出勤", in: "出勤") == "出勤")
    }

    @Test func readings() {
        #expect(LearningLanguage.japanese.reading(of: "今日") == "きょう")
        #expect(LearningLanguage.japanese.reading(of: "シフト") == nil)
        #expect(LearningLanguage.chinese.reading(of: "今天") == "jīn tiān")
        #expect(LearningLanguage.korean.reading(of: "오늘") == "oneul")
        #expect(LearningLanguage.spanish.reading(of: "tienda") == nil)
    }
}
