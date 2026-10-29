import ImmerseKit
import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var language: LearningLanguage?
    @State private var level = Level.a2

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Immerse")
                        .font(.largeTitle.bold())
                    Text("A feed of people who post in the language you're learning, at your level. Tap any word to translate it, reply to anyone, and save words to see them again.")
                        .foregroundStyle(.secondary)
                    Label("Written on this iPhone by Apple Intelligence", systemImage: "apple.intelligence")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("I'm learning")
                        .font(.title3.bold())
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        ForEach(model.languages) { option in
                            Button { language = option } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.nativeName)
                                        .font(.headline)
                                    Text(option.name())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(.fill.quaternary, in: .rect(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.accentColor, lineWidth: option == language ? 2 : 0)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(option == language ? .isSelected : [])
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("My level")
                        .font(.title3.bold())
                    ForEach(Level.allCases) { option in
                        Button { level = option } label: {
                            HStack(spacing: 14) {
                                Text(option.code)
                                    .font(.headline.monospaced())
                                    .foregroundStyle(option == level ? Color.accentColor : .secondary)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(.headline)
                                    Text(option.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .background(.fill.quaternary, in: .rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.accentColor, lineWidth: option == level ? 2 : 0)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(option == level ? .isSelected : [])
                    }
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if let language { model.start(language, level: level) }
            } label: {
                Text(language.map { "Start reading \($0.name())" } ?? "Choose a language")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(language == nil)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
}
