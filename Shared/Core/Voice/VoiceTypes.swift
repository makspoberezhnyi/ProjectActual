import Foundation

/// What the person wants to happen. Only two things can be said to Actual: begin
/// something, or finish something.
public enum VoiceIntent: String, Equatable, Sendable {
    case start
    case end
}

/// A language the parser can handle without a model.
///
/// Category names are deliberately absent from everything here. Categories come from
/// whatever the person typed or said when creating them, so matching a spoken phrase
/// against their own list never depends on translation. Only the grammar around the
/// category — the words for starting, guessing, and the numbers — needs per-language
/// handling.
public enum VoiceLanguage: String, Equatable, Sendable, CaseIterable {
    case english
    case russian
    case ukrainian

    public var localeIdentifier: String {
        switch self {
        case .english: return "en-US"
        case .russian: return "ru-RU"
        case .ukrainian: return "uk-UA"
        }
    }
}

/// The structured reading of a spoken phrase, before it has met the person's actual
/// categories or open sessions.
///
/// `categoryReference` is the raw remaining words, not a resolved category. Resolving
/// it is a separate step, because that step needs to know what the person actually has.
public struct VoiceCommand: Equatable, Sendable {
    public var intent: VoiceIntent
    public var categoryReference: String?
    public var estimatedMinutes: Int?
    /// `nil` means the phrase said nothing about context, which is different from
    /// saying "normal". The resolver applies the default.
    public var contextTag: ContextTag?
    public var language: VoiceLanguage

    public init(
        intent: VoiceIntent,
        categoryReference: String?,
        estimatedMinutes: Int? = nil,
        contextTag: ContextTag? = nil,
        language: VoiceLanguage = .english
    ) {
        self.intent = intent
        self.categoryReference = categoryReference
        self.estimatedMinutes = estimatedMinutes
        self.contextTag = contextTag
        self.language = language
    }
}

/// Everything needed to open a session, once the command has met the real world.
public struct StartRequest: Equatable, Sendable {
    /// `nil` when the spoken category is one the person does not have yet, in which
    /// case `title` is what to create.
    public let categoryID: String?
    public let title: String
    public let contextTag: ContextTag
    public let estimatedMinutes: Int?

    public init(categoryID: String?, title: String, contextTag: ContextTag, estimatedMinutes: Int?) {
        self.categoryID = categoryID
        self.title = title
        self.contextTag = contextTag
        self.estimatedMinutes = estimatedMinutes
    }
}

/// One short question, asked rather than guessed.
///
/// Guessing silently between two plausible categories risks logging a session under the
/// wrong one, which quietly corrupts the very history the engine depends on. A single
/// question costs a moment; a wrong write costs the data.
public struct AmbiguousChoice: Equatable, Sendable {
    public struct Option: Equatable, Sendable, Identifiable {
        public let id: String
        public let label: String

        public init(id: String, label: String) {
            self.id = id
            self.label = label
        }
    }

    public let question: String
    public let options: [Option]

    public init(question: String, options: [Option]) {
        self.question = question
        self.options = options
    }
}

/// What the app should do about what it just heard.
public enum VoiceOutcome: Equatable, Sendable {
    case start(StartRequest)
    case end(sessionID: UUID)
    /// More than one reading is equally likely. Ask, do not pick.
    case ambiguous(AmbiguousChoice)
    /// Nothing usable was heard. Falls back to manual entry rather than inventing.
    case notUnderstood(NotUnderstood)

    public enum NotUnderstood: Equatable, Sendable {
        case noIntent
        case noCategorySpoken
        case nothingRunning
        case noMatchingOpenSession(spoken: String)
    }
}
