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
    case lessonDetail(Lesson)
    case setPasscode
    case enterPasscode
    case goToDate
    case manageCalendars
    case options
    case help
    case info
}

private struct AppSheet: Identifiable {
    let id = UUID()
    let kind: AppSheetKind
}

// MARK: - Main screen

struct ContentView: View {
    @StateObject private var timetable = TimetableStore()
    @StateObject private var passcodes = PasscodeStore()

    @State private var selectedTab: MainTab = .timetable
    @State private var selectedDate = Calendar(identifier: .iso8601).startOfDay(for: Date())
    @State private var displayMode: TimetableViewMode = .day
    @State private var isEditMode = false
    @State private var activeSheet: AppSheet?
    @State private var showResetConfirmation = false

    @AppStorage("untis.mobile.showCancelledLessons") private var showCancelledLessons = true
    @AppStorage("untis.mobile.showRooms") private var showRooms = true
    @AppStorage("untis.mobile.showSubjectColours") private var showSubjectColours = true

    private let timeColumnWidth: CGFloat = 42
    private let periodRowHeight: CGFloat = 58

    var body: some View {
        ZStack {
            // Paint the complete device canvas, including the status-bar and home-indicator areas.
            UntisPalette.timetableBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                navigationHeader

                if selectedTab == .timetable {
                    if isEditMode {
                        editModeBanner
                    }
                    dateStrip
                    timetableBody
                } else {
                    SecondaryTabScreen(tab: selectedTab)
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
        .confirmationDialog(
            "Reset the timetable to the original sample week?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to default", role: .destructive) {
                timetable.resetToDefault()
                isEditMode = false
                selectedDate = Calendar(identifier: .iso8601).startOfDay(for: Date())
                displayMode = .day
            }
            Button("Cancel", role: .cancel) { }
        }
        .onChange(of: selectedTab) { newValue in
            if newValue != .timetable { isEditMode = false }
        }
        .statusBarHidden(false)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

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
        case .lessonDetail(let lesson):
            LessonDetailSheet(lesson: lesson, showRooms: showRooms)
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
            GoToDateSheet(selectedDate: $selectedDate)
        case .manageCalendars:
            LocalCalendarsSheet()
        case .options:
            TimetableOptionsSheet(
                showCancelledLessons: $showCancelledLessons,
                showRooms: $showRooms,
                showSubjectColours: $showSubjectColours
            )
        case .help:
            HelpSheet()
        case .info:
            InfoSheet()
        }
    }

    // MARK: Header and menus

