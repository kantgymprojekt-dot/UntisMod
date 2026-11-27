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

// MARK: - Calendar helpers (ISO weeks, Monday–Friday timetable)

enum UntisCalendar {
    static let calendar = Calendar(identifier: .iso8601)

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// 0 = Monday … 6 = Sunday
    static func dayIndex(of date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)   // 1 = Sunday … 7 = Saturday
        return (weekday + 5) % 7
    }

    static func isWeekend(_ date: Date) -> Bool {
        dayIndex(of: date) >= 5
    }

    /// Saturday and Sunday move forward to the next Monday.
    static func normalized(_ date: Date) -> Date {
        let day = startOfDay(date)
        switch dayIndex(of: day) {
        case 5: return calendar.date(byAdding: .day, value: 2, to: day) ?? day
        case 6: return calendar.date(byAdding: .day, value: 1, to: day) ?? day
        default: return day
        }
    }

    static func monday(of date: Date) -> Date {
        let day = startOfDay(date)
        return calendar.date(byAdding: .day, value: -dayIndex(of: day), to: day) ?? day
    }

    /// Moves by school days only; weekends are skipped. `count` may be negative.
    static func addingWeekdays(_ date: Date, _ count: Int) -> Date {
        var result = startOfDay(date)
        let step = count >= 0 ? 1 : -1
        var remaining = abs(count)
        while remaining > 0 {
            result = calendar.date(byAdding: .day, value: step, to: result) ?? result
            if !isWeekend(result) { remaining -= 1 }
        }
        return result
    }

    static func addingDays(_ date: Date, _ count: Int) -> Date {
        calendar.date(byAdding: .day, value: count, to: startOfDay(date)) ?? date
    }

    /// yyyymmdd, the date format used by the Untis JSON-RPC API.
    static func key(_ date: Date) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }

    static func date(fromKey key: Int) -> Date? {
        var parts = DateComponents()
        parts.year = key / 10_000
        parts.month = (key / 100) % 100
        parts.day = key % 100
        return calendar.date(from: parts)
    }

    static func weekNumber(of date: Date) -> Int {
        calendar.component(.weekOfYear, from: date)
    }

    /// 815 -> 495 minutes
    static func minutes(fromHHmm value: Int) -> Int {
        (value / 100) * 60 + value % 100
    }

    /// "08:15" -> 495 minutes
    static func minutes(fromClock text: String) -> Int {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1]) else { return 0 }
        return hours * 60 + minutes
    }

    /// 815 -> "08:15"
    static func clock(fromHHmm value: Int) -> String {
        String(format: "%02d:%02d", value / 100, value % 100)
    }
}

// MARK: - Unified display model (demo lessons and live Untis data both become entries)

struct TimetableEntry: Identifiable, Hashable {
    var id: String
    var date: Date
    var startRow: Int
    var span: Int = 1

    var subject: String = ""
    var subjectLong: String = ""
    var teacher: String = ""
    var teacherLong: String = ""
    var room: String = ""
    var roomLong: String = ""
    var classNames: String = ""

    var status: LessonStatus = .normal
    var originalSubject: String = ""
    var originalTeacher: String = ""
    var originalRoom: String = ""
    var infoText: String = ""

    var startTime: String = ""
    var endTime: String = ""
    var colorHex: String = "#E5F0F7"

    /// Edit mode only: an empty slot that can be filled, or a cancelled lesson the user hid.
    var isPlaceholder: Bool = false
    var isHidden: Bool = false

    var endRow: Int { startRow + span }

    func hasSameContent(as other: TimetableEntry) -> Bool {
        UntisCalendar.key(date) == UntisCalendar.key(other.date)
            && subject == other.subject
            && teacher == other.teacher
            && room == other.room
            && classNames == other.classNames
            && status == other.status
            && originalSubject == other.originalSubject
            && originalTeacher == other.originalTeacher
            && originalRoom == other.originalRoom
            && infoText == other.infoText
            && isPlaceholder == other.isPlaceholder
            && isHidden == other.isHidden
    }
}

