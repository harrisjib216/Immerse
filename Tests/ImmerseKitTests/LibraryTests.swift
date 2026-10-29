import Foundation
import Testing
@testable import ImmerseKit

@Suite struct LibraryTests {
    @Test(.enabled("needs NaturalLanguage's Spanish dictionary forms") { await LearningLanguage.spanish.prepareDictionaryForms() })
    func savedWordsNoticeWhenTheyComeBack() throws {
        var library = Library(language: .spanish, level: .a2)
        library.add(.by("nurse", "Hoy fui a la tienda."))
        let fui = try #require(LearningLanguage.spanish.tokens(in: "Hoy fui a la tienda.").first { $0.word == "fui" })
        library.save(fui, from: "Hoy fui a la tienda.", translation: "I went")

        library.add(.by("runner", "Mañana vamos a correr."))
        library.add(.by("baker", "Ayer fuimos al cine."))
        let word = try #require(library.currentWords.first)
        #expect(word.sightings.map(\.author) == ["runner", "baker"])
        #expect(word.prompted == "ir")
        #expect(library.saved(fui) != nil)
    }

    @Test func anotherFormOfASavedWordCounts() throws {
        var library = Library(language: .spanish, level: .a2)
        let sabroso = try #require(LearningLanguage.spanish.tokens(in: "Pan caliente y sabroso.").last)
        library.save(sabroso, from: "Pan caliente y sabroso.", translation: "tasty")
        library.add(.by("musician", "La comida era sabrosa y muy rica."))
        #expect(library.currentWords[0].sightings.count == 1)
    }

    @Test func aSavedWordComesBackAfterTwoPostsWithoutIt() {
        var library = Library(language: .spanish, level: .a2)
        let start = Date.now
        func post(_ text: String, minutes: Double) {
            library.add(Post(author: "nurse", text: text, date: start + minutes * 60, topic: "today"))
        }
        post("Hoy hace sol.", minutes: 0)
        library.save(LearningLanguage.spanish.tokens(in: "perro")[0], from: "perro", translation: nil, at: start + 60)
        #expect(library.wordToReuse() == nil)
        post("Me gusta el café.", minutes: 2)
        #expect(library.wordToReuse() == nil)
        post("Mañana vamos al cine.", minutes: 3)
        #expect(library.wordToReuse()?.word == "perro")
        post("Mi perro duerme.", minutes: 4)
        #expect(library.wordToReuse() == nil)
    }

    @Test func theLeastSeenWordComesBackFirst() {
        var library = Library(language: .spanish, level: .a2)
        let start = Date.now
        for word in ["pan", "casa", "perro"] {
            library.save(LearningLanguage.spanish.tokens(in: word)[0], from: word, translation: nil, at: start)
        }
        library.add(Post(author: "nurse", text: "El pan y la casa.", date: start + 60, topic: "today"))
        library.add(Post(author: "baker", text: "Hoy hace sol.", date: start + 120, topic: "today"))
        library.add(Post(author: "runner", text: "Me gusta correr.", date: start + 180, topic: "today"))
        #expect(library.wordToReuse()?.word == "perro")
    }

    @Test func aNewLanguageStartsANewFeedButKeepsWords() {
        var library = Library(language: .spanish, level: .a2)
        library.add(.by("nurse"))
        library.save(LearningLanguage.spanish.tokens(in: "pan")[0], from: "pan", translation: nil)
        library.change(to: .spanish, level: .b1)
        #expect(library.posts.count == 1)
        library.change(to: .french, level: .b1)
        #expect(library.posts.isEmpty)
        #expect(library.currentWords.isEmpty)
        library.change(to: .spanish, level: .b1)
        #expect(library.currentWords.count == 1)
    }

    @Test func roundTripsThroughJSON() throws {
        var library = Library(language: .korean, level: .b2)
        var post = Post.by("student", "오늘 작은 문제가 생겼어.")
        post.comments = [Comment(author: .you, text: "무슨 문제?", date: .now)]
        library.add(post)
        library.toggleLike(post.id)
        let decoded = try JSONDecoder().decode(Library.self, from: JSONEncoder().encode(library))
        #expect(decoded.posts == library.posts)
        #expect(decoded.level == .b2)
        #expect(decoded.posts[0].isLiked)
    }
}
