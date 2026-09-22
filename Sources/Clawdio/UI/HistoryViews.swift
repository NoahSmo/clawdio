import SwiftUI

/// Petite icône d'état d'une session (même vocabulaire visuel que le badge de Clawd).
struct StateGlyph: View {
    let state: AgentState
    let isRecent: Bool

    var body: some View {
        Group {
            if !isRecent || state == .idle {
                Image(systemName: "moon.zzz.fill").foregroundStyle(.white.opacity(0.3))
            } else {
                switch state {
                case .working:
                    Image(systemName: "sparkle") // fixe : `.symbolEffect(.pulse)` tournait en boucle
                        .foregroundStyle(Color(red: 0.98, green: 0.72, blue: 0.40))
                case .waitingReply:
                    Image(systemName: "bubble.left.fill").foregroundStyle(.white)
                case .needsApproval:
                    Image(systemName: "hand.raised.fill").foregroundStyle(Color(red: 1.0, green: 0.60, blue: 0.22))
                case .idle:
                    EmptyView()
                }
            }
        }
        .font(.system(size: 12))
        .frame(width: 20, height: 20)
    }
}

// MARK: - Liste des conversations

struct HistoryPage: View {
    let store: SessionStore
    let state: NotchState
    @Environment(\.t) private var t

    var body: some View {
        if store.sessions.isEmpty {
            Text(t(.noConversations))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollIfLive {
                VStack(spacing: 6) {
                    ForEach(store.sessions) { session in
                        SessionRow(session: session)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.snappy(duration: 0.3)) { state.page = .thread(session.id) }
                            }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct SessionRow: View {
    let session: AgentSession
    @Environment(\.t) private var t

    var body: some View {
        let recent = Date.now.timeIntervalSince(session.lastActivity) < 30 * 60
        HStack(spacing: 10) {
            StateGlyph(state: session.state, isRecent: recent)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title.isEmpty ? t(.untitled) : session.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(session.project)
                    Text("·")
                    AgeText(date: session.lastActivity)
                }
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.45))
                if !session.snippet.isEmpty {
                    Text(session.snippet)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

// MARK: - Fil d'une conversation

struct ThreadPage: View {
    let store: SessionStore
    let sessionID: String
    @Environment(\.t) private var t

    private var session: AgentSession? { store.sessions.first { $0.id == sessionID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let session {
                    StateGlyph(state: session.state, isRecent: Date.now.timeIntervalSince(session.lastActivity) < 30 * 60)
                    Text(session.title.isEmpty ? t(.untitled) : session.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text("· \(session.project)").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                }
            }
            .frame(height: 20)

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 6) {
                        ForEach(store.thread) { message in
                            bubble(message).id(message.id)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                }
                .scrollIndicators(.hidden)
                .onChange(of: store.thread) { _, _ in
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
        // Le fil se met à jour tant qu'il est affiché (la conversation continue de vivre).
        .task(id: sessionID) {
            while !Task.isCancelled {
                await store.loadThread(sessionID: sessionID)
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func bubble(_ message: ChatMessage) -> some View {
        Text(message.text)
            .font(.system(size: 11))
            .lineLimit(9)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                message.isUser ? Color(red: 0.79, green: 0.36, blue: 0.20).opacity(0.75) : Color.white.opacity(0.09),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
            .padding(message.isUser ? .leading : .trailing, 40)
    }
}

/// ScrollView masquée, sauf en capture debug : `ImageRenderer` ne dessine pas les ScrollView.
struct ScrollIfLive<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if Reveal.instant {
            content.frame(maxHeight: .infinity, alignment: .top).clipped()
        } else {
            ScrollView(.vertical) { content }.scrollIndicators(.hidden)
        }
    }
}
