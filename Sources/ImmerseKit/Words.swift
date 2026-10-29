import Foundation
import NaturalLanguage

/// A word in a post that you can tap.
public struct Token: Hashable, Sendable {
    public let range: Range<String.Index>
    public let word: String
    /// The dictionary form, where NaturalLanguage knows it: `ir` for `fui`, `sein` for `bin`.
    public let lemma: String?
    /// What saved words are matched by: the dictionary form when there is one, so saving `fui` also finds `fuimos`.
    public let key: String
}

extension LearningLanguage {
    /// Downloads NaturalLanguage's dictionary forms for this language if this device doesn't have them yet, and
    /// says whether they're there. Without them every word is its own dictionary form, so saving `fui` wouldn't find
    /// `fuimos`.
    @discardableResult
    public func prepareDictionaryForms() async -> Bool {
        (try? await NLTagger.requestAssets(for: naturalLanguage, tagScheme: .lemma)) == .available
    }

    /// The words in `text`, without spaces, punctuation, numbers or emoji. Japanese and Chinese, which don't put
    /// spaces between words, are split by NaturalLanguage's dictionary.
    public func tokens(in text: String) -> [Token] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        tagger.setLanguage(naturalLanguage, range: text.startIndex..<text.endIndex)
        let wordLocale = Locale(identifier: id)
        var tokens: [Token] = []
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma,
            options: [.omitWhitespace, .omitPunctuation, .omitOther]
        ) { tag, range in
            let word = String(text[range])
            guard word.unicodeScalars.contains(where: CharacterSet.letters.contains) else { return true }
            let lemma = tag.map(\.rawValue).flatMap { $0.isEmpty || $0 == word ? nil : $0 }
            tokens.append(Token(range: range, word: word, lemma: lemma, key: (lemma ?? word).lowercased(with: wordLocale)))
            return true
        }
        return tokens
    }

    /// Whether two keys are forms of the same word. NaturalLanguage doesn't know the dictionary form of every word,
    /// so in languages that inflect by changing endings, words that share all but their last three letters count
    /// too: `sabroso` and `sabrosa`, `arreglado` and `arreglarla`. Short words have to match exactly, so `casa` isn't `caso`.
    /// Japanese, Korean, Chinese and Vietnamese don't inflect that way and always match exactly.
    public func sameWord(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        guard ![.japanese, .korean, .simplifiedChinese, .vietnamese].contains(naturalLanguage),
              a.count >= 4, b.count >= 4
        else { return false }
        let shared = zip(a, b).prefix { $0 == $1 }.count
        return shared >= max(4, max(a.count, b.count) - 3)
    }

    /// The words in `corrected` that aren't in `original`, by position, ignoring capitals and punctuation:
    /// `es` → `está` in "Mi horno también es roto" marks `está`.
    public func changedWords(from original: String, to corrected: String) -> [Range<String.Index>] {
        let locale = Locale(identifier: id)
        let before = tokens(in: original).map { $0.word.lowercased(with: locale) }
        let after = tokens(in: corrected)
        let changes = after.map { $0.word.lowercased(with: locale) }.difference(from: before)
        return changes.insertions.compactMap { change in
            if case .insert(let offset, _, _) = change { after[offset].range } else { nil }
        }
    }

    /// The sentence in `text` that contains `range`, for showing a word in context.
    public func sentence(containing range: Range<String.Index>, in text: String) -> String {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        tokenizer.setLanguage(naturalLanguage)
        let sentence = tokenizer.tokenRange(for: range)
        return String(text[sentence]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// How to read `word`, for scripts that don't show it: hiragana for Japanese words with kanji, pinyin for
    /// Chinese, and a romanization for Korean. `nil` for everything else.
    public func reading(of word: String) -> String? {
        switch naturalLanguage {
        case .japanese:
            guard word.unicodeScalars.contains(where: \.isKanji), let latin = latinTranscription(of: word) else { return nil }
            return latin.applyingTransform(.latinToHiragana, reverse: false)
        case .simplifiedChinese:
            return word.applyingTransform(.mandarinToLatin, reverse: false)
        case .korean:
            return word.applyingTransform(.toLatin, reverse: false)
        default:
            return nil
        }
    }

    private func latinTranscription(of word: String) -> String? {
        let string = word as CFString
        let tokenizer = CFStringTokenizerCreate(
            nil, string, CFRange(location: 0, length: CFStringGetLength(string)), kCFStringTokenizerUnitWord,
            Locale(identifier: id) as CFLocale
        )
        var parts: [String] = []
        while !CFStringTokenizerAdvanceToNextToken(tokenizer).isEmpty {
            if let part = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String {
                parts.append(part)
            }
        }
        return parts.isEmpty ? nil : parts.joined()
    }
}

extension Unicode.Scalar {
    fileprivate var isKanji: Bool {
        (0x4E00...0x9FFF).contains(value) || (0x3400...0x4DBF).contains(value)
    }
}
