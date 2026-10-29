import Foundation

public struct Post: Identifiable, Codable, Hashable, Sendable {
    public var id = UUID()
    /// The persona's id.
    public var author: String
    public var text: String
    public var date: Date
    public var topic: String
    public var comments: [Comment] = []
    public var isLiked = false

    public init(author: String, text: String, date: Date, topic: String) {
        self.author = author
        self.text = text
        self.date = date
        self.topic = topic
    }
}

public struct Comment: Identifiable, Codable, Hashable, Sendable {
    public var id = UUID()
    public var author: Author
    public var text: String
    public var date: Date
    /// For your comments: how a native speaker would say it, when that's different.
    public var suggestion: String?

    public init(author: Author, text: String, date: Date) {
        self.author = author
        self.text = text
        self.date = date
    }
}

public enum Author: Codable, Hashable, Sendable {
    case you
    case persona(String)
}

/// A word you saved, and every time someone in the feed has used it since.
public struct SavedWord: Identifiable, Codable, Hashable, Sendable {
    public var id = UUID()
    public var word: String
    public var dictionaryForm: String?
    public var key: String
    public var translation: String?
    /// The sentence you found it in.
    public var sentence: String
    public var language: String
    public var saved: Date
    public var sightings: [Sighting] = []

    public struct Sighting: Codable, Hashable, Sendable {
        public var post: UUID
        public var author: String
        public var date: Date
    }

    /// What the prompts ask the cast to use: the dictionary form, so the model can put it in whatever form fits.
    public var prompted: String { dictionaryForm ?? word }
}

/// Everything Immerse keeps: the settings, the feed and your words.
public struct Library: Codable, Sendable {
    public var languageID: String
    public var level: Level
    /// Newest first.
    public private(set) var posts: [Post] = []
    public private(set) var words: [SavedWord] = []

    public init(language: LearningLanguage, level: Level) {
        languageID = language.id
        self.level = level
    }

    public var language: LearningLanguage { .named(languageID) ?? .spanish }

    /// Your saved words in the current language, newest first.
    public var currentWords: [SavedWord] {
        words.filter { $0.language == languageID }.sorted { $0.saved > $1.saved }
    }

    /// Switches language or level. A new language starts a new feed; saved words stay with their language.
    public mutating func change(to language: LearningLanguage, level: Level) {
        if language.id != languageID { posts = [] }
        languageID = language.id
        self.level = level
    }

    public mutating func startOver() {
        posts = []
    }

    public func post(_ id: Post.ID) -> Post? {
        posts.first { $0.id == id }
    }

    /// Adds a new post to the top of the feed and notes which of your saved words it uses.
    public mutating func add(_ post: Post) {
        posts.insert(post, at: 0)
        let language = language
        let keys = language.tokens(in: post.text).map(\.key)
        for index in words.indices where words[index].language == languageID
            && keys.contains(where: { language.sameWord($0, words[index].key) }) {
            words[index].sightings.append(.init(post: post.id, author: post.author, date: post.date))
        }
    }

    public mutating func add(_ comment: Comment, to post: Post.ID) {
        guard let index = posts.firstIndex(where: { $0.id == post }) else { return }
        posts[index].comments.append(comment)
    }

    public mutating func suggest(_ suggestion: String, for comment: Comment.ID, on post: Post.ID) {
        guard let index = posts.firstIndex(where: { $0.id == post }),
              let position = posts[index].comments.firstIndex(where: { $0.id == comment })
        else { return }
        posts[index].comments[position].suggestion = suggestion
    }

    public mutating func toggleLike(_ post: Post.ID) {
        guard let index = posts.firstIndex(where: { $0.id == post }) else { return }
        posts[index].isLiked.toggle()
    }

    public func saved(_ token: Token) -> SavedWord? {
        words.first { $0.language == languageID && language.sameWord($0.key, token.key) }
    }

    public mutating func save(_ token: Token, from sentence: String, translation: String?, at date: Date = .now) {
        guard saved(token) == nil else { return }
        words.append(SavedWord(
            word: token.word, dictionaryForm: token.lemma, key: token.key, translation: translation,
            sentence: sentence, language: languageID, saved: date
        ))
    }

    public mutating func forget(_ word: SavedWord.ID) {
        words.removeAll { $0.id == word }
    }

    /// The saved word the cast should use next, if any: the one seen least, among those that haven't come up in the
    /// last `gap` posts. Asking for every saved word in every post made the whole feed about the same three things.
    public func wordToReuse(gap: Int = 2) -> SavedWord? {
        guard posts.count >= gap else { return nil }
        let cutoff = posts[gap - 1].date
        return currentWords
            .filter { ($0.sightings.last?.date ?? $0.saved) < cutoff }
            .min { $0.sightings.count < $1.sightings.count }
    }
}
