import Foundation
import Combine
import CryptoKit

// MARK: - Timetable domain

enum LessonStatus: String, CaseIterable, Codable, Identifiable {
    case normal = "Normal"
    case cancelled = "Cancelled (Entfall)"
    case roomChange = "Room Change (Raumänderung)"
    case substitution = "Substitution (Vertretung)"
    case exam = "Exam / Info"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .normal: return "Normal"
        case .cancelled: return "Entfall"
        case .roomChange: return "Raumänderung"
        case .substitution: return "Vertretung"
        case .exam: return "Exam / Info"
        }
    }
}

enum CancelledDisplayMode: String, CaseIterable, Codable, Identifiable {
    case strikethrough
    case hidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strikethrough: return "Show with strikethrough"
        case .hidden: return "Hide lesson"
        }
    }
}

struct PeriodDefinition: Identifiable, Codable, Hashable {
    let number: Int
    var startTime: String
    var endTime: String

    var id: Int { number }
}

struct Lesson: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var dayIndex: Int
    var periodNumber: Int
    var subject: String
    var teacher: String
    var room: String
    var status: LessonStatus = .normal
    var originalSubject: String = ""
    var originalTeacher: String = ""
    var originalRoom: String = ""
    var infoText: String = ""
    var cancelledDisplayMode: CancelledDisplayMode = .strikethrough
    var subjectColorHex: String = "#E5F0F7"

    var isHiddenFromTimetable: Bool {
        status == .cancelled && cancelledDisplayMode == .hidden
    }
}

struct TimetableDocument: Codable {
    var periods: [PeriodDefinition]
    var lessons: [Lesson]
}

// MARK: - Local sample timetable

enum DemoTimetable {
    static let periods: [PeriodDefinition] = [
        PeriodDefinition(number: 1, startTime: "08:00", endTime: "08:45"),
        PeriodDefinition(number: 2, startTime: "08:50", endTime: "09:35"),
        PeriodDefinition(number: 3, startTime: "09:50", endTime: "10:35"),
        PeriodDefinition(number: 4, startTime: "10:40", endTime: "11:25"),
        PeriodDefinition(number: 5, startTime: "11:40", endTime: "12:25"),
        PeriodDefinition(number: 6, startTime: "12:30", endTime: "13:15"),
        PeriodDefinition(number: 7, startTime: "13:30", endTime: "14:15"),
        PeriodDefinition(number: 8, startTime: "14:20", endTime: "15:05")
    ]