enum EntryBuilder {
    /// Builds the entries of the offline demo week for one date.
    static func demoEntries(
        for date: Date,
        lessons: [Lesson],
        periods: [PeriodDefinition],
        isEditMode: Bool,
        showCancelled: Bool
    ) -> [TimetableEntry] {
        let dayIndex = UntisCalendar.dayIndex(of: date)
        guard dayIndex < 5 else { return [] }
        let day = UntisCalendar.startOfDay(date)

        var result: [TimetableEntry] = []
        for (row, period) in periods.enumerated() {
            if let lesson = lessons.first(where: { $0.dayIndex == dayIndex && $0.periodNumber == period.number }) {
                let hidden = lesson.isHiddenFromTimetable || (lesson.status == .cancelled && !showCancelled)
                if hidden && !isEditMode { continue }

                var entry = TimetableEntry(id: lesson.id.uuidString, date: day, startRow: row)
                entry.subject = lesson.subject
                entry.teacher = lesson.teacher
                entry.room = lesson.room
                entry.status = lesson.status
                entry.originalSubject = lesson.originalSubject
                entry.originalTeacher = lesson.originalTeacher
                entry.originalRoom = lesson.originalRoom
                entry.infoText = lesson.infoText
                entry.startTime = period.startTime
                entry.endTime = period.endTime
                entry.colorHex = lesson.subjectColorHex
                entry.isHidden = hidden
                result.append(entry)
            } else if isEditMode {
                var placeholder = TimetableEntry(id: "empty-\(dayIndex)-\(period.number)", date: day, startRow: row)
                placeholder.startTime = period.startTime
                placeholder.endTime = period.endTime
                placeholder.isPlaceholder = true
                result.append(placeholder)
            }
        }
        // While editing, every period stays its own tappable slot.
        return isEditMode ? result : mergeConsecutive(result)
    }

    /// Joins directly adjacent identical periods into one block (a double period has span 2).
    static func mergeConsecutive(_ entries: [TimetableEntry]) -> [TimetableEntry] {
        let sorted = entries.sorted { ($0.startRow, $0.id) < ($1.startRow, $1.id) }
        var merged: [TimetableEntry] = []

        for entry in sorted {
            if entry.isPlaceholder || entry.isHidden {
                merged.append(entry)
                continue
            }
            if let index = merged.lastIndex(where: { $0.endRow == entry.startRow && $0.hasSameContent(as: entry) }) {
                merged[index].span += entry.span
                merged[index].endTime = entry.endTime
            } else {
                merged.append(entry)
            }
        }
        return merged
    }
}

// MARK: - Side-by-side layout for lessons that run in parallel

struct PositionedEntry: Identifiable {
    let entry: TimetableEntry
    let column: Int
    let columns: Int

    var id: String { entry.id }
}

enum EntryLayout {
    static func position(_ entries: [TimetableEntry]) -> [PositionedEntry] {
        let sorted = entries.sorted { ($0.startRow, -$0.span) < ($1.startRow, -$1.span) }

        var output: [PositionedEntry] = []
        var cluster: [(entry: TimetableEntry, column: Int)] = []
        var columnEnds: [Int] = []
        var clusterEnd = 0

        func flush() {
            let count = max(columnEnds.count, 1)
            for item in cluster {
                output.append(PositionedEntry(entry: item.entry, column: item.column, columns: count))
            }
            cluster.removeAll()
            columnEnds.removeAll()
            clusterEnd = 0
        }

        for entry in sorted {
            if !cluster.isEmpty && entry.startRow >= clusterEnd { flush() }

            if let free = columnEnds.firstIndex(where: { $0 <= entry.startRow }) {
                columnEnds[free] = entry.endRow
                cluster.append((entry: entry, column: free))
            } else {
                columnEnds.append(entry.endRow)
                cluster.append((entry: entry, column: columnEnds.count - 1))
            }
            clusterEnd = max(clusterEnd, entry.endRow)
        }
        flush()
        return output
    }
}
