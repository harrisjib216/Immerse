import Foundation

public enum EngineError: Error, Equatable {
    /// The model kept writing in English, or added a translation.
    case wrongLanguage(String)
}

/// Decides who posts next and about what, writes it, and checks that it came back in the right language.
public struct FeedEngine: Sendable {
    public let language: LearningLanguage
    public let level: Level
    public let cast: [Persona]
    let writer: any Writer
    var attempts = 3

    public init(language: LearningLanguage, level: Level, writer: any Writer) {
        self.language = language
        self.level = level
        self.writer = writer
        cast = Cast.people(in: language)
    }

    var prompts: Prompts { Prompts(language: language, level: level, cast: cast) }

    public func person(_ id: String) -> Persona? {
        cast.first { $0.id == id }
    }

    /// Whoever has gone longest without posting, so the whole cast takes turns. `posts` is newest first.
    public func nextAuthor(after posts: [Post]) -> Persona {
        let lastPosted = Dictionary(posts.enumerated().map { ($1.author, $0) }, uniquingKeysWith: min)
        return cast.max { (lastPosted[$0.id] ?? .max) < (lastPosted[$1.id] ?? .max) } ?? cast[0]
    }

    /// A topic this person hasn't used in their last four posts, and that the last two posts in the feed weren't
    /// about.
    public func nextTopic(for persona: Persona, after posts: [Post], using random: inout some RandomNumberGenerator) -> Topic {
        let theirs = posts.filter { $0.author == persona.id }.prefix(4).map(\.topic)
        let recent = posts.prefix(2).map(\.topic)
        let fresh = Topic.all.filter { !theirs.contains($0.id) && !recent.contains($0.id) }
        return (fresh.isEmpty ? Topic.all : fresh).randomElement(using: &random)!
    }

    /// A new post. `word` is one of your saved words for the post to use, and `feed` is the feed so far, newest
    /// first.
    public func post(
        by persona: Persona, about topic: Topic, reusing word: String? = nil, after feed: [Post] = [], at date: Date = .now
    ) async throws -> Post {
        let draft = try await write(prompts.post(about: topic, reusing: word, avoiding: openings(of: feed)), as: persona)
        return Post(author: persona.id, text: await polished(draft, by: persona, keeping: word), date: date, topic: topic.id)
    }

    /// The first words of the latest three posts, without repeats.
    func openings(of feed: [Post]) -> [String] {
        var seen: Set<String> = []
        return feed.prefix(3).compactMap { language.tokens(in: $0.text).first?.word }.filter { seen.insert($0).inserted }
    }

    /// Someone other than the author who hasn't commented yet, chosen the same way every time for the same post.
    public func commenter(for post: Post) -> Persona? {
        let taken = Set(post.comments.compactMap { if case .persona(let id) = $0.author { id } else { nil } })
        let others = cast.filter { $0.id != post.author && !taken.contains($0.id) }
        guard !others.isEmpty else { return nil }
        let seed = post.id.uuid.0 ^ post.id.uuid.15
        return others[Int(seed) % others.count]
    }

    public func comment(on post: Post, by persona: Persona, at date: Date = .now) async throws -> Comment {
        let draft = try await write(prompts.comment(on: post), as: persona)
        return Comment(author: .persona(persona.id), text: await polished(draft, by: persona, keeping: nil), date: date)
    }

    /// The draft as a native speaker would write it.
    ///
    /// The model's posts have the odd agreement slip, most often when it's asked to reuse one of your words and
    /// leaves it in the form it was given: "la comida era muy sabroso", or Irene writing "estuve ocupado". The same rewrite that checks your comments
    /// fixes those. A rewrite is only kept if it's in the right language, isn't much shorter than the draft, and
    /// still uses the word the post was meant to bring back. Rewording a correct post is harmless, since nobody saw
    /// the draft.
    func polished(_ draft: String, by persona: Persona, keeping word: String?) async -> String {
        guard let rewrite = (try? await writer.correct(draft, in: language, isWoman: persona.isWoman)).map(Self.tidy),
              language.wrote(rewrite)
        else {
            return draft
        }
        let tokens = language.tokens(in: rewrite)
        guard tokens.count * 5 >= language.tokens(in: draft).count * 4 else { return draft }
        if let word {
            let key = word.lowercased(with: Locale(identifier: language.id))
            guard tokens.contains(where: { language.sameWord($0.key, key) || language.sameWord($0.word.lowercased(), key) }) else {
                return draft
            }
        }
        return rewrite
    }

    /// How a native speaker would say your comment, or `nil` if you said it right. Differences only in punctuation
    /// or capitals don't count, and neither does a rewrite that isn't in the language you're learning.
    public func suggestion(for comment: String) async -> String? {
        guard let rewrite = try? await writer.correct(comment, in: language, isWoman: nil).trimmingCharacters(in: .whitespacesAndNewlines),
              language.wrote(rewrite), !language.changedWords(from: comment, to: rewrite).isEmpty
        else { return nil }
        return rewrite
    }

    /// The author's reply to your latest comment, as it's written. If the finished reply isn't in the right
    /// language, it's written again without streaming and the last value replaces it.
    public func reply(to post: Post) -> AsyncThrowingStream<String, any Error> {
        guard let author = person(post.author) else { return AsyncThrowingStream { $0.finish() } }
        let instructions = prompts.instructions(for: author)
        let prompt = prompts.reply(to: post)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var text = ""
                    for try await partial in writer.stream(prompt, instructions: instructions) {
                        text = partial
                        continuation.yield(Self.tidy(partial))
                    }
                    if !language.wrote(text) {
                        continuation.yield(try await write(prompt, as: author))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func write(_ prompt: String, as persona: Persona) async throws -> String {
        let instructions = prompts.instructions(for: persona)
        var failure: any Error = EngineError.wrongLanguage("")
        for _ in 0..<attempts {
            do {
                let text = Self.tidy(try await writer.write(prompt, instructions: instructions))
                if language.wrote(text) { return text }
                failure = EngineError.wrongLanguage(text)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // The model sometimes loops until it runs out of room, or trips a guardrail on harmless text.
                // A second try with the same prompt almost always works.
                failure = error
            }
        }
        throw failure
    }

    /// Trims the whitespace, the quotation marks the model sometimes puts around a post anyway, and the odd brace
    /// left over from the structured output.
    static func tidy(_ text: String) -> String {
        let quotes = CharacterSet(charactersIn: "\"“”„«»「」『』{}")
        return text.trimmingCharacters(in: .whitespacesAndNewlines.union(quotes))
    }
}
