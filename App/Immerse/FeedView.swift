import ImmerseKit
import SwiftUI

struct FeedView: View {
    @Environment(AppModel.self) private var model
    @State private var path: [Post.ID] = []

    var body: some View {
        NavigationStack(path: $path) {
            if let library = model.library {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if let persona = model.writing {
                            TypingRow(persona: persona)
                                .transition(.opacity)
                            Divider()
                        }
                        ForEach(library.posts) { post in
                            PostCard(post: post, language: library.language) { path.append(post.id) }
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                    .animation(.snappy, value: library.posts.map(\.id))
                    .animation(.snappy, value: model.writing)
                }
                .refreshable {
                    // The new posts arrive one at a time under the typing row, so the spinner can go away now.
                    model.refresh()
                }
                .navigationTitle(library.language.nativeName)
                .navigationSubtitle("\(library.level.code) · \(library.level.title)")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        SettingsMenu(library: library)
                    }
                }
                .navigationDestination(for: Post.ID.self) { ThreadView(postID: $0) }
                .task(id: library.languageID) {
                    OnDeviceWriter.prewarm()
                    model.fill()
                    await library.language.prepareDictionaryForms()
                    #if DEBUG
                    if Demo.flag("thread"), let first = await Demo.firstPost(model) { path.append(first) }
                    #endif
                }
            }
        }
    }
}

private struct SettingsMenu: View {
    let library: Library
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            Picker("Level", systemImage: "chart.bar", selection: Binding {
                library.level
            } set: {
                model.start(library.language, level: $0)
            }) {
                ForEach(Level.allCases) { level in
                    Text("\(level.code) · \(level.title)").tag(level)
                }
            }
            .pickerStyle(.menu)
            Picker("Language", systemImage: "globe", selection: Binding {
                library.language
            } set: {
                model.start($0, level: library.level)
            }) {
                ForEach(model.languages) { language in
                    Text(language.nativeName).tag(language)
                }
            }
            .pickerStyle(.menu)
            Divider()
            Button("Start a new feed", systemImage: "arrow.counterclockwise", role: .destructive) {
                model.startOver()
            }
        } label: {
            Label("Settings", systemImage: "slider.horizontal.3")
        }
    }
}

struct TypingRow: View {
    let persona: Persona

    var body: some View {
        HStack(spacing: 12) {
            Avatar(persona: persona)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(persona.name) is writing…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TypingDots()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

struct TypingDots: View {
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 6, height: 6)
                    .phaseAnimator([0.3, 1]) { dot, phase in
                        dot.opacity(phase)
                    } animation: { _ in
                        .easeInOut(duration: 0.5).delay(Double(index) * 0.15)
                    }
            }
        }
        .foregroundStyle(.secondary)
    }
}

struct Avatar: View {
    /// `nil` is you.
    let persona: Persona?
    var size: CGFloat = 44

    var body: some View {
        let hue = persona?.hue ?? 0.6
        let saturation = persona == nil ? 0.0 : 1.0
        Circle()
            .fill(LinearGradient(
                colors: [
                    Color(hue: hue, saturation: 0.5 * saturation, brightness: 0.95),
                    Color(hue: hue, saturation: 0.75 * saturation, brightness: 0.72),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .overlay {
                Image(systemName: persona?.symbol ?? "person.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
