import Foundation
import Testing
@testable import ImmerseKit

@Suite struct EngineTests {
    let spanish = "Hoy fui al mercado con mi hermana. Compramos fruta y pan."

    @Test func everyoneTakesATurnBeforeAnyonePostsTwice() {
        let engine = FeedEngine(language: .spanish, level: .a2, writer: ScriptedWriter())
        var posts: [Post] = []
        for _ in 0..<8 {
            posts.insert(.by(engine.nextAuthor(after: posts).id), at: 0)
        }
        #expect(Set(posts.map(\.author)).count == 8)
        #expect(engine.nextAuthor(after: posts).id == posts.last?.author)
    }

    @Test func topicsDontRepeatTooSoon() {
        let engine = FeedEngine(language: .spanish, level: .a2, writer: ScriptedWriter())
        var random = SeededRandom(state: 7)
        var posts: [Post] = []
        for _ in 0..<40 {
            let author = engine.nextAuthor(after: posts)
            let topic = engine.nextTopic(for: author, after: posts, using: &random)
            let theirs = posts.filter { $0.author == author.id }.prefix(4).map(\.topic)
            #expect(!theirs.contains(topic.id))
            #expect(!posts.prefix(2).map(\.topic).contains(topic.id))
            posts.insert(.by(author.id, topic: topic.id), at: 0)
        }
    }

    @Test func writesAgainWhenTheModelSlipsIntoEnglish() async throws {
        let writer = ScriptedWriter("Today I went to the market with my sister.", "“\(spanish)”\n")
        let engine = FeedEngine(language: .spanish, level: .a2, writer: writer)
        let post = try await engine.post(by: engine.cast[0], about: Topic.all[0])
        #expect(post.text == spanish)
        #expect(writer.requests.count == 2)
    }

    @Test func triesAgainAfterAnError() async throws {
        struct Failing: Writer {
            let attempts = Attempts()
            func write(_ prompt: String, instructions: String) async throws -> String {
                if await attempts.next() == 1 { throw CocoaError(.featureUnsupported) }
                return "Hoy fui al mercado con mi hermana."
            }
            func stream(_ prompt: String, instructions: String) -> AsyncThrowingStream<String, any Error> {
                AsyncThrowingStream { $0.finish() }
            }
            func correct(_ text: String, in language: LearningLanguage, isWoman: Bool?) async throws -> String { text }
        }
        actor Attempts {
            var count = 0
            func next() -> Int { count += 1; return count }
        }
        let engine = FeedEngine(language: .spanish, level: .a2, writer: Failing())
        let post = try await engine.post(by: engine.cast[0], about: Topic.all[0])
        #expect(post.text == "Hoy fui al mercado con mi hermana.")
    }

