/// What a post is about. Without a topic, every post from the on-device model starts with "Today I…".
public struct Topic: Identifiable, Hashable, Sendable {
    public let id: String
    let prompt: String

    public static let all: [Topic] = [
        Topic(id: "today", prompt: "Write a post about something small that happened to you today."),
        Topic(id: "food", prompt: "Write a post about something you ate today, or something you're craving."),
        Topic(id: "question", prompt: "Write a post asking your followers a question about your life."),
        Topic(id: "weekend", prompt: "Write a post about your plans for the weekend."),
        Topic(id: "recommendation", prompt: "Write a post recommending something: a place, a song, a food or a habit."),
        Topic(id: "noticed", prompt: "Write a post about something you noticed on your way somewhere today."),
        Topic(id: "weather", prompt: "Write a post about the weather and what it did to your day."),
        Topic(id: "problem", prompt: "Write a post about a small problem you had and whether you solved it."),
        Topic(id: "memory", prompt: "Write a post about a memory that something today brought back."),
        Topic(id: "opinion", prompt: "Write a post sharing a small opinion some people might disagree with."),
        Topic(id: "lookingForward", prompt: "Write a post about something you're looking forward to."),
        Topic(id: "funny", prompt: "Write a post about something funny that happened recently."),
    ]
}
