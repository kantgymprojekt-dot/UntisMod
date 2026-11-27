import SwiftUI
import UIKit

// MARK: - App navigation

private enum MainTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case timetable = "Timetable"
    case profile = "Profile"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .home: return "untis_ic_home"
        case .timetable: return "untis_ic_timetable"
        case .profile: return "untis_ic_profile"
        }
    }

    var symbolName: String {
        switch self {
        case .home: return "building.2"
        case .timetable: return "calendar"
        case .profile: return "person.crop.circle"
        }
    }
}

private enum TimetableViewMode: String, CaseIterable, Identifiable {
    case day = "Day"
    case twoDays = "2 Days"
    case threeDays = "3 Days"
    case week = "Week"

    var id: String { rawValue }

    var numberOfDays: Int {
        switch self {
        case .day: return 1
        case .twoDays: return 2
        case .threeDays: return 3
        case .week: return 5
        }
    }
}

private enum AppSheetKind {
    case lessonEditor(Lesson, isNew: Bool)
    case setPasscode
    case enterPasscode
    case goToDate
    case classPicker
    case options
    case help
    case info
}

private struct AppSheet: Identifiable {
    let id = UUID()
    let kind: AppSheetKind
}

/// Full-screen pages are kept in one enum so SwiftUI only has one cover to manage.
private enum FullScreenPage: Identifiable {
    case login
    case lesson(TimetableEntry, periodLabel: String)

    var id: String {
        switch self {
        case .login: return "login"
        case .lesson(let entry, _): return "lesson-\(entry.id)"
        }
    }
}

// MARK: - Main screen

struct ContentView: View {
    @StateObject private var app = AppModel()
    @StateObject private var timetable = TimetableStore()
    @StateObject private var passcodes = PasscodeStore()

    @State private var selectedTab: MainTab = .timetable
    @State private var selectedDate = UntisCalendar.normalized(Date())
    @State private var displayMode: TimetableViewMode = .day
    @State private var isEditMode = false
    @State private var activeSheet: AppSheet?
    @State private var fullScreenPage: FullScreenPage?
    @State private var showResetConfirmation = false
    @State private var refreshToken = 0

    @AppStorage("untis.mobile.showCancelledLessons") private var showCancelledLessons = true
    @AppStorage("untis.mobile.showRooms") private var showRooms = true
    @AppStorage("untis.mobile.showSubjectColours") private var showSubjectColours = true
    @AppStorage("untis.mobile.zoom") private var storedZoom = 1.0
    @AppStorage("untis.mobile.onboardingDone") private var onboardingDone = false

    private let timeColumnWidth: CGFloat = 42

