import Foundation

/// A session currently running, in the plain form Core can reason about.
public struct OpenSession: Equatable, Sendable {
    public let id: UUID
    public let categoryID: String?
    public let title: String

    public init(id: UUID, categoryID: String?, title: String) {
        self.id = id
        self.categoryID = categoryID
        self.title = title
    }
}

/// Turns a parsed command into something the app can actually do, given what the person
/// has and what is already running.
///
/// Kept separate from parsing so both halves stay testable on their own: parsing is
/// about language, this is about the person's data.
public struct VoiceResolver: Sendable {
    private let matcher: CategoryMatcher

    public init(matcher: CategoryMatcher = CategoryMatcher()) {
        self.matcher = matcher
    }

    public func resolve(
        _ command: VoiceCommand,
        categories: [CategoryMatcher.Candidate],
        openSessions: [OpenSession]
    ) -> VoiceOutcome {
        switch command.intent {
        case .start:
            return resolveStart(command, categories: categories)
        case .end:
            return resolveEnd(command, openSessions: openSessions)
        }
    }

    // MARK: - Starting

    private func resolveStart(
        _ command: VoiceCommand,
        categories: [CategoryMatcher.Candidate]
    ) -> VoiceOutcome {
        guard let reference = command.categoryReference else {
            return .notUnderstood(.noCategorySpoken)
        }

        let contextTag = command.contextTag ?? .normal

        switch matcher.match(reference, against: categories) {
        case .one(let candidate):
            return .start(
                StartRequest(
                    categoryID: candidate.id,
                    title: candidate.name,
                    contextTag: contextTag,
                    estimatedMinutes: command.estimatedMinutes
                )
            )

        case .several(let candidates):
            return .ambiguous(
                AmbiguousChoice(
                    question: "Which one did you mean?",
                    options: candidates.map { .init(id: $0.id, label: $0.name) }
                )
            )

        case .none:
            // Nothing close enough is not a failure. It is a category the person does
            // not have yet, and saying it out loud is a perfectly good way to create it.
            return .start(
                StartRequest(
                    categoryID: nil,
                    title: titleCased(reference),
                    contextTag: contextTag,
                    estimatedMinutes: command.estimatedMinutes
                )
            )
        }
    }

    // MARK: - Ending

    private func resolveEnd(
        _ command: VoiceCommand,
        openSessions: [OpenSession]
    ) -> VoiceOutcome {
        guard !openSessions.isEmpty else { return .notUnderstood(.nothingRunning) }

        // "ending the work session" names which one; a bare "stop" does not.
        guard let reference = command.categoryReference else {
            if openSessions.count == 1 {
                return .end(sessionID: openSessions[0].id)
            }
            return .ambiguous(
                AmbiguousChoice(
                    question: "Which one should I end?",
                    options: openSessions.map { .init(id: $0.id.uuidString, label: $0.title) }
                )
            )
        }

        let candidates = openSessions.map {
            CategoryMatcher.Candidate(id: $0.id.uuidString, name: $0.title)
        }

        switch matcher.match(reference, against: candidates) {
        case .one(let candidate):
            guard let id = UUID(uuidString: candidate.id) else {
                return .notUnderstood(.noMatchingOpenSession(spoken: reference))
            }
            return .end(sessionID: id)

        case .several(let matches):
            return .ambiguous(
                AmbiguousChoice(
                    question: "Which one should I end?",
                    options: matches.map { .init(id: $0.id, label: $0.name) }
                )
            )

        case .none:
            // Closing the only running session because it is the only one would write an
            // end time onto something the person did not name. Ask instead.
            return .notUnderstood(.noMatchingOpenSession(spoken: reference))
        }
    }

    private func titleCased(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
