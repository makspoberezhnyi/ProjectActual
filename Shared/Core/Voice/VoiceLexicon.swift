import Foundation

/// The per-language word tables the deterministic parser runs on.
///
/// This is the backup layer described in the concept: where the on-device model handles
/// a language well it does the flexible parsing, and where it does not, these fixed
/// keywords still guarantee the basic commands work. Adding a language means adding a
/// table here, not writing new logic.
public struct VoiceLexicon: Sendable {
    public let language: VoiceLanguage
    /// Words that mean "begin".
    public let startVerbs: Set<String>
    /// Words that mean "finish".
    public let endVerbs: Set<String>
    /// Words that introduce an estimate: "guessing", "about", "roughly".
    public let guessMarkers: Set<String>
    /// Words meaning minute, in whatever forms the language inflects into.
    public let minuteUnits: Set<String>
    /// Words meaning hour.
    public let hourUnits: Set<String>
    /// Word for half, used by "half an hour" and "an hour and a half".
    public let halfWords: Set<String>
    /// Single words that already mean thirty minutes on their own, like "полчаса".
    public let halfHourWords: Set<String>
    /// Single words meaning one and a half, like "полтора", which need the unit that
    /// follows to know what they are one and a half of.
    public let oneAndAHalfWords: Set<String>
    /// Word for quarter, used by "quarter of an hour".
    public let quarterWords: Set<String>
    /// Words meaning "and", which join "two hours and a half".
    public let conjunctions: Set<String>
    /// Number words mapped to their value.
    public let numbers: [String: Int]
    /// Words carrying no meaning for parsing, stripped before the category is read.
    public let fillers: Set<String>
    /// Spoken cues that map onto a context tag.
    public let contextCues: [String: ContextTag]

    public static let all: [VoiceLexicon] = [.english, .russian, .ukrainian]

    public static func lexicon(for language: VoiceLanguage) -> VoiceLexicon {
        all.first { $0.language == language } ?? .english
    }
}

extension VoiceLexicon {

    public static let english = VoiceLexicon(
        language: .english,
        startVerbs: ["start", "starting", "begin", "beginning", "began", "starts"],
        endVerbs: ["end", "ending", "finish", "finishing", "finished", "stop", "stopping", "done", "complete", "completed"],
        guessMarkers: ["guessing", "guess", "about", "around", "roughly", "maybe", "approximately", "estimate", "estimating", "think", "probably"],
        minuteUnits: ["minute", "minutes", "min", "mins", "m"],
        hourUnits: ["hour", "hours", "hr", "hrs", "h"],
        halfWords: ["half"],
        halfHourWords: [],
        oneAndAHalfWords: [],
        quarterWords: ["quarter"],
        conjunctions: ["and"],
        numbers: englishNumbers,
        // Contractions keep their apostrophe, because the tokenizer has to preserve the
        // one inside "п'ять", so they are listed in the form they actually arrive in.
        fillers: [
            "a", "an", "the", "my", "some", "i", "am", "is", "it", "to", "of", "for",
            "please", "let", "on", "up", "with", "was", "just",
            "i'm", "im", "let's", "lets", "it's", "its", "that's", "i've", "ive", "i'll"
        ],
        contextCues: [
            "deadline": .highPressure, "deadlines": .highPressure, "pressure": .highPressure,
            "urgent": .highPressure, "urgently": .highPressure, "rushed": .highPressure,
            "rushing": .highPressure, "stressed": .highPressure, "stressful": .highPressure,
            "crunch": .highPressure,
            "tired": .lowEnergy, "exhausted": .lowEnergy, "sleepy": .lowEnergy,
            "knackered": .lowEnergy, "drained": .lowEnergy,
            "distracted": .distracted, "noisy": .distracted, "interrupted": .distracted,
            "scattered": .distracted
        ]
    )