    var body: some View {
        ZStack {
            // Paint the complete device canvas, including the status-bar and home-indicator areas.
            UntisPalette.timetableBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                navigationHeader

                switch selectedTab {
                case .timetable:
                    if isEditMode { editModeBanner }
                    if app.isLive, let message = app.errorMessage { errorBanner(message) }
                    dateStrip
                    timetableBody
                case .home:
                    HomeScreen(
                        entries: todayEntries,
                        isLive: app.isLive,
                        showRooms: showRooms
                    )
                case .profile:
                    ProfileScreen(
                        app: app,
                        onLogin: { fullScreenPage = .login },
                        onAbout: { activeSheet = AppSheet(kind: .info) }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(UntisPalette.timetableBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomNavigation
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .fullScreenCover(item: $fullScreenPage) { page in
            fullScreenContent(for: page)
        }
        .confirmationDialog(
            "Reset the timetable to the original sample week?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to default", role: .destructive) {
                timetable.resetToDefault()
                isEditMode = false
                selectedDate = UntisCalendar.normalized(Date())
                displayMode = .day
            }
            Button("Cancel", role: .cancel) { }
        }
        .task(id: loadKey) {
            await app.ensureLoaded(for: visibleDates)
        }
        .onAppear {
            if !onboardingDone && !app.isLive { fullScreenPage = .login }
        }
        .onChange(of: selectedTab) { newValue in
            if newValue != .timetable { isEditMode = false }
        }
        .onChange(of: app.isLive) { live in
            if live { isEditMode = false }
        }
        .statusBarHidden(false)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: Sheets and pages

    @ViewBuilder
    private func sheetContent(for sheet: AppSheet) -> some View {
        switch sheet.kind {
        case .lessonEditor(let lesson, let isNew):
            LessonEditorSheet(
                lesson: lesson,
                isNew: isNew,
                periods: timetable.periods,
                onSave: { timetable.upsert($0) },
                onDelete: { timetable.delete(id: $0) }
            )
        case .setPasscode:
            PasscodeSheet(passcodes: passcodes, mode: .set, onSuccess: {
                activeSheet = nil
            })
        case .enterPasscode:
            PasscodeSheet(passcodes: passcodes, mode: .enter, onSuccess: {
                isEditMode = true
                selectedTab = .timetable
                activeSheet = nil
            })
        case .goToDate:
            GoToDateSheet(selectedDate: Binding(
                get: { selectedDate },
                set: { selectedDate = UntisCalendar.normalized($0) }
            ))
        case .classPicker:
            ClassPickerSheet(app: app)
        case .options:
            TimetableOptionsSheet(
                showCancelledLessons: $showCancelledLessons,
                showRooms: $showRooms,
                showSubjectColours: $showSubjectColours
            )
        case .help:
            HelpSheet(isLive: app.isLive)
        case .info:
            InfoSheet(isLive: app.isLive)
        }
    }

    @ViewBuilder
    private func fullScreenContent(for page: FullScreenPage) -> some View {
        switch page {
        case .login:
            LoginView(app: app, allowsDemo: !app.isLive) {
                onboardingDone = true
                fullScreenPage = nil
            }
        case .lesson(let entry, let periodLabel):
            LessonDetailView(entry: entry, periodLabel: periodLabel, showRooms: showRooms) {
                fullScreenPage = nil
            }
        }
    }

    // MARK: Header and menus

    private var headerTitle: String {
        app.isLive ? (app.element?.name ?? "Timetable") : "Demo"
    }

    private var navigationHeader: some View {
        ZStack {
            if selectedTab == .timetable {
                Button {
                    if app.isLive {
                        activeSheet = AppSheet(kind: .classPicker)
                    } else {
                        fullScreenPage = .login
                    }
                } label: {
                    HStack(spacing: 7) {
                        Text(headerTitle)
                            .font(.system(size: 19, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(UntisPalette.title)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Text(selectedTab.rawValue)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(UntisPalette.title)
                    Spacer()
                }
                .padding(.horizontal, 5)
            }

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                HStack(spacing: 17) {
                    Button {
                        activeSheet = AppSheet(kind: .info)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(UntisPalette.navigationTint)
                            .frame(width: 34, height: 38)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Information")

                    if selectedTab == .timetable {
                        timetableMenu
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .modifier(UntisLiquidGlassCapsule())
            }
        }
        .frame(height: selectedTab == .timetable ? 57 : 64)
        .padding(.horizontal, 17)
        .padding(.top, 3)
        .padding(.bottom, 4)
        .background(UntisPalette.timetableBackground)
    }

    private var timetableMenu: some View {
        Menu {
            if app.isLive {
                Button {
                    activeSheet = AppSheet(kind: .classPicker)
                } label: {
                    Label("Choose class", systemImage: "person.3")
                }
                Button {
                    refreshToken += 1
                    Task { await app.ensureLoaded(for: visibleDates, force: true) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            } else {
                if passcodes.hasPasscode {
                    Button {
                        activeSheet = AppSheet(kind: .enterPasscode)
                    } label: {
                        Label("Enter code", systemImage: "lock.open")
                    }
                } else {
                    Button {
                        activeSheet = AppSheet(kind: .setPasscode)
                    } label: {
                        Label("Set code", systemImage: "lock")
                    }
                }
                Button {
                    fullScreenPage = .login
                } label: {
                    Label("Log in to Untis", systemImage: "person.badge.key")
                }
            }

            Divider()

            Button {
                activeSheet = AppSheet(kind: .goToDate)
            } label: {
                Label("Go to Date", systemImage: "calendar")
            }

            Section("View") {
                ForEach(TimetableViewMode.allCases) { mode in
                    Button {
                        displayMode = mode
                    } label: {
                        if displayMode == mode {
                            Label(mode.rawValue, systemImage: "checkmark")
                        } else {
                            Text(mode.rawValue)
                        }
                    }
                }
            }

            Section("Zoom") {
                Button { changeZoom(by: 0.25) } label: { Label("Zoom in", systemImage: "plus.magnifyingglass") }
                Button { changeZoom(by: -0.25) } label: { Label("Zoom out", systemImage: "minus.magnifyingglass") }
                Button { storedZoom = 1.0 } label: { Label("Reset zoom", systemImage: "1.magnifyingglass") }
            }

            Button {
                activeSheet = AppSheet(kind: .options)
            } label: {
                Label("Options", systemImage: "slider.horizontal.3")
            }

            Button {
                activeSheet = AppSheet(kind: .help)
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }

            if !app.isLive {
                Divider()
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("Reset to default", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 22, weight: .medium))
                .rotationEffect(.degrees(90))
                .foregroundStyle(UntisPalette.navigationTint)
                .frame(width: 30, height: 38)
        }
        .accessibilityLabel("More options")
    }

    private var editModeBanner: some View {
        HStack(spacing: 8) {
            UntisIcon(asset: "untis_ic_edit", symbol: "pencil")
                .foregroundStyle(UntisPalette.brand)
                .frame(width: 15, height: 15)

            Text("Edit Mode Active – Tap any lesson to edit")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(UntisPalette.title)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 4)

            Button("Done") { isEditMode = false }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(UntisPalette.brand)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(UntisPalette.brand.opacity(0.08))
        .overlay(alignment: .bottom) {
            Rectangle().fill(UntisPalette.separator).frame(height: 0.6)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(UntisPalette.cancelledBorder)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(UntisPalette.title)
                .lineLimit(2)
            Spacer(minLength: 4)
            Button("Retry") {
                refreshToken += 1
                Task { await app.ensureLoaded(for: visibleDates, force: true) }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(UntisPalette.brand)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(UntisPalette.cancelledBackground.opacity(0.9))
        .overlay(alignment: .bottom) {
            Rectangle().fill(UntisPalette.cancelledBorder.opacity(0.5)).frame(height: 0.6)
        }
    }

    // MARK: Date strip

    private var dateStrip: some View {
        GeometryReader { geometry in
            let dates = visibleDates
            let dayWidth = max(40, (geometry.size.width - timeColumnWidth) / CGFloat(max(dates.count, 1)))

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("W \(UntisCalendar.weekNumber(of: selectedDate))")
                        .font(.system(size: 13, weight: .semibold))
                    Text(UntisFormat.monthShort.string(from: selectedDate))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(UntisPalette.text)
                .frame(width: timeColumnWidth, height: 57, alignment: .leading)
                .padding(.leading, 4)

                ForEach(dates, id: \.self) { date in
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 2) {
                            Text(String(UntisFormat.weekdayShort.string(from: date).prefix(2)))
                                .font(.system(size: 13, weight: .semibold))
                            Text("\(UntisCalendar.calendar.component(.day, from: date))")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(isHighlighted(date) ? UntisPalette.brand : UntisPalette.text)
                        .frame(width: dayWidth, height: 57)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(UntisPalette.timetableBackground)
            .overlay(alignment: .bottom) {
                Rectangle().fill(UntisPalette.separator.opacity(0.65)).frame(height: 0.7)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        if value.translation.width < -40 {
                            moveSelection(by: 1)
                        } else if value.translation.width > 40 {
                            moveSelection(by: -1)
                        }
                    }
            )
        }
        .frame(height: 57)
    }

    private func isHighlighted(_ date: Date) -> Bool {
        UntisCalendar.calendar.isDate(date, inSameDayAs: selectedDate)
    }

    // MARK: Timetable

    private var timetableBody: some View {
        TimetableGridView(
            dates: visibleDates,
            periods: activePeriods,
            entriesFor: entries(for:),
            isEditMode: isEditMode,
            showRooms: showRooms,
            showSubjectColours: showSubjectColours,
            zoom: Binding(
                get: { CGFloat(storedZoom) },
                set: { storedZoom = Double($0) }
            ),
            timeColumnWidth: timeColumnWidth,
            onTap: handleEntryTap,
            onSwipe: { step in moveSelection(by: step) },
            onRefresh: { await app.ensureLoaded(for: visibleDates, force: true) }
        )
        .overlay(alignment: .top) {
            if app.isLive && app.isLoading {
                ProgressView()
                    .padding(8)
                    .background(UntisPalette.surface.opacity(0.9), in: Capsule())
                    .padding(.top, 8)
            }
        }
    }

    private var bottomNavigation: some View {
        HStack(spacing: 3) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        UntisIcon(asset: tab.iconName, symbol: tab.symbolName)
                            .frame(width: 25, height: 25)
                            .foregroundStyle(.white)
                        Text(tab.rawValue)
                            .font(.system(size: 10.5, weight: .semibold))
                            .lineLimit(1)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background {
                        if selectedTab == tab {
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.36))
                                .padding(2)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(4)
        .frame(maxWidth: 290)
        .modifier(UntisLiquidGlassCapsule())
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }

    // MARK: Data helpers

    private var activePeriods: [PeriodDefinition] {
        app.isLive ? app.livePeriods : timetable.periods
    }

    private func entries(for date: Date) -> [TimetableEntry] {
        if app.isLive {
            let all = app.entries(for: date)
            return showCancelledLessons ? all : all.filter { $0.status != .cancelled }
        }
        return EntryBuilder.demoEntries(
            for: date,
            lessons: timetable.lessons,
            periods: timetable.periods,
            isEditMode: isEditMode,
            showCancelled: showCancelledLessons
        )
    }

    private var todayEntries: [TimetableEntry] {
        entries(for: UntisCalendar.normalized(Date())).sorted { $0.startRow < $1.startRow }
    }

    /// The dates currently on screen. Day views skip weekends and may cross into the next week.
    private var visibleDates: [Date] {
        if displayMode == .week {
            let monday = UntisCalendar.monday(of: selectedDate)
            return (0..<5).map { UntisCalendar.addingDays(monday, $0) }
        }
        return (0..<displayMode.numberOfDays).map { UntisCalendar.addingWeekdays(selectedDate, $0) }
    }

    private var loadKey: String {
        let weeks = visibleDates
            .map { String(UntisCalendar.key(UntisCalendar.monday(of: $0))) }
            .joined(separator: ",")
        return "\(app.profile?.username ?? "demo")|\(app.element?.id ?? 0)|\(weeks)|\(refreshToken)"
    }

    private func moveSelection(by step: Int) {
        if displayMode == .week {
            selectedDate = UntisCalendar.addingDays(selectedDate, 7 * step)
        } else {
            selectedDate = UntisCalendar.addingWeekdays(selectedDate, step * displayMode.numberOfDays)
        }
    }

    private func changeZoom(by delta: Double) {
        let lower = Double(TimetableGridView.minZoom)
        let upper = Double(TimetableGridView.maxZoom)
        storedZoom = min(max(storedZoom + delta, lower), upper)
    }

    private func periodLabel(for entry: TimetableEntry) -> String {
        let periods = activePeriods
        guard entry.startRow < periods.count else { return "" }
        let first = periods[entry.startRow].number
        let last = periods[min(entry.endRow - 1, periods.count - 1)].number
        return first == last ? "Period \(first)" : "Periods \(first)–\(last)"
    }

    private func handleEntryTap(_ entry: TimetableEntry) {
        if isEditMode && !app.isLive {
            let periods = timetable.periods
            guard entry.startRow < periods.count else { return }

            if entry.isPlaceholder {
                let lesson = Lesson(
                    dayIndex: UntisCalendar.dayIndex(of: entry.date),
                    periodNumber: periods[entry.startRow].number,
                    subject: "",
                    teacher: "",
                    room: ""
                )
                activeSheet = AppSheet(kind: .lessonEditor(lesson, isNew: true))
            } else if let existing = timetable.lessons.first(where: { $0.id.uuidString == entry.id }) {
                activeSheet = AppSheet(kind: .lessonEditor(existing, isNew: false))
            }
            return
        }

        guard !entry.isPlaceholder, !entry.isHidden else { return }
        fullScreenPage = .lesson(entry, periodLabel: periodLabel(for: entry))
    }
}

// MARK: - Home

private struct HomeScreen: View {
    let entries: [TimetableEntry]
    let isLive: Bool
    let showRooms: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(UntisPalette.title)
                    Text(UntisFormat.fullDate.string(from: UntisCalendar.normalized(Date())))
                        .font(.system(size: 14))
                        .foregroundStyle(UntisPalette.subtitle)
                }

                if entries.isEmpty {
                    Text(isLive ? "No lessons today." : "No lessons in the demo timetable today.")
                        .font(.system(size: 14))
                        .foregroundStyle(UntisPalette.subtitle)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(UntisPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    VStack(spacing: 0) {
                        ForEach(entries) { entry in
                            lessonRow(entry)
                            if entry.id != entries.last?.id {
                                Divider().overlay(UntisPalette.separator).padding(.leading, 62)
                            }
                        }
                    }
                    .background(UntisPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    private func lessonRow(_ entry: TimetableEntry) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(entry.startTime)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(entry.endTime)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(UntisPalette.subtitle)
            }
            .foregroundStyle(UntisPalette.title)
            .frame(width: 42)

            RoundedRectangle(cornerRadius: 2)
                .fill(entry.status.accent)
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.subject.isEmpty ? "—" : entry.subject)
                    .font(.system(size: 16, weight: .semibold))
                    .strikethrough(entry.status == .cancelled)
                    .foregroundStyle(UntisPalette.title)
                Text([entry.teacher, showRooms ? entry.room : ""].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 13))
                    .foregroundStyle(UntisPalette.subtitle)
            }
            Spacer(minLength: 0)

            if entry.status != .normal {
                Text(entry.status.shortTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(entry.status.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

// MARK: - Profile

private struct ProfileScreen: View {
    @ObservedObject var app: AppModel
    let onLogin: () -> Void
    let onAbout: () -> Void

    @State private var showLogoutConfirmation = false

    private var title: String { app.profile?.username ?? "Demo profile" }
    private var subtitle: String { app.profile?.schoolName ?? "Offline demo timetable" }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(UntisPalette.title)
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(UntisPalette.subtitle)
                    }
                    Spacer()
                    if let name = app.profile?.username {
                        Menu {
                            Button {
                                UIPasteboard.general.string = name
                            } label: {
                                Label("Copy username", systemImage: "doc.on.doc")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(UntisPalette.navigationTint)
                                .frame(width: 42, height: 42)
                                .background(UntisPalette.timetableBackground.opacity(0.8), in: Circle())
                        }
                    }
                }
                .padding(22)
                .background(UntisPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))

                VStack(spacing: 0) {
                    row(icon: "info.circle", title: "About", action: onAbout)
                }
                .padding(.horizontal, 17)
                .background(UntisPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))

                VStack(spacing: 0) {
                    if app.isLive {
                        row(icon: "rectangle.portrait.and.arrow.right", title: "Log out") {
                            showLogoutConfirmation = true
                        }
                    } else {
                        row(icon: "person.badge.key", title: "Log in to Untis", action: onLogin)
                    }
                }
                .padding(.horizontal, 17)
                .background(UntisPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            }
            .padding(.horizontal, 17)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .confirmationDialog("Log out of Untis?", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
            Button("Log out", role: .destructive) { app.logout() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The saved password is removed from this device. You will see the offline demo timetable again.")
        }
    }

    private func row(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(UntisPalette.navigationTint)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(UntisPalette.title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(UntisPalette.navigationTint)
            }
            .padding(.vertical, 19)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
