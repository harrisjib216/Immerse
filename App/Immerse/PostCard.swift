import ImmerseKit
import SwiftUI
@preconcurrency import Translation

struct PostCard: View {
    let post: Post
    let language: LearningLanguage
    /// `nil` when the card is already the top of its thread.
    var openThread: (() -> Void)?

    @Environment(AppModel.self) private var model
    @State private var showsTranslation = false
    @State private var translation: String?
    @State private var translating: TranslationSession.Configuration?

    var body: some View {
        let persona = model.person(post.author)
        HStack(alignment: .top, spacing: 12) {
            Avatar(persona: persona)
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(persona?.name ?? post.author)
                            .font(.subheadline.weight(.semibold))
                        Text("@\(persona?.handle ?? "")")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    // Even the timestamps are in the language you're learning.
                    Text("\(persona?.city ?? "") · \(post.date.formatted(.relative(presentation: .named).locale(Locale(identifier: language.id))))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                TappableText(text: post.text, language: language)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                if showsTranslation {
                    Text(translation ?? "Translating…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 10)
                        .overlay(alignment: .leading) {
                            Capsule().fill(.quaternary).frame(width: 3)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                actions
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .translationTask(translating) { session in
            translation = (try? await session.translate(post.text))?.targetText ?? "Translation isn't available."
        }
    }

    /// Whole posts go through the Translation framework, which downloads the language on first use. It doesn't run
    /// in the simulator, so there the on-device model translates instead.
    private func translate() {
        #if targetEnvironment(simulator)
        Task {
            translation = (try? await OnDeviceWriter().translate(post.text, from: language, into: model.readerLanguageName))
                ?? "Translation isn't available."
        }
        #else
        translating = TranslationSession.Configuration(source: language.locale, target: model.readerLanguage)
        #endif
    }

    private var actions: some View {
        HStack(spacing: 0) {
            Button {
                model.toggleLike(post.id)
            } label: {
                Image(systemName: post.isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(post.isLiked ? AnyShapeStyle(.pink) : AnyShapeStyle(.secondary))
                    .contentTransition(.symbolEffect(.replace))
            }
            .sensoryFeedback(.impact(weight: .light), trigger: post.isLiked)
            .accessibilityLabel(post.isLiked ? "Unlike" : "Like")
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                openThread?()
            } label: {
                Label {
                    Text(post.comments.isEmpty ? "" : "\(post.comments.count)")
                } icon: {
                    Image(systemName: "bubble.right")
                }
            }
            .disabled(openThread == nil)
            .accessibilityLabel("Reply")
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Speaker.shared.speak(post.text, in: language)
            } label: {
                Image(systemName: "speaker.wave.2")
            }
            .accessibilityLabel("Listen")
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                if translation == nil { translate() }
                withAnimation(.snappy) { showsTranslation.toggle() }
            } label: {
                Image(systemName: "translate")
                    .foregroundStyle(showsTranslation ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            .accessibilityLabel(showsTranslation ? "Hide translation" : "Translate")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

struct CommentRow: View {
    let author: Author
    let text: String
    let date: Date
    let language: LearningLanguage
    /// For your comments: how a native speaker might say it.
    var suggestion: String?
    /// Still being written, so it isn't tappable yet.
    var isWriting = false

    @Environment(AppModel.self) private var model

    var body: some View {
        let persona: Persona? = if case .persona(let id) = author { model.person(id) } else { nil }
        HStack(alignment: .top, spacing: 10) {
            Avatar(persona: persona, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(persona?.name ?? "You")
                        .font(.subheadline.weight(.semibold))
                    if !isWriting {
                        Text(date.formatted(.relative(presentation: .named).locale(Locale(identifier: language.id))))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if persona == nil {
                    Text(text)
                    if let suggestion {
                        SuggestionView(original: text, suggestion: suggestion, language: language)
                            .padding(.top, 4)
                            .transition(.opacity)
                    }
                } else if isWriting {
                    if text.isEmpty { TypingDots().padding(.vertical, 6) } else { Text(text) }
                } else {
                    TappableText(text: text, language: language)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .animation(.snappy, value: suggestion)
    }
}

/// How a native speaker might say your comment, with the words that changed picked out. It's quiet on purpose:
/// the conversation carries on either way.
struct SuggestionView: View {
    let original: String
    let suggestion: String
    let language: LearningLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("A native speaker might say", systemImage: "text.bubble")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(highlighted)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.tint.opacity(0.08), in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private var highlighted: AttributedString {
        var string = AttributedString(suggestion)
        for range in language.changedWords(from: original, to: suggestion) {
            guard let range = Range(range, in: string) else { continue }
            string[range].font = .callout.bold()
            string[range].foregroundColor = .accentColor
        }
        return string
    }
}
