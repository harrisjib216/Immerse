import Foundation
@testable import ImmerseKit

/// Answers from a list, in order, and remembers what it was asked.
final class ScriptedWriter: Writer, @unchecked Sendable {
    private let lock = NSLock()
    private var answers: [String]
    private var corrections: [String]
    private(set) var requests: [(prompt: String, instructions: String)] = []

    /// `corrections` answer `correct(_:in:)` in order; without one, the text comes back as it was.
    init(_ answers: String..., corrections: [String] = []) {
        self.answers = answers
        self.corrections = corrections
    }

    func write(_ prompt: String, instructions: String) async throws -> String {
        lock.withLock {
            requests.append((prompt, instructions))
            return answers.isEmpty ? "" : answers.removeFirst()
        }
    }

    func correct(_ text: String, in language: LearningLanguage, isWoman: Bool?) async throws -> String {
        lock.withLock { corrections.isEmpty ? text : corrections.removeFirst() }
    }

    /// Streams the next answer a word at a time.
    func stream(_ prompt: String, instructions: String) -> AsyncThrowingStream<String, any Error> {
        let answer = lock.withLock {
            requests.append((prompt, instructions))
            return answers.isEmpty ? "" : answers.removeFirst()
        }
        return AsyncThrowingStream { continuation in
            var text = ""
            for word in answer.split(separator: " ") {
                text += text.isEmpty ? String(word) : " \(word)"
                continuation.yield(text)
            }
            continuation.finish()
        }
    }
}

/// SplitMix64, so topic choices repeat from run to run.
struct SeededRandom: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension Post {
    static func by(_ author: String, topic: String = "today", _ text: String = "Hoy fui a la tienda.") -> Post {
        Post(author: author, text: text, date: .now, topic: topic)
    }
}
