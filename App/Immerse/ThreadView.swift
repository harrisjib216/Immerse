import ImmerseKit
import SwiftUI

struct ThreadView: View {
    let postID: Post.ID

    @Environment(AppModel.self) private var model
    @State private var draft = ""
    @FocusState private var composing: Bool

    var body: some View {
        if let library = model.library, let post = library.post(postID) {
            let language = library.language
            let reply = model.replies[postID]
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        PostCard(post: post, language: language)
                        Divider()
                        ForEach(post.comments) { comment in
                            CommentRow(
                                author: comment.author, text: comment.text, date: comment.date, language: language,
                                suggestion: comment.suggestion
                            )
                        }
                        if let persona = model.commenting[postID] {
                            CommentRow(author: .persona(persona.id), text: "", date: .now, language: language, isWriting: true)
                        }
                        if let reply {
                            CommentRow(author: .persona(post.author), text: reply, date: .now, language: language, isWriting: true)
                        }
                        Color.clear
                            .frame(height: 1)
                            .id("end")
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: post.comments.count) { withAnimation { scroller.scrollTo("end") } }
                .onChange(of: reply) { scroller.scrollTo("end") }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Reply in \(language.nativeName)", text: $draft, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($composing)
                        .padding(.vertical, 10)
                        .padding(.leading, 16)
                    Button {
                        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        draft = ""
                        Task { await model.comment(text, on: postID) }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reply != nil)
                    .accessibilityLabel("Send")
                    .padding(4)
                }
                .glassEffect(in: .rect(cornerRadius: 22))
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle(model.person(post.author)?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarVisibility(.hidden, for: .tabBar)
            .task {
                await model.joinIfQuiet(postID)
                #if DEBUG
                if let text = Demo.value("reply") { await model.comment(text, on: postID) }
                #endif
            }
        }
    }
}
