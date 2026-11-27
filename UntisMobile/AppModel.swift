import Foundation
import SwiftUI

// MARK: - Stored profile

struct UntisProfile: Codable, Equatable {
    var server: String
    var school: String
    var schoolName: String
    var username: String
    var personType: Int
    var personId: Int
    var klasseId: Int
}

/// What the timetable currently shows: a class, a teacher, or the logged-in student.
struct TimetableElement: Codable, Equatable, Hashable {
    var type: Int
    var id: Int
    var name: String
}

// MARK: - Live Untis state

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var profile: UntisProfile?
    @Published private(set) var element: TimetableElement?
    @Published private(set) var livePeriods: [PeriodDefinition] = DefaultTimetable.periods
    @Published private(set) var weeks: [Int: [TimetableEntry]] = [:]
    @Published private(set) var loadingWeeks: Set<Int> = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var klassen: [UntisKlasse] = []
    @Published private(set) var klassenError: String?

    private let client = UntisClient()
    private let defaults = UserDefaults.standard
    private var session: UntisSession?
    private var hasLoadedGrid = false

    private static let profileKey = "untis.mobile.profile.v1"
    private static let elementKey = "untis.mobile.element.v1"

    var isLive: Bool { profile != nil }
    var isLoading: Bool { !loadingWeeks.isEmpty }

    init() {
        if let data = defaults.data(forKey: Self.profileKey),
           let stored = try? JSONDecoder().decode(UntisProfile.self, from: data) {
            profile = stored
            if let elementData = defaults.data(forKey: Self.elementKey),
               let storedElement = try? JSONDecoder().decode(TimetableElement.self, from: elementData) {
                element = storedElement
            } else {
                element = Self.ownElement(for: stored)
            }
        }
    }

    // MARK: Account

    func searchSchools(_ term: String) async throws -> [UntisSchool] {
        try await client.searchSchools(term)
    }

    func login(school: UntisSchool, username: String, password: String) async throws {
        let newSession = try await client.authenticate(
            server: school.server,
            school: school.loginName,
            user: username,
            password: password
        )
        let newProfile = UntisProfile(
            server: school.server,
            school: school.loginName,
            schoolName: school.displayName,
            username: username,
            personType: newSession.personType,
            personId: newSession.personId,
            klasseId: newSession.klasseId
        )
        Keychain.save(password, account: Self.keychainAccount(for: newProfile))

        session = newSession
        profile = newProfile
        element = Self.ownElement(for: newProfile)
        resetData()
        persist()
    }

    func logout() {
        let oldProfile = profile
        let oldSession = session

        if let oldProfile { Keychain.delete(account: Self.keychainAccount(for: oldProfile)) }
        profile = nil
        element = nil
        session = nil
        resetData()
        defaults.removeObject(forKey: Self.profileKey)
        defaults.removeObject(forKey: Self.elementKey)

        if let oldSession {
            let client = self.client
            Task { await client.logout(oldSession) }
        }
    }

    // MARK: Selection

    var isOwnTimetableSelected: Bool {
        guard let profile else { return false }
        return element == Self.ownElement(for: profile)
    }

    func selectOwnTimetable() {
        guard let profile else { return }
        select(Self.ownElement(for: profile))
    }

    func select(_ newElement: TimetableElement) {
        element = newElement
        weeks = [:]
        errorMessage = nil
        persist()
    }

    func loadKlassen() async {
        guard profile != nil else { return }
        do {
            let loaded = try await withSession { try await client.klassen($0) }
            klassen = loaded.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            klassenError = nil
        } catch {
            klassenError = error.localizedDescription
        }
    }

    // MARK: Timetable data

    func entries(for date: Date) -> [TimetableEntry] {
        let monday = UntisCalendar.key(UntisCalendar.monday(of: date))
        let dayKey = UntisCalendar.key(date)
        return (weeks[monday] ?? []).filter { UntisCalendar.key($0.date) == dayKey }
    }

    /// Loads every week that the given dates touch. Weeks that are already cached are skipped.
    func ensureLoaded(for dates: [Date], force: Bool = false) async {
        guard profile != nil, let element else { return }
        let mondays = Set(dates.map { UntisCalendar.key(UntisCalendar.monday(of: $0)) }).sorted()
        for key in mondays {
            if !force, weeks[key] != nil { continue }
            await loadWeek(mondayKey: key, element: element)
        }
    }

    private func loadWeek(mondayKey: Int, element requested: TimetableElement) async {
        guard let monday = UntisCalendar.date(fromKey: mondayKey) else { return }
        let friday = UntisCalendar.addingDays(monday, 4)

        loadingWeeks.insert(mondayKey)
        defer { loadingWeeks.remove(mondayKey) }

        do {
            await loadGridIfNeeded()
            let raw = try await withSession {
                try await client.timetable($0, elementType: requested.type, elementId: requested.id, from: monday, to: friday)
            }
            guard element == requested else { return }

            if !hasLoadedGrid {
                let derived = Self.derivePeriods(from: raw)
                if !derived.isEmpty { livePeriods = derived }
            }
            weeks[mondayKey] = Self.convert(raw, periods: livePeriods)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadGridIfNeeded() async {
        guard !hasLoadedGrid else { return }
        guard let grid = try? await withSession({ try await client.timegrid($0) }) else { return }

        let day = grid.first(where: { $0.day == 2 && !$0.timeUnits.isEmpty })
            ?? grid.first(where: { !$0.timeUnits.isEmpty })
        guard let units = day?.timeUnits.sorted(by: { $0.startTime < $1.startTime }), !units.isEmpty else { return }

        livePeriods = units.enumerated().map { index, unit in
            PeriodDefinition(
                number: Int(unit.name) ?? index + 1,
                startTime: UntisCalendar.clock(fromHHmm: unit.startTime),
                endTime: UntisCalendar.clock(fromHHmm: unit.endTime)
            )
        }
        hasLoadedGrid = true
    }

    // MARK: Session handling

    private func currentSession() async throws -> UntisSession {
        if let session { return session }
        guard let profile,
              let password = Keychain.load(account: Self.keychainAccount(for: profile)) else {
            throw UntisError.notLoggedIn
        }
        let fresh = try await client.authenticate(
            server: profile.server,
            school: profile.school,
            user: profile.username,
            password: password
        )
        session = fresh
        return fresh
    }

    /// Runs a call and, if the Untis session has expired, logs in again once and retries.
    private func withSession<T>(_ work: (UntisSession) async throws -> T) async throws -> T {
        let active = try await currentSession()
        do {
            return try await work(active)
        } catch let error as UntisError where error.isSessionExpired {
            session = nil
            let fresh = try await currentSession()
            return try await work(fresh)
        }
    }

    // MARK: Helpers

    private func resetData() {
        weeks = [:]
        loadingWeeks = []
        errorMessage = nil
        klassen = []
        klassenError = nil
        hasLoadedGrid = false
        livePeriods = DefaultTimetable.periods
    }

    private func persist() {
        if let profile, let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Self.profileKey)
        }
        if let element, let data = try? JSONEncoder().encode(element) {
            defaults.set(data, forKey: Self.elementKey)
        }
    }

    private static func keychainAccount(for profile: UntisProfile) -> String {
        "\(profile.server)|\(profile.school)|\(profile.username)"
    }

    private static func ownElement(for profile: UntisProfile) -> TimetableElement {
        // personType: 1 class, 2 teacher, 5 student. A student without own rights falls back to the class.
        TimetableElement(type: profile.personType == 0 ? 5 : profile.personType, id: profile.personId, name: profile.username)
    }

    // MARK: Conversion from the Untis JSON to display entries

    private static let subjectPalette = ["#E5F0F7", "#FCE8E3", "#E3F5EC", "#FFF2D7", "#F0E9FA", "#E9EDF1"]

    private static func colorHex(for subject: String) -> String {
        var hash: UInt32 = 5381
        for scalar in subject.unicodeScalars {
            hash = (hash &* 33) &+ scalar.value
        }
        return subjectPalette[Int(hash % UInt32(subjectPalette.count))]
    }

    private static func joined(_ elements: [RawElement]?, long: Bool = false) -> String {
        let names = (elements ?? []).compactMap { element -> String? in
            let value = long ? (element.longname ?? element.name) : element.name
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return names.joined(separator: ", ")
    }

    private static func originals(_ elements: [RawElement]?) -> String {
        (elements ?? [])
            .compactMap { $0.orgname }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private static func derivePeriods(from raw: [RawPeriod]) -> [PeriodDefinition] {
        var seen = Set<Int>()
        var pairs: [(start: Int, end: Int)] = []
        for item in raw where item.endTime > item.startTime {
            if seen.insert(item.startTime * 10_000 + item.endTime).inserted {
                pairs.append((start: item.startTime, end: item.endTime))
            }
        }
        pairs.sort { ($0.start, $0.end) < ($1.start, $1.end) }

        var cleaned: [(start: Int, end: Int)] = []
        for pair in pairs {
            if let last = cleaned.last, pair.start < last.end { continue }
            cleaned.append(pair)
        }
        return cleaned.enumerated().map { index, pair in
            PeriodDefinition(
                number: index + 1,
                startTime: UntisCalendar.clock(fromHHmm: pair.start),
                endTime: UntisCalendar.clock(fromHHmm: pair.end)
            )
        }
    }

    private static func convert(_ raw: [RawPeriod], periods: [PeriodDefinition]) -> [TimetableEntry] {
        let bounds = periods.map {
            (start: UntisCalendar.minutes(fromClock: $0.startTime), end: UntisCalendar.minutes(fromClock: $0.endTime))
        }

        var byDay: [Int: [TimetableEntry]] = [:]

        for (offset, item) in raw.enumerated() {
            guard let date = UntisCalendar.date(fromKey: item.date) else { continue }
            let start = UntisCalendar.minutes(fromHHmm: item.startTime)
            let end = UntisCalendar.minutes(fromHHmm: item.endTime)

            let rows = bounds.indices.filter { bounds[$0].start < end && bounds[$0].end > start }
            guard let first = rows.first, let last = rows.last else { continue }

            let teacherChanged = (item.te ?? []).contains { $0.isChanged }
            let roomChanged = (item.ro ?? []).contains { $0.isChanged }
            let subjectChanged = (item.su ?? []).contains { $0.isChanged }

            let status: LessonStatus
            if item.code == "cancelled" {
                status = .cancelled
            } else if item.lstype == "ex" {
                status = .exam
            } else if item.code == "irregular" || teacherChanged || roomChanged || subjectChanged {
                status = (roomChanged && !teacherChanged && !subjectChanged) ? .roomChange : .substitution
            } else {
                status = .normal
            }

            let notes = [item.lstext, item.substText, item.info]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            var uniqueNotes: [String] = []
            for note in notes where !uniqueNotes.contains(note) { uniqueNotes.append(note) }

            let subject = joined(item.su)
            var entry = TimetableEntry(
                id: "\(item.id ?? 0)-\(item.date)-\(item.startTime)-\(offset)",
                date: UntisCalendar.startOfDay(date),
                startRow: first,
                span: last - first + 1
            )
            entry.subject = subject
            entry.subjectLong = joined(item.su, long: true)
            entry.teacher = joined(item.te)
            entry.teacherLong = joined(item.te, long: true)
            entry.room = joined(item.ro)
            entry.roomLong = joined(item.ro, long: true)
            entry.classNames = joined(item.kl)
            entry.status = status
            entry.originalSubject = originals(item.su)
            entry.originalTeacher = originals(item.te)
            entry.originalRoom = originals(item.ro)
            entry.infoText = uniqueNotes.joined(separator: "\n")
            entry.startTime = UntisCalendar.clock(fromHHmm: item.startTime)
            entry.endTime = UntisCalendar.clock(fromHHmm: item.endTime)
            entry.colorHex = colorHex(for: subject)

            byDay[item.date, default: []].append(entry)
        }

        return byDay.values.flatMap { EntryBuilder.mergeConsecutive($0) }
    }
}
