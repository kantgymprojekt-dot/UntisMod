import Foundation
import CryptoKit

// MARK: - Lesson model

enum LessonStatus: String, CaseIterable, Identifiable, Codable {
    case normal = "Normal"
    case cancelled = "Cancelled"
    case roomChange = "Room change"
    case substitution = "Substitution"
    case exam = "Exam / Info"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .normal: return "Regular lesson"
        case .cancelled: return "Cancelled"
        case .roomChange: return "Room change"
        case .substitution: return "Substitution"
        case .exam: return "Exam / Info"
        }
    }
}

enum CancelledDisplayMode: String, CaseIterable, Identifiable, Codable {
    case strikethrough
    case hidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strikethrough: return "Show with strikethrough"
        case .hidden: return "Hide from timetable"
        }
    }
}

struct Lesson: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var dayIndex: Int
    var periodNumber: Int
    var subject: String
    var teacher: String
    var room: String
    var subjectColorHex: String
    var status: LessonStatus
    var cancelledDisplayMode: CancelledDisplayMode
    var originalSubject: String
    var originalTeacher: String
    var originalRoom: String
    var infoText: String

    init(
        id: UUID = UUID(),
        dayIndex: Int,
        periodNumber: Int,
        subject: String,
        teacher: String,
        room: String,
        subjectColorHex: String = "#E5F0F7",
        status: LessonStatus = .normal,
        cancelledDisplayMode: CancelledDisplayMode = .strikethrough,
        originalSubject: String = "",
        originalTeacher: String = "",
        originalRoom: String = "",
        infoText: String = ""
    ) {
        self.id = id
        self.dayIndex = dayIndex
        self.periodNumber = periodNumber
        self.subject = subject
        self.teacher = teacher
        self.room = room
        self.subjectColorHex = subjectColorHex
        self.status = status
        self.cancelledDisplayMode = cancelledDisplayMode
        self.originalSubject = originalSubject
        self.originalTeacher = originalTeacher
        self.originalRoom = originalRoom
        self.infoText = infoText
    }

    /// A cancelled lesson that the user chose to hide. It stays stored and is shown as a
    /// restorable "Hidden" slot while Edit Mode is active.
    var isHiddenFromTimetable: Bool {
        status == .cancelled && cancelledDisplayMode == .hidden
    }

    // Tolerant decoding so data saved by an older version of the app still loads.
    private enum CodingKeys: String, CodingKey {
        case id, dayIndex, periodNumber, subject, teacher, room, subjectColorHex
        case status, cancelledDisplayMode
        case originalSubject, originalTeacher, originalRoom, infoText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        dayIndex = try container.decode(Int.self, forKey: .dayIndex)
        periodNumber = try container.decode(Int.self, forKey: .periodNumber)
        subject = try container.decodeIfPresent(String.self, forKey: .subject) ?? ""
        teacher = try container.decodeIfPresent(String.self, forKey: .teacher) ?? ""
        room = try container.decodeIfPresent(String.self, forKey: .room) ?? ""
        subjectColorHex = try container.decodeIfPresent(String.self, forKey: .subjectColorHex) ?? "#E5F0F7"
        status = try container.decodeIfPresent(LessonStatus.self, forKey: .status) ?? .normal
        cancelledDisplayMode = try container.decodeIfPresent(CancelledDisplayMode.self, forKey: .cancelledDisplayMode) ?? .strikethrough
        originalSubject = try container.decodeIfPresent(String.self, forKey: .originalSubject) ?? ""
        originalTeacher = try container.decodeIfPresent(String.self, forKey: .originalTeacher) ?? ""
        originalRoom = try container.decodeIfPresent(String.self, forKey: .originalRoom) ?? ""
        infoText = try container.decodeIfPresent(String.self, forKey: .infoText) ?? ""
    }
}

struct PeriodDefinition: Identifiable, Codable, Equatable, Hashable {
    var number: Int
    var startTime: String
    var endTime: String

    var id: Int { number }
}

// MARK: - Default sample week

enum DefaultTimetable {
    static let periods: [PeriodDefinition] = [
        PeriodDefinition(number: 1, startTime: "08:00", endTime: "08:45"),
        PeriodDefinition(number: 2, startTime: "08:50", endTime: "09:35"),
        PeriodDefinition(number: 3, startTime: "09:55", endTime: "10:40"),
        PeriodDefinition(number: 4, startTime: "10:45", endTime: "11:30"),
        PeriodDefinition(number: 5, startTime: "11:50", endTime: "12:35"),
        PeriodDefinition(number: 6, startTime: "12:40", endTime: "13:25"),
        PeriodDefinition(number: 7, startTime: "13:30", endTime: "14:15"),
        PeriodDefinition(number: 8, startTime: "14:20", endTime: "15:05")
    ]