    static func makeDocument() -> TimetableDocument {
        func lesson(
            _ day: Int,
            _ period: Int,
            _ subject: String,
            _ teacher: String,
            _ room: String,
            _ color: String,
            status: LessonStatus = .normal,
            oldSubject: String = "",
            oldTeacher: String = "",
            oldRoom: String = "",
            info: String = "",
            cancellation: CancelledDisplayMode = .strikethrough
        ) -> Lesson {
            Lesson(
                dayIndex: day,
                periodNumber: period,
                subject: subject,
                teacher: teacher,
                room: room,
                status: status,
                originalSubject: oldSubject,
                originalTeacher: oldTeacher,
                originalRoom: oldRoom,
                infoText: info,
                cancelledDisplayMode: cancellation,
                subjectColorHex: color
            )
        }

        let lessons: [Lesson] = [
            // Monday
            lesson(0, 1, "Ma", "KLE", "B204", "#E5F0F7"),
            lesson(0, 2, "Eng", "WAG", "B101", "#FCE8E3"),
            lesson(0, 3, "Bio", "RIC", "N203", "#E3F5EC"),
            lesson(0, 4, "Ph", "HOF", "P106", "#E3EEF9"),
            lesson(0, 5, "D", "BER", "A305", "#FFF2D7"),
            lesson(0, 6, "Gesch", "LEM", "A203", "#E9EDF1"),
            lesson(0, 7, "Mu", "STU", "M01", "#F0E9FA"),

            // Tuesday
            lesson(1, 1, "Eng", "WAG", "B101", "#FCE8E3"),
            lesson(1, 2, "Geo", "SOM", "C112", "#E9EDF1"),
            lesson(1, 3, "Ma", "KLE", "B204", "#E5F0F7"),
            lesson(1, 4, "Fr", "DEL", "B208", "#FFF2D7"),
            lesson(1, 5, "Ch", "BRA", "N204", "#E3F5EC", status: .substitution, oldSubject: "Ph", oldTeacher: "HOF", info: "Substitute lesson"),
            lesson(1, 6, "Sport", "KRA", "TH1", "#F0E9FA"),
            lesson(1, 7, "Sport", "KRA", "TH1", "#F0E9FA"),

            // Wednesday
            lesson(2, 1, "Bio", "RIC", "N203", "#E3F5EC"),
            lesson(2, 2, "D", "BER", "A305", "#FFF2D7"),
            lesson(2, 3, "Eng", "WAG", "B101", "#FCE8E3"),
            lesson(2, 4, "Ku", "STU", "K02", "#F0E9FA", status: .cancelled, info: "This lesson has been cancelled"),
            lesson(2, 5, "Ma", "KLE", "B204", "#E5F0F7"),
            lesson(2, 6, "Geo", "SOM", "C112", "#E9EDF1"),
            lesson(2, 7, "Ch", "BRA", "N204", "#E3F5EC", status: .exam, info: "Chemistry test · Chapters 3–5"),

            // Thursday
            lesson(3, 1, "Ph", "HOF", "P204", "#E3EEF9", status: .roomChange, oldRoom: "P106", info: "Moved to the physics laboratory"),
            lesson(3, 2, "Ma", "KLE", "B204", "#E5F0F7"),
            lesson(3, 3, "Gesch", "LEM", "A203", "#E9EDF1"),
            lesson(3, 4, "Eng", "WAG", "B101", "#FCE8E3"),
            lesson(3, 5, "Bio", "RIC", "N203", "#E3F5EC", status: .exam, info: "Biology test · Cells and genetics"),
            lesson(3, 6, "D", "BER", "A305", "#FFF2D7"),
            lesson(3, 7, "Ethik", "MEY", "A108", "#F0E9FA"),

            // Friday
            lesson(4, 1, "Ma", "KLE", "B204", "#E5F0F7"),
            lesson(4, 2, "Fr", "DEL", "B208", "#FFF2D7"),
            lesson(4, 3, "Bio", "RIC", "N203", "#E3F5EC"),
            lesson(4, 4, "Eng", "WAG", "B101", "#FCE8E3"),
            lesson(4, 5, "D", "BER", "A305", "#FFF2D7"),
            lesson(4, 6, "Ph", "HOF", "P106", "#E3EEF9"),
            lesson(4, 7, "Info", "WEB", "C205", "#E9EDF1", status: .exam, info: "Project presentations")
        ]
        return TimetableDocument(periods: periods, lessons: lessons)
    }
}

// MARK: - UserDefaults JSON persistence

final class TimetableStore: ObservableObject {
    @Published private(set) var lessons: [Lesson]
    @Published private(set) var periods: [PeriodDefinition]

