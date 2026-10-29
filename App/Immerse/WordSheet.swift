import ImmerseKit
import SwiftUI

struct WordSheet: View {
    let word: TappedWord
    let language: LearningLanguage

    @Environment(AppModel.self) private var model
    @State private var meaning: Meaning?
    @State private var failed = false

    var body: some View {
        let saved = model.library?.saved(word.token)
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(word.token.word)
                        .font(.largeTitle.bold())
                    if let reading = language.reading(of: word.token.word) {
                        Text(reading)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    if let lemma = word.token.lemma {
                        Text("from \(Text(lemma).italic())")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    Speaker.shared.speak(word.token.word, in: language)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityLabel("Listen")
            }

            Text(meaning?.word ?? (failed ? "No translation right now." : "Translating…"))
                .font(.title2)
                .foregroundStyle(meaning == nil ? .secondary : .primary)

            VStack(alignment: .leading, spacing: 6) {
                Text(highlightedSentence)
                Text(meaning?.sentence ?? " ")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.quaternary, in: .rect(cornerRadius: 14))

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Button {
                    if let saved {
                        model.forget(saved.id)
                    } else {
                        model.save(word.token, from: word.sentence, translation: meaning?.word)
                    }
                } label: {
                    Label(saved == nil ? "Save word" : "Saved", systemImage: saved == nil ? "plus" : "checkmark")
                        .frame(maxWidth: .infinity)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .sensoryFeedback(.success, trigger: saved != nil) { _, isSaved in isSaved }
                Text(saved == nil ? "Saved words come back in new posts." : "Watch for it in new posts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            do {
                meaning = try await OnDeviceWriter().meaning(
                    of: word.token.word, in: word.sentence, from: language, into: model.readerLanguageName
                )
            } catch {
                failed = true
            }
        }
    }

    private var highlightedSentence: AttributedString {
        var sentence = AttributedString(word.sentence)
        if let range = sentence.range(of: word.token.word) {
            sentence[range].font = .body.bold()
            sentence[range].backgroundColor = Color.yellow.opacity(0.35)
        }
        return sentence
    }
}
