import FoundationModels
import ImmerseKit
import SwiftUI

@main
struct ImmerseApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch model.availability {
            case .available:
                if model.library == nil {
                    OnboardingView()
                } else {
                    MainView()
                }
            case .unavailable(let reason):
                UnavailableView(reason: reason)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.checkAvailability() }
        }
        .alert("Something went wrong", isPresented: Binding { model.failure != nil } set: { if !$0 { model.failure = nil } }) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.failure ?? "")
        }
    }
}

struct MainView: View {
    enum Page: Hashable { case feed, words }

    @State private var page = Page.feed
    #if DEBUG
    @Environment(AppModel.self) private var model
    #endif

    var body: some View {
        TabView(selection: $page) {
            Tab("Feed", systemImage: "text.bubble", value: .feed) {
                FeedView()
            }
            Tab("Words", systemImage: "character.book.closed", value: .words) {
                WordsView()
            }
        }
        #if DEBUG
        .task {
            await Demo.prepare(model)
            if Demo.value("tab") == "words" { page = .words }
        }
        #endif
    }
}

/// Immerse writes every post with Apple's on-device model, so there's nothing to show without it.
struct UnavailableView: View {
    let reason: SystemLanguageModel.Availability.UnavailableReason
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch reason {
        case .deviceNotEligible:
            ContentUnavailableView(
                "This iPhone can't run Apple Intelligence", systemImage: "iphone.slash",
                description: Text("Immerse writes every post on your iPhone with Apple's on-device model, which needs iPhone 15 Pro or later.")
            )
        case .appleIntelligenceNotEnabled:
            ContentUnavailableView {
                Label("Turn on Apple Intelligence", systemImage: "apple.intelligence")
            } description: {
                Text("Immerse writes every post on your iPhone with Apple's on-device model. Turn on Apple Intelligence in Settings, then come back.")
            } actions: {
                Button("Open Settings") { openURL(URL(string: "App-prefs:")!) }
                    .buttonStyle(.borderedProminent)
            }
        case .modelNotReady:
            ContentUnavailableView {
                Label("Apple Intelligence is getting ready", systemImage: "arrow.down.circle")
            } description: {
                Text("The on-device model is still downloading. Your feed starts as soon as it's done.")
            } actions: {
                ProgressView()
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    model.checkAvailability()
                }
            }
        @unknown default:
            ContentUnavailableView("Apple Intelligence isn't available", systemImage: "exclamationmark.triangle")
        }
    }
}
