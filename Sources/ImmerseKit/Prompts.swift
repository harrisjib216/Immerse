/// The text sent to the model. Kept apart from the engine so the tests can read every prompt.
struct Prompts {
    let language: LearningLanguage
    let level: Level
    let cast: [Persona]

    func instructions(for persona: Persona) -> String {
        """
        You are \(persona.name), a \(persona.age)-year-old \(persona.isWoman ? "woman" : "man") who lives in \
        \(persona.city). \(persona.life)
        You post on a social network. Write only in \(language.promptName): never in English, not even one word, \
        and never add a translation. \(level.guidance)\(register) Write like a real person typing on a phone: no \
        hashtags, no title, no quotation marks around the text.
        """
    }

    /// Japanese and Korean courses teach the polite forms first, and the model's casual forms read as rude to a
    /// beginner who can't tell the difference yet.
    private var register: String {
        guard level == .a1 || level == .a2 else { return "" }
        return switch language.id {
        case "ja": " Use the polite です and ます forms."
        case "ko": " Use the polite 요 forms."
        default: ""
        }
    }

    /// Each post comes from a new session that can't see the feed, so left alone, most posts open with the word for
    /// "today". Naming the words the latest posts opened with is enough to stop that.
    func post(about topic: Topic, reusing word: String?, avoiding openings: [String]) -> String {
        var prompt = topic.prompt
        if let word {
            prompt += " Use the word \"\(word)\" somewhere, in its everyday meaning and in whatever form the sentence needs."
        }
        if !openings.isEmpty {
            prompt += " Don't start with " + openings.map { "\"\($0)\"" }.joined(separator: " or ") + "."
        }
        return prompt
    }

    func comment(on post: Post) -> String {
        let author = name(post.author)
        return """
            \(author) posted: \(post.text)

            Write a short comment on \(author)'s post, one or two sentences, the way a friend would.
            """
    }

    /// The author's reply to your latest comment. The whole thread goes in each time, so a conversation picks up
    /// where it left off after the app relaunches, without keeping a model session alive.
    ///
    /// The author echoes you back, the way people do in conversation. Echoing a mistake would teach it, so your
    /// comments go in as a native speaker would have said them.
    func reply(to post: Post) -> String {
        var lines = ["Your post: \(post.text)", "", "Comments, oldest first:"]
        for comment in post.comments {
            switch comment.author {
            case .you: lines.append("A follower: \(comment.suggestion ?? comment.text)")
            case .persona(post.author): lines.append("You: \(comment.text)")
            case .persona(let id): lines.append("\(name(id)): \(comment.text)")
            }
        }
        lines.append("")
        lines.append("""
            Reply to the follower's last comment in one or two sentences, warmly, like a friend. Begin by echoing \
            what they said back to them in correct, natural words, the way friends repeat each other in \
            conversation, then add something of your own. Never mention mistakes.
            """)
        return lines.joined(separator: "\n")
    }

    private func name(_ id: String) -> String {
        cast.first { $0.id == id }?.name ?? id
    }
}