    static func lessons() -> [Lesson] {
        let blue = "#E5F0F7"
        let red = "#FCE8E3"
        let green = "#E3F5EC"
        let yellow = "#FFF2D7"
        let purple = "#F0E9FA"
        let grey = "#E9EDF1"

        func normal(_ day: Int, _ period: Int, _ subject: String, _ teacher: String, _ room: String, _ color: String) -> Lesson {
            Lesson(dayIndex: day, periodNumber: period, subject: subject, teacher: teacher, room: room, subjectColorHex: color)
        }

        return [
            // Monday
            normal(0, 1, "D", "MÜL", "R101", blue),
            normal(0, 2, "M", "SCH", "R204", red),
            normal(0, 3, "E", "WEB", "R105", green),
            normal(0, 4, "E", "WEB", "R105", green),
            normal(0, 5, "BIO", "KRA", "B02", yellow),
            normal(0, 6, "SP", "HOF", "TH1", purple),

            // Tuesday
            normal(1, 1, "M", "SCH", "R204", red),
            normal(1, 2, "M", "SCH", "R204", red),
            Lesson(dayIndex: 1, periodNumber: 3, subject: "PH", teacher: "BEC", room: "P01",
                   subjectColorHex: grey, status: .cancelled, cancelledDisplayMode: .strikethrough),
            normal(1, 4, "D", "MÜL", "R101", blue),
            normal(1, 5, "GE", "LAN", "R112", yellow),
            normal(1, 6, "KU", "FIS", "K01", purple),

            // Wednesday
            normal(2, 1, "E", "WEB", "R105", green),
            Lesson(dayIndex: 2, periodNumber: 2, subject: "CH", teacher: "KRA", room: "C03",
                   subjectColorHex: grey, status: .roomChange, originalRoom: "C01"),
            normal(2, 3, "D", "MÜL", "R101", blue),
            normal(2, 4, "M", "SCH", "R204", red),
            normal(2, 5, "REL", "BER", "R108", blue),

            // Thursday
            normal(3, 1, "SP", "HOF", "TH1", purple),
            normal(3, 2, "SP", "HOF", "TH1", purple),
            normal(3, 3, "BIO", "KRA", "B02", yellow),
            Lesson(dayIndex: 3, periodNumber: 4, subject: "M", teacher: "VOG", room: "R204",
                   subjectColorHex: red, status: .substitution, originalTeacher: "SCH"),
            normal(3, 5, "GE", "LAN", "R112", yellow),
            normal(3, 6, "E", "WEB", "R105", green),

            // Friday
            normal(4, 1, "D", "MÜL", "R101", blue),
            normal(4, 2, "M", "SCH", "R204", red),
            normal(4, 3, "PH", "BEC", "P01", grey),
            normal(4, 4, "CH", "KRA", "C01", grey),
            Lesson(dayIndex: 4, periodNumber: 5, subject: "E", teacher: "WEB", room: "R105",
                   subjectColorHex: green, status: .exam, infoText: "Vocabulary test"),
            Lesson(dayIndex: 4, periodNumber: 6, subject: "KU", teacher: "FIS", room: "K01",
                   subjectColorHex: purple, status: .cancelled, cancelledDisplayMode: .hidden)
        ]
    }
}

// MARK: - Timetable store (UserDefaults + JSON)

final class TimetableStore: ObservableObject {
    @Published private(set) var periods: [PeriodDefinition]
    @Published private(set) var lessons: [Lesson]

    private struct Snapshot: Codable {
        var periods: [PeriodDefinition]
        var lessons: [Lesson]
    }