    private var navigationHeader: some View {
        ZStack {
            if selectedTab == .timetable {
                Button { } label: {
                    HStack(spacing: 7) {
                        Text("08B")
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
                        Menu {
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

                            Button {
                                activeSheet = AppSheet(kind: .help)
                            } label: {
                                Label("Help", systemImage: "questionmark.circle")
                            }
                            Divider()
                            Button(role: .destructive) {
                                showResetConfirmation = true
                            } label: {
                                Label("Reset to default", systemImage: "arrow.counterclockwise")
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

    private var dateStrip: some View {
        GeometryReader { geometry in
            let indices = visibleDayIndices
            let dayWidth = max(50, (geometry.size.width - timeColumnWidth) / CGFloat(max(indices.count, 1)))
            let weekNumber = Calendar(identifier: .iso8601).component(.weekOfYear, from: selectedDate)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("W \(weekNumber)")
                        .font(.system(size: 13, weight: .semibold))
                    Text(monthName(for: selectedDate))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(UntisPalette.text)
                .frame(width: timeColumnWidth, height: 57, alignment: .leading)
                .padding(.leading, 4)

                ForEach(indices, id: \.self) { dayIndex in
                    let date = weekDates[dayIndex]
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 2) {
                            Text(String(dayName(for: date).prefix(2)))
                                .font(.system(size: 13, weight: .semibold))
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(isSelectedDay(date) ? UntisPalette.brand : UntisPalette.text)
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
                            moveWeek(by: 1)
                        } else if value.translation.width > 40 {
                            moveWeek(by: -1)
                        }
                    }
            )
        }
        .frame(height: 57)
    }

    private var weekNavigation: some View {
        HStack(spacing: 9) {
            Text(weekCaption)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(UntisPalette.subtitle)

            Spacer()

            Button {
                moveWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(UntisPalette.title)
                    .frame(width: 29, height: 29)
                    .background(UntisPalette.timetableBackground)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Previous week")

            Button {
                moveWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(UntisPalette.title)
                    .frame(width: 29, height: 29)
                    .background(UntisPalette.timetableBackground)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Next week")
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 7)
        .background(UntisPalette.surface)
    }

    // MARK: Timetable header and grid

    private var dayHeader: some View {
        GeometryReader { geometry in
            let indices = visibleDayIndices
            let dayWidth = max(50, (geometry.size.width - timeColumnWidth) / CGFloat(max(indices.count, 1)))

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("TIME")
                    Text("PERIOD")
                }
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(UntisPalette.subtitle)
                .frame(width: timeColumnWidth, height: 52)

                ForEach(indices, id: \.self) { dayIndex in
                    let date = weekDates[dayIndex]
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 3) {
                            Text(dayName(for: date).uppercased())
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(isSelectedDay(date) ? UntisPalette.brand : UntisPalette.subtitle)
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 16, weight: isSelectedDay(date) ? .bold : .medium))
                                .foregroundStyle(isSelectedDay(date) ? UntisPalette.brand : UntisPalette.title)
                        }
                        .frame(width: dayWidth, height: 52)
                        .background(isSelectedDay(date) ? UntisPalette.brand.opacity(0.055) : UntisPalette.surface)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(isSelectedDay(date) ? UntisPalette.brand : .clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(UntisPalette.surface)
            .overlay(alignment: .bottom) {
                Rectangle().fill(UntisPalette.separator).frame(height: 0.7)
            }
        }
        .frame(height: 52)
    }

    private var timetableBody: some View {
        GeometryReader { geometry in
            let indices = visibleDayIndices
            let dayWidth = max(50, (geometry.size.width - timeColumnWidth) / CGFloat(max(indices.count, 1)))

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(timetable.periods) { period in
                        HStack(spacing: 0) {
                            PeriodTimeCell(period: period)
                                .frame(width: timeColumnWidth, height: periodRowHeight)

                            ForEach(indices, id: \.self) { dayIndex in
                                let lesson = timetable.lesson(dayIndex: dayIndex, periodNumber: period.number)
                                LessonSlotButton(
                                    lesson: lesson,
                                    isEditMode: isEditMode,
                                    showCancelledLessons: showCancelledLessons,
                                    showRooms: showRooms,
                                    showSubjectColours: showSubjectColours
                                ) {
                                    handleSlotTap(dayIndex: dayIndex, period: period)
                                }
                                .frame(width: dayWidth, height: periodRowHeight)
                                .overlay(alignment: .trailing) {
                                    Rectangle().fill(UntisPalette.gridLine).frame(width: 0.65)
                                }
                            }
                        }
                        .frame(height: periodRowHeight)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(UntisPalette.gridLine).frame(height: 0.65)
                        }
                    }
                }
                .background(UntisPalette.timegridBackground)
            }
            .background(UntisPalette.timegridBackground)
        }
        .background(UntisPalette.timegridBackground)
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

    // MARK: Date helpers and tap behavior

    private var weekDates: [Date] {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)
        let monday = calendar.date(from: components) ?? calendar.startOfDay(for: selectedDate)
        return (0..<5).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private var visibleDayIndices: [Int] {
        switch displayMode {
        case .week: return Array(0..<5)
        case .day: return [selectedWeekdayIndex]
        case .twoDays: return (0..<2).map { (selectedWeekdayIndex + $0) % 5 }
        case .threeDays: return (0..<3).map { (selectedWeekdayIndex + $0) % 5 }
        }
    }

    private var selectedWeekdayIndex: Int {
        let weekday = Calendar(identifier: .iso8601).component(.weekday, from: selectedDate)
        if weekday == 1 { return 4 }   // Sunday belongs to the ISO week that ends on it
        return min(max(weekday - 2, 0), 4)
    }

    private var weekCaption: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d MMM"
        guard let first = weekDates.first, let last = weekDates.last else { return "This week" }
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }

    private func monthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func isSelectedDay(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    private func moveWeek(by amount: Int) {
        if let updated = Calendar(identifier: .iso8601).date(byAdding: .weekOfYear, value: amount, to: selectedDate) {
            selectedDate = updated
        }
    }

    private func handleSlotTap(dayIndex: Int, period: PeriodDefinition) {
        if isEditMode {
            if let existing = timetable.lesson(dayIndex: dayIndex, periodNumber: period.number) {
                activeSheet = AppSheet(kind: .lessonEditor(existing, isNew: false))
            } else {
                let newLesson = Lesson(
                    dayIndex: dayIndex,
                    periodNumber: period.number,
                    subject: "",
                    teacher: "",
                    room: "",
                    subjectColorHex: "#E5F0F7"
                )
                activeSheet = AppSheet(kind: .lessonEditor(newLesson, isNew: true))
            }
        } else if let lesson = timetable.lesson(dayIndex: dayIndex, periodNumber: period.number),
                  !(lesson.isHiddenFromTimetable || (lesson.status == .cancelled && !showCancelledLessons)) {
            activeSheet = AppSheet(kind: .lessonDetail(lesson))
        }
    }
}

// MARK: - Period labels and timetable cards

private struct PeriodTimeCell: View {
    let period: PeriodDefinition

    var body: some View {
        VStack(spacing: 3) {
            Text("\(period.number).")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(UntisPalette.title)
            Text(period.startTime)
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundStyle(UntisPalette.subtitle)
            Rectangle().fill(UntisPalette.separator).frame(width: 25, height: 0.6)
            Text(period.endTime)
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundStyle(UntisPalette.subtitle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UntisPalette.timegridBackground)
    }
}

private struct LessonSlotButton: View {
    let lesson: Lesson?
    let isEditMode: Bool
    let showCancelledLessons: Bool
    let showRooms: Bool
    let showSubjectColours: Bool
    let action: () -> Void

    private var isHidden: Bool {
        guard let lesson else { return false }
        return lesson.isHiddenFromTimetable || (lesson.status == .cancelled && !showCancelledLessons)
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let lesson {
                    if isHidden {
                        if isEditMode {
                            HiddenLessonCard()
                        } else {
                            Color.clear
                        }
                    } else {
                        LessonCardView(lesson: lesson, showRooms: showRooms, showSubjectColours: showSubjectColours)
                    }
                } else if isEditMode {
                    EmptyLessonCard()
                } else {
                    Color.clear
                }
            }
            .padding(3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(lesson == nil && !isEditMode || isHidden && !isEditMode)
        .background(UntisPalette.timegridBackground)
    }
}

private struct EmptyLessonCard: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "plus.circle")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(UntisPalette.brand.opacity(0.7))
            Text("Add")
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(UntisPalette.subtitle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UntisPalette.surface.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(UntisPalette.brand.opacity(0.22), style: StrokeStyle(lineWidth: 0.8, dash: [3, 2]))
        }
    }
}

private struct HiddenLessonCard: View {
    var body: some View {
        VStack(spacing: 4) {
            UntisIcon(asset: "untis_ic_eye_off", symbol: "eye.slash")
                .frame(width: 14, height: 14)
                .foregroundStyle(UntisPalette.subtitle)
            Text("Hidden")
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(UntisPalette.subtitle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UntisPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(UntisPalette.separator, style: StrokeStyle(lineWidth: 0.8, dash: [2, 2]))
        }
    }
}

private struct LessonCardView: View {
    let lesson: Lesson
    let showRooms: Bool
    let showSubjectColours: Bool