    @Test func givesUpAfterThreeTries() async {
        let english = "Today I went to the market with my sister."
        let engine = FeedEngine(language: .spanish, level: .a2, writer: ScriptedWriter(english, english, english))
        await #expect(throws: EngineError.wrongLanguage(english)) {
            try await engine.post(by: engine.cast[0], about: Topic.all[0])
        }
    }

    @Test func savedWordsGoIntoThePrompt() async throws {
        let writer = ScriptedWriter(spanish)
        let engine = FeedEngine(language: .spanish, level: .a2, writer: writer)
        _ = try await engine.post(by: engine.cast[1], about: Topic.all[0], reusing: "mercado")
        #expect(writer.requests[0].prompt.hasSuffix("Use the word \"mercado\" somewhere, in its everyday meaning and in whatever form the sentence needs."))
        #expect(writer.requests[0].instructions.hasPrefix("You are Lucía, a 26-year-old woman who lives in Madrid."))
    }

    @Test func postsDontAllStartTheSameWay() async throws {
        let writer = ScriptedWriter(spanish)
        let engine = FeedEngine(language: .spanish, level: .a2, writer: writer)
        let feed: [Post] = [.by("nurse", "Hoy fui al parque."), .by("baker", "¿Alguien sabe hacer pan?"), .by("runner", "Hoy corrí 10 km."), .by("student", "Mañana tengo examen.")]
        _ = try await engine.post(by: engine.cast[2], about: Topic.all[0], after: feed)
        #expect(writer.requests[0].prompt.hasSuffix(#"Don't start with "Hoy" or "Alguien"."#))
    }

    @Test func someoneElseComments() {
        let engine = FeedEngine(language: .spanish, level: .a2, writer: ScriptedWriter())
        var post = Post.by("nurse")
        for _ in 0..<7 {
            let commenter = try! #require(engine.commenter(for: post))
            #expect(commenter.id != "nurse")
            post.comments.append(Comment(author: .persona(commenter.id), text: "¡Qué bien!", date: .now))
        }
        #expect(engine.commenter(for: post) == nil)
    }

    @Test func repliesStreamAndSeeTheWholeThread() async throws {
        let writer = ScriptedWriter("¡Claro que sí! Mañana vamos juntos.")
        let engine = FeedEngine(language: .spanish, level: .a2, writer: writer)
        var post = Post.by("courier", "¿Alguien conoce un buen café?")
        post.comments = [
            Comment(author: .persona("baker"), text: "¡Mi panadería!", date: .now),
            Comment(author: .you, text: "Yo quiero ir contigo", date: .now),
        ]
        var seen: [String] = []
        for try await text in engine.reply(to: post) { seen.append(text) }
        #expect(seen.first == "¡Claro")
        #expect(seen.last == "¡Claro que sí! Mañana vamos juntos.")
        #expect(writer.requests[0].prompt.contains("Diego: ¡Mi panadería!\nA follower: Yo quiero ir contigo"))
    }

    @Test func postsAreRewrittenTheWayANativeSpeakerWouldWriteThem() async throws {
        let writer = ScriptedWriter(
            "La comida que comí era muy sabroso y me ayudó a olvidar todo.",
            corrections: ["La comida que comí era muy sabrosa y me ayudó a olvidar todo."]
        )
        let engine = FeedEngine(language: .spanish, level: .a2, writer: writer)
        let post = try await engine.post(by: engine.cast[0], about: Topic.all[1], reusing: "sabroso")
        #expect(post.text == "La comida que comí era muy sabrosa y me ayudó a olvidar todo.")
    }

    @Test(arguments: [
        "La comida era deliciosa y muy buena, como siempre en mi barrio.",  // drops the saved word
        "The food was tasty and helped me forget everything today.",        // not Spanish
        "La comida sabrosa.",                                               // much shorter
    ])
    func aBadRewriteKeepsTheDraft(_ rewrite: String) async throws {
        let draft = "La comida era sabrosa y muy rica, como siempre en mi barrio."
        let engine = FeedEngine(language: .spanish, level: .a2, writer: ScriptedWriter(draft, corrections: [rewrite]))
        let post = try await engine.post(by: engine.cast[0], about: Topic.all[1], reusing: "sabroso")
        #expect(post.text == draft)
    }

    @Test func aMistakeGetsASuggestion() async {
        let engine = FeedEngine(language: .spanish, level: .a2, writer: ScriptedWriter(corrections: ["Mi horno también está roto."]))
        #expect(await engine.suggestion(for: "Mi horno también es roto") == "Mi horno también está roto.")
    }

    @Test func punctuationAndCapitalsAreNotMistakes() async {
        let engine = FeedEngine(language: .spanish, level: .a2, writer: ScriptedWriter(corrections: ["¡Mi horno también está roto!"]))
        #expect(await engine.suggestion(for: "mi horno también está roto") == nil)
    }

    @Test func aRewriteInEnglishIsIgnored() async {
        let engine = FeedEngine(language: .spanish, level: .a2, writer: ScriptedWriter(corrections: ["My oven is broken too, and I need it for the bread."]))
        #expect(await engine.suggestion(for: "Mi horno también es roto") == nil)
    }

    @Test func theAuthorRepliesToWhatYouMeant() async throws {
        let writer = ScriptedWriter("¿También está roto? ¡Qué mala suerte!")
        let engine = FeedEngine(language: .spanish, level: .a2, writer: writer)
        var post = Post.by("baker", "Mi horno se calienta mucho.")
        var comment = Comment(author: .you, text: "Mi horno también es roto", date: .now)
        comment.suggestion = "Mi horno también está roto."
        post.comments = [comment]
        for try await _ in engine.reply(to: post) {}
        #expect(writer.requests[0].prompt.contains("A follower: Mi horno también está roto."))
        #expect(!writer.requests[0].prompt.contains("es roto"))
    }

    @Test func aReplyInEnglishIsReplaced() async throws {
        let writer = ScriptedWriter("Of course, we can go together tomorrow!", "¡Claro que sí! Mañana vamos juntos.")
        let engine = FeedEngine(language: .spanish, level: .a2, writer: writer)
        var post = Post.by("courier")
        post.comments = [Comment(author: .you, text: "Yo quiero ir contigo", date: .now)]
        var last = ""
        for try await text in engine.reply(to: post) { last = text }
        #expect(last == "¡Claro que sí! Mañana vamos juntos.")
    }

    @Test(arguments: Level.allCases)
    func everyLevelAsksForSomethingDifferent(_ level: Level) {
        let instructions = Prompts(language: .japanese, level: level, cast: []).instructions(for: Cast.people(in: .japanese)[0])
        #expect(instructions.contains("Write only in Japanese"))
        #expect(instructions.contains("CEFR level \(level.code)"))
    }
}