    private let defaults: UserDefaults
    private static let storageKey = "untis.mobile.timetable.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Self.storageKey),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
           !snapshot.periods.isEmpty {
            self.periods = snapshot.periods.sorted { $0.number < $1.number }
            self.lessons = snapshot.lessons
        } else {
            self.periods = DefaultTimetable.periods
            self.lessons = DefaultTimetable.lessons()
        }
    }

    func lesson(dayIndex: Int, periodNumber: Int) -> Lesson? {
        lessons.first { $0.dayIndex == dayIndex && $0.periodNumber == periodNumber }
    }

    /// Inserts a new lesson or replaces the lesson with the same id.
    /// A slot holds one lesson, so any other lesson occupying the target slot is replaced.
    func upsert(_ lesson: Lesson) {
        lessons.removeAll {
            $0.id != lesson.id && $0.dayIndex == lesson.dayIndex && $0.periodNumber == lesson.periodNumber
        }
        if let index = lessons.firstIndex(where: { $0.id == lesson.id }) {
            lessons[index] = lesson
        } else {
            lessons.append(lesson)
        }
        save()
    }

    func delete(id: UUID) {
        lessons.removeAll { $0.id == id }
        save()
    }

    /// Restores the sample week. The edit code is stored elsewhere and is not touched.
    func resetToDefault() {
        periods = DefaultTimetable.periods
        lessons = DefaultTimetable.lessons()
        save()
    }

    private func save() {
        let snapshot = Snapshot(periods: periods, lessons: lessons)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - Edit code (salted SHA-256, attempt limit, persisted lockout)

enum PasscodeVerification: Equatable {
    case success
    case incorrect(Int)   // attempts remaining
    case locked
}

final class PasscodeStore: ObservableObject {
    static let codeLength = 4
    static let maxAttempts = 3
    static let lockoutDuration: TimeInterval = 5 * 60

    @Published private(set) var hasPasscode: Bool
    @Published private(set) var lockedUntil: Date?

    private let defaults: UserDefaults

    private enum Keys {
        static let salt = "untis.mobile.editCode.salt"
        static let hash = "untis.mobile.editCode.hash"
        static let failedAttempts = "untis.mobile.editCode.failedAttempts"
        static let lockedUntil = "untis.mobile.editCode.lockedUntil"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let hasSalt = defaults.string(forKey: Keys.salt) != nil
        let hasHash = defaults.string(forKey: Keys.hash) != nil
        self.hasPasscode = hasSalt && hasHash

        let stamp = defaults.double(forKey: Keys.lockedUntil)
        if stamp > 0 {
            let until = Date(timeIntervalSince1970: stamp)
            if until > Date() {
                self.lockedUntil = until
            } else {
                self.lockedUntil = nil
                defaults.removeObject(forKey: Keys.lockedUntil)
                defaults.set(0, forKey: Keys.failedAttempts)
            }
        } else {
            self.lockedUntil = nil
        }
    }

    /// Saves the code once. Returns false if a code already exists or the code is not four digits.
    /// There is deliberately no way to remove or change the code afterwards.
    @discardableResult
    func setPasscode(_ code: String) -> Bool {
        guard !hasPasscode, Self.isValid(code) else { return false }

        let salt = (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
        defaults.set(salt, forKey: Keys.salt)
        defaults.set(Self.digest(code: code, salt: salt), forKey: Keys.hash)
        defaults.set(0, forKey: Keys.failedAttempts)
        defaults.removeObject(forKey: Keys.lockedUntil)
        lockedUntil = nil
        hasPasscode = true
        return true
    }

    func verify(_ code: String) -> PasscodeVerification {
        if let until = lockedUntil {
            if until > Date() { return .locked }
            clearLock()
        }

        guard let salt = defaults.string(forKey: Keys.salt),
              let stored = defaults.string(forKey: Keys.hash) else {
            return .incorrect(Self.maxAttempts)
        }

        if Self.digest(code: code, salt: salt) == stored {
            defaults.set(0, forKey: Keys.failedAttempts)
            return .success
        }

        let attempts = defaults.integer(forKey: Keys.failedAttempts) + 1
        if attempts >= Self.maxAttempts {
            let until = Date().addingTimeInterval(Self.lockoutDuration)
            defaults.set(0, forKey: Keys.failedAttempts)
            defaults.set(until.timeIntervalSince1970, forKey: Keys.lockedUntil)
            lockedUntil = until
            return .locked
        }

        defaults.set(attempts, forKey: Keys.failedAttempts)
        return .incorrect(Self.maxAttempts - attempts)
    }

    private func clearLock() {
        lockedUntil = nil
        defaults.removeObject(forKey: Keys.lockedUntil)
        defaults.set(0, forKey: Keys.failedAttempts)
    }

    private static func isValid(_ code: String) -> Bool {
        code.count == codeLength && code.allSatisfy { $0.isASCII && $0.isNumber }
    }

    private static func digest(code: String, salt: String) -> String {
        let hash = SHA256.hash(data: Data((salt + code).utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