    public static let russian = VoiceLexicon(
        language: .russian,
        startVerbs: ["начинаю", "начать", "начал", "начала", "старт", "стартую", "запускаю"],
        endVerbs: ["заканчиваю", "закончить", "закончил", "закончила", "завершаю", "завершить", "конец", "стоп", "останавливаю", "готово"],
        guessMarkers: ["думаю", "примерно", "около", "где-то", "приблизительно", "наверное"],
        minuteUnits: ["минута", "минуту", "минуты", "минут", "мин"],
        hourUnits: ["час", "часа", "часов", "часу", "ч"],
        halfWords: ["половина", "половину"],
        halfHourWords: ["полчаса"],
        oneAndAHalfWords: ["полтора", "полторы"],
        quarterWords: ["четверть"],
        conjunctions: ["и"],
        numbers: russianNumbers,
        fillers: ["я", "мой", "моя", "мою", "это", "на", "в", "с", "по", "давай", "сейчас"],
        contextCues: [
            "дедлайн": .highPressure, "срочно": .highPressure, "спешу": .highPressure,
            "стресс": .highPressure, "давление": .highPressure,
            "устал": .lowEnergy, "устала": .lowEnergy, "усталый": .lowEnergy, "сонный": .lowEnergy,
            "отвлекают": .distracted, "шумно": .distracted, "отвлекаюсь": .distracted
        ]
    )

    public static let ukrainian = VoiceLexicon(
        language: .ukrainian,
        startVerbs: ["починаю", "почати", "почав", "почала", "старт", "стартую", "запускаю"],
        endVerbs: ["закінчую", "закінчити", "закінчив", "закінчила", "завершую", "завершити", "кінець", "стоп", "зупиняю", "готово"],
        guessMarkers: ["думаю", "приблизно", "близько", "десь", "мабуть", "орієнтовно"],
        minuteUnits: ["хвилина", "хвилину", "хвилини", "хвилин", "хв"],
        hourUnits: ["година", "годину", "години", "годин", "год"],
        halfWords: ["половина", "половину"],
        halfHourWords: ["півгодини"],
        oneAndAHalfWords: ["півтори", "півтора"],
        quarterWords: ["чверть"],
        conjunctions: ["і", "та"],
        numbers: ukrainianNumbers,
        fillers: ["я", "мій", "моя", "мою", "це", "на", "в", "у", "з", "по", "давай", "зараз"],
        contextCues: [
            "дедлайн": .highPressure, "терміново": .highPressure, "поспішаю": .highPressure,
            "стрес": .highPressure, "тиск": .highPressure,
            "втомився": .lowEnergy, "втомилася": .lowEnergy, "сонний": .lowEnergy,
            "відволікають": .distracted, "шумно": .distracted, "відволікаюся": .distracted
        ]
    )
}

// MARK: - Number words

private let englishNumbers: [String: Int] = {
    var table: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60,
        "seventy": 70, "eighty": 80, "ninety": 90
    ]
    // "a" and "an" carry a value only in front of a unit, as in "an hour". The scanner
    // resolves that; here they simply mean one.
    table["a"] = 1
    table["an"] = 1
    return table
}()

private let russianNumbers: [String: Int] = [
    "ноль": 0, "один": 1, "одна": 1, "одну": 1, "два": 2, "две": 2, "три": 3,
    "четыре": 4, "пять": 5, "шесть": 6, "семь": 7, "восемь": 8, "девять": 9,
    "десять": 10, "одиннадцать": 11, "двенадцать": 12, "тринадцать": 13,
    "четырнадцать": 14, "пятнадцать": 15, "шестнадцать": 16, "семнадцать": 17,
    "восемнадцать": 18, "девятнадцать": 19, "двадцать": 20, "тридцать": 30,
    "сорок": 40, "пятьдесят": 50, "шестьдесят": 60
]

private let ukrainianNumbers: [String: Int] = [
    "нуль": 0, "один": 1, "одна": 1, "одну": 1, "два": 2, "дві": 2, "три": 3,
    "чотири": 4, "п'ять": 5, "пять": 5, "шість": 6, "сім": 7, "вісім": 8, "дев'ять": 9,
    "девять": 9, "десять": 10, "одинадцять": 11, "дванадцять": 12, "тринадцять": 13,
    "чотирнадцять": 14, "п'ятнадцять": 15, "пятнадцять": 15, "шістнадцять": 16,
    "сімнадцять": 17, "вісімнадцять": 18, "дев'ятнадцять": 19, "двадцять": 20,
    "тридцять": 30, "сорок": 40, "п'ятдесят": 50, "пятдесят": 50, "шістдесят": 60
]
