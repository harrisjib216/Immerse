import ImmerseKit
import SwiftUI

struct WordsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            let words = model.library?.currentWords ?? []
            let language = model.library?.language ?? .spanish
            List {
                ForEach(words) { word in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(word.word)
                                .font(.headline)
                            if let form = word.dictionaryForm {
                                Text(form)
                                    .font(.subheadline)
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let translation = word.translation {
                                Text(translation)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(word.sentence)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        sightings(of: word, in: language)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                    .swipeActions {
                        Button("Forget", systemImage: "trash", role: .destructive) { model.forget(word.id) }
                    }
                }
            }
            .overlay {
                if words.isEmpty {
                    ContentUnavailableView(
                        "No saved words yet", systemImage: "character.book.closed",
                        description: Text("Tap any word in a post, then Save. Saved words come back in new posts.")
                    )
                }
            }
            .navigationTitle("Words")
            .navigationSubtitle(words.isEmpty ? "" : "\(words.count) in \(language.name())")
        }
    }

    @ViewBuilder
    private func sightings(of word: SavedWord, in language: LearningLanguage) -> some View {
        if let last = word.sightings.last {
            let name = Cast.person(last.author, in: language)?.name ?? last.author
            let when = last.date.formatted(.relative(presentation: .named))
            let text = word.sightings.count == 1
                ? "Back in \(name)'s post \(when)"
                : "Back \(word.sightings.count) times, last in \(name)'s post \(when)"
            Label(text, systemImage: "arrow.trianglehead.2.clockwise")
                .foregroundStyle(.tint)
        } else {
            Label("Coming up in a new post", systemImage: "clock")
                .foregroundStyle(.secondary)
        }
    }
}
