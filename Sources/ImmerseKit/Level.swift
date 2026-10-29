/// How hard the feed reads, on the Common European Framework of Reference scale.
public enum Level: String, CaseIterable, Codable, Identifiable, Sendable {
    case a1, a2, b1, b2, c1

    public var id: String { rawValue }

    public var code: String { rawValue.uppercased() }

    public var title: String {
        switch self {
        case .a1: "Beginner"
        case .a2: "Elementary"
        case .b1: "Intermediate"
        case .b2: "Upper intermediate"
        case .c1: "Advanced"
        }
    }

    public var summary: String {
        switch self {
        case .a1: "Short posts about everyday things, in the present tense."
        case .a2: "The past and the future, still in short, plain sentences."
        case .b1: "Longer posts with common expressions, the way people write to friends."
        case .b2: "Natural posts with varied grammar and some idioms."
        case .c1: "Exactly how people post: slang, wordplay and all."
        }
    }

    /// What the prompts ask for. Each level names the grammar and length it allows, because "write at level A2"
    /// on its own makes the model write the same post it would have written anyway.
    var guidance: String {
        switch self {
        case .a1:
            "Write at CEFR level A1: only the present tense, only very common words, one idea per sentence, "
                + "five to eight words per sentence, two or three sentences. No idioms, no slang."
        case .a2:
            "Write at CEFR level A2: the present, the simple past and the near future, common everyday words, "
                + "short sentences joined with words like and, but and because, two to four sentences. No idioms."
        case .b1:
            "Write at CEFR level B1: any common tense, everyday words with a few less common ones, sentences with "
                + "one clause added, three to five sentences. A common expression now and then is fine."
        case .b2:
            "Write at CEFR level B2: varied grammar and vocabulary, the way a native speaker writes to friends, "
                + "with some idioms and casual phrasing, three to six sentences."
        case .c1:
            "Write at CEFR level C1: exactly as a native speaker posts, with idioms, slang, wordplay and "
                + "abbreviations where they come naturally, up to six sentences."
        }
    }
}