    private var isCancelled: Bool { lesson.status == .cancelled }

    private var cardBackground: Color {
        switch lesson.status {
        case .normal, .cancelled, .roomChange, .substitution, .exam:
            return UntisPalette.lessonBackground
        }
    }

    private var statusAccent: Color {
        switch lesson.status {
        case .normal: return showSubjectColours ? Color(hex: lesson.subjectColorHex).darker(by: 0.24) : UntisPalette.lessonBorder
        case .cancelled: return UntisPalette.cancelledBorder
        case .roomChange, .substitution: return UntisPalette.changeBorder
        case .exam: return UntisPalette.examBorder
        }
    }

    private var cardBorder: Color {
        switch lesson.status {
        case .normal: return UntisPalette.lessonBorder
        case .cancelled: return UntisPalette.cancelledBorder.opacity(0.75)
        case .roomChange, .substitution: return UntisPalette.changeBorder.opacity(0.65)
        case .exam: return UntisPalette.examBorder.opacity(0.65)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if lesson.status == .exam {
                HStack(spacing: 3) {
                    UntisIcon(asset: "untis_ic_exam", symbol: "doc.text")
                        .frame(width: 8, height: 8)
                    Text("EXAM / INFO")
                        .font(.system(size: 6.5, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(UntisPalette.examBorder)
            } else if lesson.status == .cancelled {
                HStack(spacing: 3) {
                    UntisIcon(asset: "untis_ic_cancel_lesson", symbol: "xmark.circle")
                        .frame(width: 8, height: 8)
                    Text("ENTFALL")
                        .font(.system(size: 6.5, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(UntisPalette.cancelledBorder)
            } else if lesson.status == .roomChange || lesson.status == .substitution {
                HStack(spacing: 3) {
                    Circle().fill(UntisPalette.changeBorder).frame(width: 5, height: 5)
                    Text(lesson.status == .roomChange ? "RAUMÄNDERUNG" : "VERTRETUNG")
                        .font(.system(size: 6.2, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
                .foregroundStyle(UntisPalette.changeBorder)
            }

            HStack(spacing: 2) {
                Text(lesson.subject.isEmpty ? "—" : lesson.subject)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .strikethrough(isCancelled)
                if lesson.status == .substitution && !lesson.originalSubject.isEmpty {
                    Text(lesson.originalSubject)
                        .font(.system(size: 7, weight: .medium))
                        .lineLimit(1)
                        .strikethrough()
                        .opacity(0.65)
                }
            }
            .foregroundStyle(isCancelled ? UntisPalette.cancelledText : UntisPalette.lessonTitle)

            HStack(spacing: 2) {
                Text(lesson.teacher.isEmpty ? "—" : lesson.teacher)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .strikethrough(isCancelled)
                if lesson.status == .substitution && !lesson.originalTeacher.isEmpty {
                    Text(lesson.originalTeacher)
                        .font(.system(size: 7, weight: .regular))
                        .lineLimit(1)
                        .strikethrough()
                        .opacity(0.65)
                }
            }
            .foregroundStyle(isCancelled ? UntisPalette.cancelledText.opacity(0.82) : UntisPalette.lessonSubtitle)

            if showRooms {
                roomRow
            }

            if lesson.status == .exam && !lesson.infoText.isEmpty {
                Text(lesson.infoText)
                    .font(.system(size: 6.5, weight: .medium))
                    .foregroundStyle(UntisPalette.title.opacity(0.85))
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, 3)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(statusAccent)
                .frame(width: 3)
                .padding(.vertical, 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(cardBorder, lineWidth: 0.65)
        }
        .opacity(isCancelled ? 0.88 : 1)
    }

    @ViewBuilder
    private var roomRow: some View {
        if lesson.status == .roomChange {
            HStack(spacing: 3) {
                Text(lesson.room.isEmpty ? "—" : lesson.room)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(UntisPalette.changeBorder)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                if !lesson.originalRoom.isEmpty {
                    Text(lesson.originalRoom)
                        .font(.system(size: 6.5, weight: .medium))
                        .lineLimit(1)
                        .strikethrough()
                        .foregroundStyle(UntisPalette.subtitle)
                }
            }
            .foregroundStyle(Color.black.opacity(0.88))
        } else {
            Text(lesson.room.isEmpty ? "—" : lesson.room)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .strikethrough(isCancelled)
                .foregroundStyle(isCancelled ? UntisPalette.cancelledText.opacity(0.8) : UntisPalette.lessonSubtitle)
        }
    }
}

// MARK: - Secondary tabs (local frontend-only states)

private struct SecondaryTabScreen: View {
    let tab: MainTab

    var body: some View {
        Group {
            switch tab {
            case .home:
                HomeScreen()
            case .timetable:
                EmptyView()
            case .profile:
                ProfileScreen()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UntisPalette.timetableBackground)
    }
}

private struct HomeScreen: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Home")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(UntisPalette.title)
            VStack(alignment: .leading, spacing: 7) {
                Text("Today")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(UntisPalette.title)
                Text("Your school day at a glance.")
                    .font(.system(size: 14))
                    .foregroundStyle(UntisPalette.subtitle)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(UntisPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 25)
    }
}

private struct ProfileScreen: View {
    @State private var showDeleteConfirmation = false
    @State private var showAddProfile = false
    @State private var showAbout = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("local.student")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(UntisPalette.title)
                            Text("Profile")
                                .font(.system(size: 13))
                                .foregroundStyle(UntisPalette.subtitle)
                        }
                        Spacer()
                        Menu {
                            Button {
                                UIPasteboard.general.string = "local.student"
                            } label: {
                                Label("Copy username", systemImage: "doc.on.doc")
                            }
                            Divider()
                            Section("Profile options") {
                                Button {
                                    showAddProfile = true
                                } label: {
                                    Label("Add profile", systemImage: "plus")
                                }
                                Button(role: .destructive) {
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete profile", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(UntisPalette.navigationTint)
                                .frame(width: 42, height: 42)
                                .background(UntisPalette.timetableBackground.opacity(0.8), in: Circle())
                        }
                    }
                    .padding(22)
                }
                .background(UntisPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))

                VStack(spacing: 0) {
                    profileRow(icon: "megaphone", title: "Announcements") { }
                    Divider().overlay(UntisPalette.separator).padding(.leading, 60)
                    profileRow(icon: "star.square", title: "Rate Untis Mobile") { }
                    Divider().overlay(UntisPalette.separator).padding(.leading, 60)
                    profileRow(icon: "info.circle", title: "About") { showAbout = true }
                }
                .padding(.horizontal, 17)
                .background(UntisPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))

                Button { } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(UntisPalette.navigationTint)
                        Text("Log out")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(UntisPalette.title)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(UntisPalette.navigationTint)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 22)
                    .background(UntisPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 17)
            .padding(.top, 22)
            .padding(.bottom, 18)
        }
        .alert("Add profile", isPresented: $showAddProfile) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Profile management is shown locally in this frontend-only build.")
        }
        .alert("Delete profile?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { }
        } message: {
            Text("This demo profile is stored locally.")
        }
        .sheet(isPresented: $showAbout) {
            InfoSheet()
        }
    }

    private func profileRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
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

// MARK: - Lesson editor

private struct LessonEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Lesson
    @State private var showDeleteConfirmation = false

    let isNew: Bool
    let periods: [PeriodDefinition]
    let onSave: (Lesson) -> Void
    let onDelete: (UUID) -> Void

    init(
        lesson: Lesson,
        isNew: Bool,
        periods: [PeriodDefinition],
        onSave: @escaping (Lesson) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) {
        self.isNew = isNew
        self.periods = periods
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: lesson)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lesson") {
                    TextField("Subject", text: $draft.subject)
                        .textInputAutocapitalization(.characters)
                    TextField("Teacher", text: $draft.teacher)
                        .textInputAutocapitalization(.characters)
                    TextField("Room", text: $draft.room)
                        .textInputAutocapitalization(.characters)
                }

                Section("Time") {
                    Picker("Day", selection: $draft.dayIndex) {
                        ForEach(0..<5, id: \.self) { index in
                            Text(dayTitle(index)).tag(index)
                        }
                    }
                    Picker("Period", selection: $draft.periodNumber) {
                        ForEach(periods) { period in
                            Text("\(period.number)  ·  \(period.startTime)–\(period.endTime)").tag(period.number)
                        }
                    }
                    .onChange(of: draft.periodNumber) { number in
                        if let period = periods.first(where: { $0.number == number }) {
                            // Start and end are represented by the period definition in the timetable grid.
                            _ = period
                        }
                    }
                }

                Section("Status") {
                    Picker("Status", selection: $draft.status) {
                        ForEach(LessonStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    if draft.status == .cancelled {
                        Picker("Cancelled lesson display", selection: $draft.cancelledDisplayMode) {
                            ForEach(CancelledDisplayMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        Text("A hidden cancelled lesson remains saved. In Edit Mode its slot is shown as Hidden, so you can restore or change it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Original values for comparison") {
                    TextField("Original subject", text: $draft.originalSubject)
                        .textInputAutocapitalization(.characters)
                    TextField("Original teacher", text: $draft.originalTeacher)
                        .textInputAutocapitalization(.characters)
                    TextField("Original room", text: $draft.originalRoom)
                        .textInputAutocapitalization(.characters)
                }

                Section("Information") {
                    TextField("Info text", text: $draft.infoText, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Subject colour") {
                    TextField("Hex colour", text: $draft.subjectColorHex)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    HStack(spacing: 8) {
                        ForEach(["#E5F0F7", "#FCE8E3", "#E3F5EC", "#FFF2D7", "#F0E9FA", "#E9EDF1"], id: \.self) { hex in
                            Button {
                                draft.subjectColorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 25, height: 25)
                                    .overlay(Circle().stroke(UntisPalette.title.opacity(0.2), lineWidth: 0.7))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Set subject colour \(hex)")
                        }
                    }
                }

                if !isNew {
                    Section {
                        Button("Delete Lesson", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Add lesson" : "Edit lesson")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Delete this lesson?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Lesson", role: .destructive) {
                    onDelete(draft.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
        .presentationDetents([.large])
    }

    private func dayTitle(_ index: Int) -> String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"][index]
    }
}

// MARK: - Normal lesson detail sheet

private struct LessonDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let lesson: Lesson
    let showRooms: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(statusColor)
                            .frame(width: 4, height: 54)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.subject)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(UntisPalette.title)
                            Text(lesson.status.shortTitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(statusColor)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 5)
                }

                Section("Lesson details") {
                    DetailRow(icon: "person", title: "Teacher", value: lesson.teacher)
                    if showRooms {
                        DetailRow(icon: "door.left.hand.open", title: "Room", value: lesson.room)
                    }
                    if !lesson.originalSubject.isEmpty {
                        DetailRow(icon: "arrow.left.arrow.right", title: "Original subject", value: lesson.originalSubject)
                    }
                    if !lesson.originalTeacher.isEmpty {
                        DetailRow(icon: "person.crop.circle", title: "Original teacher", value: lesson.originalTeacher)
                    }
                    if !lesson.originalRoom.isEmpty {
                        DetailRow(icon: "door.left.hand.open", title: "Original room", value: lesson.originalRoom)
                    }
                }

                if !lesson.infoText.isEmpty {
                    Section("Information") {
                        Text(lesson.infoText)
                            .font(.body)
                            .foregroundStyle(UntisPalette.title)
                    }
                }
            }
            .navigationTitle("Lesson details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var statusColor: Color {
        switch lesson.status {
        case .normal: return UntisPalette.brand
        case .cancelled: return UntisPalette.cancelledBorder
        case .roomChange, .substitution: return UntisPalette.changeBorder
        case .exam: return UntisPalette.examBorder
        }
    }
}

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(UntisPalette.navigationTint)
                .frame(width: 20)
            Text(title)
                .foregroundStyle(UntisPalette.subtitle)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .foregroundStyle(UntisPalette.title)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Passcode sheets

private enum PasscodeSheetMode {
    case set
    case enter
}

private struct PasscodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var passcodes: PasscodeStore
    let mode: PasscodeSheetMode
    let onSuccess: () -> Void

    @State private var code = ""
    @State private var confirmation = ""
    @State private var feedback = ""
    @State private var isError = false
    @FocusState private var codeFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 17) {
                Image(systemName: mode == .set ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 27, weight: .regular))
                    .foregroundStyle(UntisPalette.brand)
                    .padding(.top, 20)

                Text(mode == .set ? "Set your editing code" : "Enter code")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(UntisPalette.title)

                Text(mode == .set
                     ? "Choose a four-digit code. You will need it to edit your timetable."
                     : "Enter the four-digit code to unlock timetable editing.")
                    .font(.system(size: 13))
                    .foregroundStyle(UntisPalette.subtitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)

                SecureField("4-digit code", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                    .frame(maxWidth: 220)
                    .padding(.vertical, 12)
                    .background(UntisPalette.timetableBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .focused($codeFocused)
                    .onChange(of: code) { newValue in
                        code = String(newValue.filter(\.isNumber).prefix(4))
                    }

                if mode == .set {
                    SecureField("Confirm code", text: $confirmation)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                        .frame(maxWidth: 220)
                        .padding(.vertical, 12)
                        .background(UntisPalette.timetableBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .onChange(of: confirmation) { newValue in
                            confirmation = String(newValue.filter(\.isNumber).prefix(4))
                        }
                }

                if isLockedOut {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let seconds = max(0, Int(ceil((passcodes.lockedUntil ?? context.date).timeIntervalSince(context.date))))
                        VStack(spacing: 4) {
                            Text("Too many incorrect attempts")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(UntisPalette.cancelledBorder)
                            Text(seconds > 0 ? "Try again in \(seconds / 60):\(String(format: "%02d", seconds % 60))" : "You can try again now.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(UntisPalette.subtitle)
                        }
                    }
                } else if !feedback.isEmpty {
                    Text(feedback)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isError ? UntisPalette.cancelledBorder : UntisPalette.changeBorder)
                        .multilineTextAlignment(.center)
                }

                Button(action: submit) {
                    Text(mode == .set ? "Set code" : "Unlock editing")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(canSubmit ? UntisPalette.brand : UntisPalette.brand.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(!canSubmit)
                .padding(.horizontal, 23)

                if mode == .enter {
                    Text("3 attempts allowed · 5-minute lockout")
                        .font(.system(size: 10))
                        .foregroundStyle(UntisPalette.navigationSubtitle)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(UntisPalette.surface)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { codeFocused = true }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var isLockedOut: Bool {
        guard mode == .enter, let until = passcodes.lockedUntil else { return false }
        return until > Date()
    }

    private var canSubmit: Bool {
        guard code.count == 4 else { return false }
        if mode == .set { return confirmation.count == 4 }
        return true
    }

    private func submit() {
        isError = false
        feedback = ""
        switch mode {
        case .set:
            guard code == confirmation else {
                isError = true
                feedback = "The codes do not match."
                return
            }
            guard passcodes.setPasscode(code) else {
                isError = true
                feedback = "A code is already set."
                return
            }
            onSuccess()
            dismiss()
        case .enter:
            switch passcodes.verify(code) {
            case .success:
                onSuccess()
                dismiss()
            case .incorrect(let remaining):
                isError = true
                feedback = "Incorrect code. \(remaining) attempt\(remaining == 1 ? "" : "s") remaining."
                code = ""
            case .locked:
                isError = true
                feedback = "Too many incorrect attempts. Editing is locked for five minutes."
                code = ""
            }
        }
    }
}

// MARK: - Existing Untis menu destinations (local-only)

private struct GoToDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            .navigationTitle("Go to Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct LocalCalendarsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Calendars") {
                    Label("My timetable", systemImage: "calendar")
                    Text("External and private calendar connections are not available in this frontend-only build.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Manage calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct TimetableOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showCancelledLessons: Bool
    @Binding var showRooms: Bool
    @Binding var showSubjectColours: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Timetable") {
                    Toggle("Show cancelled periods", isOn: $showCancelledLessons)
                    Toggle("Show rooms", isOn: $showRooms)
                    Toggle("Show subject colours", isOn: $showSubjectColours)
                }
                Section {
                    Text("These preferences are saved locally on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Timetable colours") {
                    Label("Cancellation", systemImage: "xmark.circle.fill").foregroundStyle(UntisPalette.cancelledBorder)
                    Label("Change / substitution", systemImage: "arrow.left.arrow.right.circle.fill").foregroundStyle(UntisPalette.changeBorder)
                    Label("Exam", systemImage: "doc.text.fill").foregroundStyle(UntisPalette.examBorder)
                }
                Section("Editing") {
                    Text("Set a four-digit code from the three-dot menu. Enter that code to unlock timetable editing. After three incorrect attempts, editing is locked for five minutes.")
                }
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct InfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        UntisIcon(asset: "untis_logo_round", symbol: "graduationcap.circle.fill", template: false)
                            .foregroundStyle(UntisPalette.brand)
                            .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Untis Mobile")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Local iOS frontend · visual reference 6.8.3")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Data") {
                    Text("Timetable data is stored locally as JSON in UserDefaults. This build has no Untis server connection or account synchronization.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Icons (bundled Untis artwork, with an SF Symbol fallback if an image is missing)

private struct UntisIcon: View {
    let asset: String
    let symbol: String
    var template: Bool = true

    var body: some View {
        if UIImage(named: asset) != nil {
            Image(asset)
                .resizable()
                .renderingMode(template ? Image.TemplateRenderingMode.template : Image.TemplateRenderingMode.original)
                .scaledToFit()
        } else {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
        }
    }
}

// MARK: - Liquid Glass with a material fallback for iOS 16–25

private struct UntisLiquidGlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().stroke(Color.white.opacity(0.16), lineWidth: 0.8)
                }
                .shadow(color: Color.black.opacity(0.22), radius: 13, x: 0, y: 5)
        }
    }
}

// MARK: - Resource-backed palette

private enum UntisPalette {
    static let brand = Color(hex: "#FF6033")
    static let navy = Color(hex: "#26396A")

    static let surface = adaptive(light: "#FFFFFF", dark: "#1C1C1E")
    static let timetableBackground = adaptive(light: "#F5F5F5", dark: "#000000")
    static let timegridBackground = adaptive(light: "#FFFFFF", dark: "#161616")
    static let title = adaptive(light: "#414D55", dark: "#F3F5F7")
    static let subtitle = adaptive(light: "#67747E", dark: "#8A96A1")
    static let text = adaptive(light: "#8A96A1", dark: "#BFC8CF")
    static let navigationTint = adaptive(light: "#8A96A1", dark: "#67747E")
    static let navigationSubtitle = adaptive(light: "#919DA6", dark: "#67747E")
    static let separator = adaptive(light: "#DCDFE5", dark: "#414D55")
    static let gridLine = adaptive(light: "#E7E9EC", dark: "#303438")

    // Untis dark-mode lesson cards are slate, not pastel subject-colour fills.
    // Subject colours remain as the narrow leading accent, matching the reference UI.
    static let lessonBackground = adaptive(light: "#EEF1F3", dark: "#333E47")
    static let lessonBorder = adaptive(light: "#D3D9DE", dark: "#414D55")
    static let lessonTitle = adaptive(light: "#414D55", dark: "#D5DADF")
    static let lessonSubtitle = adaptive(light: "#687680", dark: "#C2CAD0")

    static let cancelledBackground = adaptive(light: "#FFF3F3", dark: "#81002E")
    static let cancelledBorder = adaptive(light: "#DF0047", dark: "#F03164")
    static let cancelledText = adaptive(light: "#7A1831", dark: "#FFE5EC")

    static let changeBackground = adaptive(light: "#E4FFF3", dark: "#005741")
    static let changeBorder = adaptive(light: "#00926D", dark: "#21C0A0")

    static let examBackground = adaptive(light: "#FFF7D9", dark: "#6C2B0B")
    static let examBorder = adaptive(light: "#9F532D", dark: "#FFB728")

    private static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hexString: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hexString: hex))
    }

    func darker(by amount: CGFloat) -> Color {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return Color(red: max(0, red - amount), green: max(0, green - amount), blue: max(0, blue - amount), opacity: alpha)
    }
}

private extension UIColor {
    convenience init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
        if cleaned.count == 8 {
            alpha = CGFloat((value >> 24) & 0xFF) / 255
            red = CGFloat((value >> 16) & 0xFF) / 255
            green = CGFloat((value >> 8) & 0xFF) / 255
            blue = CGFloat(value & 0xFF) / 255
        } else {
            alpha = 1
            red = CGFloat((value >> 16) & 0xFF) / 255
            green = CGFloat((value >> 8) & 0xFF) / 255
            blue = CGFloat(value & 0xFF) / 255
        }
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