    private let defaults: UserDefaults
    private let storageKey = "untis.mobile.ios.timetable.document.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let document = try? JSONDecoder().decode(TimetableDocument.self, from: data),
           !document.periods.isEmpty {
            lessons = document.lessons
            periods = document.periods
        } else {
            let document = DemoTimetable.makeDocument()
            lessons = document.lessons
            periods = document.periods
            if let data = try? JSONEncoder().encode(document) {
                defaults.set(data, forKey: storageKey)
            }
        }
    }

    func lesson(dayIndex: Int, periodNumber: Int) -> Lesson? {
        lessons.first { $0.dayIndex == dayIndex && $0.periodNumber == periodNumber }
    }

    func upsert(_ lesson: Lesson) {
        var updated = lessons.filter {
            $0.id != lesson.id && !($0.dayIndex == lesson.dayIndex && $0.periodNumber == lesson.periodNumber)
        }
        updated.append(lesson)
        updated.sort {
            if $0.dayIndex == $1.dayIndex { return $0.periodNumber < $1.periodNumber }
            return $0.dayIndex < $1.dayIndex
        }
        lessons = updated
        persist()
    }

    func delete(id: UUID) {
        lessons.removeAll { $0.id == id }
        persist()
    }

    func resetToDefault() {
        let document = DemoTimetable.makeDocument()
        lessons = document.lessons
        periods = document.periods
        persist()
    }

    private func persist() {
        let document = TimetableDocument(periods: periods, lessons: lessons)
        guard let data = try? JSONEncoder().encode(document) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

// MARK: - Local four-digit editing passcode

struct PasscodeLockState {
    let attemptsRemaining: Int
    let lockedUntil: Date?
}

enum PasscodeVerificationResult {
    case success
    case incorrect(attemptsRemaining: Int)
    case locked(until: Date)
}

final class PasscodeStore: ObservableObject {
    @Published private(set) var hasPasscode: Bool
    @Published private(set) var failedAttempts: Int
    @Published private(set) var lockedUntil: Date?

    private let defaults: UserDefaults
    private let hashKey = "untis.mobile.ios.passcode.hash.v1"
    private let saltKey = "untis.mobile.ios.passcode.salt.v1"
    private let attemptsKey = "untis.mobile.ios.passcode.attempts.v1"
    private let lockedUntilKey = "untis.mobile.ios.passcode.lockedUntil.v1"
    private let lockDuration: TimeInterval = 5 * 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasPasscode = defaults.string(forKey: hashKey) != nil && defaults.string(forKey: saltKey) != nil
        failedAttempts = defaults.integer(forKey: attemptsKey)
        lockedUntil = defaults.object(forKey: lockedUntilKey) as? Date
        normalizeLockState()
    }

    func setPasscode(_ code: String) -> Bool {
        guard code.count == 4, code.allSatisfy({ $0.isNumber }), !hasPasscode else { return false }
        let salt = Data(UUID().uuidString.utf8)
        let hash = digest(code, salt: salt)
        defaults.set(salt.base64EncodedString(), forKey: saltKey)
        defaults.set(hash.base64EncodedString(), forKey: hashKey)
        defaults.set(0, forKey: attemptsKey)
        defaults.removeObject(forKey: lockedUntilKey)
        hasPasscode = true
        failedAttempts = 0
        lockedUntil = nil
        return true
    }

    func verify(_ code: String, now: Date = Date()) -> PasscodeVerificationResult {
        normalizeLockState(now: now)
        if let lockDate = lockedUntil, lockDate > now {
            return .locked(until: lockDate)
        }
        guard hasPasscode,
              let saltString = defaults.string(forKey: saltKey),
              let hashString = defaults.string(forKey: hashKey),
              let salt = Data(base64Encoded: saltString),
              let savedHash = Data(base64Encoded: hashString) else {
            return .incorrect(attemptsRemaining: 3)
        }

        let candidate = digest(code, salt: salt)
        if constantTimeEqual(candidate, savedHash) {
            failedAttempts = 0
            defaults.set(0, forKey: attemptsKey)
            lockedUntil = nil
            defaults.removeObject(forKey: lockedUntilKey)
            return .success
        }

        failedAttempts += 1
        if failedAttempts >= 3 {
            let expiry = now.addingTimeInterval(lockDuration)
            lockedUntil = expiry
            defaults.set(expiry, forKey: lockedUntilKey)
            defaults.set(3, forKey: attemptsKey)
            return .locked(until: expiry)
        }

        defaults.set(failedAttempts, forKey: attemptsKey)
        return .incorrect(attemptsRemaining: 3 - failedAttempts)
    }

    func timeRemaining(now: Date = Date()) -> TimeInterval {
        normalizeLockState(now: now)
        guard let lockedUntil, lockedUntil > now else { return 0 }
        return lockedUntil.timeIntervalSince(now)
    }

    private func normalizeLockState(now: Date = Date()) {
        if let lockedUntil, lockedUntil <= now {
            self.lockedUntil = nil
            failedAttempts = 0
            defaults.removeObject(forKey: lockedUntilKey)
            defaults.set(0, forKey: attemptsKey)
        }
    }

    private func digest(_ code: String, salt: Data) -> Data {
        var input = Data("UntisMobileLocalEditGate.v1".utf8)
        input.append(salt)
        input.append(Data(code.utf8))
        return Data(SHA256.hash(data: input))
    }

    private func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for index in 0..<lhs.count { difference |= lhs[index] ^ rhs[index] }
        return difference == 0
    }
}
