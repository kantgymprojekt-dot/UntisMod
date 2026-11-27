import SwiftUI

// MARK: - Grid with pinch-to-zoom and horizontal swiping

struct TimetableGridView: View {
    let dates: [Date]
    let periods: [PeriodDefinition]
    let entriesFor: (Date) -> [TimetableEntry]
    let isEditMode: Bool
    let showRooms: Bool
    let showSubjectColours: Bool
    @Binding var zoom: CGFloat
    let timeColumnWidth: CGFloat
    let onTap: (TimetableEntry) -> Void
    /// +1 = forward in time, -1 = backward.
    let onSwipe: (Int) -> Void
    let onRefresh: () async -> Void

    @State private var pinchBase: CGFloat = 1
    @State private var isPinching = false

    static let minZoom: CGFloat = 0.7
    static let maxZoom: CGFloat = 3.0
    private let baseRowHeight: CGFloat = 58

    private var rowHeight: CGFloat { baseRowHeight * zoom }
    private var totalHeight: CGFloat { rowHeight * CGFloat(periods.count) }

    var body: some View {
        GeometryReader { geometry in
            let dayWidth = max(40, (geometry.size.width - timeColumnWidth) / CGFloat(max(dates.count, 1)))

            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    timeRail

                    ForEach(dates, id: \.self) { date in
                        DayColumnView(
                            entries: entriesFor(date),
                            rowCount: periods.count,
                            rowHeight: rowHeight,
                            width: dayWidth,
                            zoom: zoom,
                            showRooms: showRooms,
                            showSubjectColours: showSubjectColours,
                            onTap: onTap
                        )
                        .frame(width: dayWidth, height: totalHeight, alignment: .topLeading)
                    }
                }
                .frame(height: totalHeight, alignment: .top)
                .background(UntisPalette.timegridBackground)
            }
            .refreshable { await onRefresh() }
            .simultaneousGesture(pinchGesture)
            .simultaneousGesture(swipeGesture)
        }
        .background(UntisPalette.timegridBackground)
    }

    private var timeRail: some View {
        VStack(spacing: 0) {
            ForEach(periods) { period in
                PeriodTimeCell(period: period, zoom: zoom)
                    .frame(width: timeColumnWidth, height: rowHeight)
            }
        }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if !isPinching {
                    isPinching = true
                    pinchBase = zoom
                }
                zoom = min(max(pinchBase * value, Self.minZoom), Self.maxZoom)
            }
            .onEnded { _ in
                isPinching = false
            }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 70, abs(horizontal) > abs(vertical) * 1.6 else { return }
                onSwipe(horizontal < 0 ? 1 : -1)
            }
    }
}

// MARK: - One day column

private struct DayColumnView: View {
    let entries: [TimetableEntry]
    let rowCount: Int
    let rowHeight: CGFloat
    let width: CGFloat
    let zoom: CGFloat
    let showRooms: Bool
    let showSubjectColours: Bool
    let onTap: (TimetableEntry) -> Void

    var body: some View {
        let positioned = EntryLayout.position(entries)

        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(0..<rowCount, id: \.self) { _ in
                    Color.clear
                        .frame(height: rowHeight)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(UntisPalette.gridLine).frame(height: 0.65)
                        }
                }
            }

            ForEach(positioned) { item in
                let columnWidth = width / CGFloat(max(item.columns, 1))
                let blockHeight = rowHeight * CGFloat(item.entry.span)

                LessonBlockView(
                    entry: item.entry,
                    zoom: zoom,
                    showRooms: showRooms,
                    showSubjectColours: showSubjectColours
                )
                .frame(width: columnWidth, height: blockHeight)
                .contentShape(Rectangle())
                .onTapGesture { onTap(item.entry) }
                .offset(x: columnWidth * CGFloat(item.column), y: rowHeight * CGFloat(item.entry.startRow))
            }
        }
        .frame(width: width, alignment: .topLeading)
        .overlay(alignment: .trailing) {
            Rectangle().fill(UntisPalette.gridLine).frame(width: 0.65)
        }
    }
}

// MARK: - Period label on the left

struct PeriodTimeCell: View {
    let period: PeriodDefinition
    let zoom: CGFloat

    private var scale: CGFloat { min(max(zoom, 0.85), 1.4) }

    var body: some View {
        VStack(spacing: 3 * scale) {
            Text("\(period.number).")
                .font(.system(size: 10 * scale, weight: .semibold))
                .foregroundStyle(UntisPalette.title)
            Text(period.startTime)
                .font(.system(size: 9 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(UntisPalette.subtitle)
            Rectangle()
                .fill(UntisPalette.separator)
                .frame(width: 25, height: 0.6)
            Text(period.endTime)
                .font(.system(size: 9 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(UntisPalette.subtitle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UntisPalette.timegridBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(UntisPalette.gridLine).frame(height: 0.65)
        }
    }
}

// MARK: - Lesson badge

/// Badge layout, top to bottom: teacher, subject, room.
/// - A single period shows the room only once the grid is zoomed in far enough for the text to fit.
/// - A double (or longer) period always shows the room, at any zoom level.
struct LessonBlockView: View {
    let entry: TimetableEntry
    let zoom: CGFloat
    let showRooms: Bool
    let showSubjectColours: Bool

    /// Single periods reveal the room from this zoom level on.
    static let roomZoomThreshold: CGFloat = 1.3

    private var scale: CGFloat { min(max(zoom, 0.85), 1.6) }
    private var isCancelled: Bool { entry.status == .cancelled }

    private var showsRoom: Bool {
        guard showRooms, !entry.room.isEmpty else { return false }
        return entry.span >= 2 || zoom >= Self.roomZoomThreshold
    }

    private var primaryText: Color {
        switch entry.status {
        case .normal: return UntisPalette.lessonTitle
        case .cancelled: return UntisPalette.cancelledText
        default: return UntisPalette.title
        }
    }

    private var secondaryText: Color {
        switch entry.status {
        case .normal: return UntisPalette.lessonSubtitle
        case .cancelled: return UntisPalette.cancelledText.opacity(0.85)
        default: return UntisPalette.title.opacity(0.8)
        }
    }

    var body: some View {
        if entry.isPlaceholder {
            EmptySlotView()
        } else if entry.isHidden {
            HiddenSlotView()
        } else {
            card
        }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        let accent = entry.status.accent
        let isNormal = entry.status == .normal

        return VStack(alignment: .leading, spacing: 1 * scale) {
            teacherLine
            subjectLine
            if showsRoom { roomLine }
            Spacer(minLength: 0)
        }
        .padding(.leading, isNormal ? 8 : 5)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(entry.status.fill)
        .overlay {
            if isCancelled {
                DiagonalHatch(spacing: 7)
                    .stroke(UntisPalette.cancelledBorder.opacity(0.22), lineWidth: 0.8)
                    .clipShape(shape)
            }
        }
        .overlay(alignment: .leading) {
            if isNormal {
                Rectangle()
                    .fill(showSubjectColours ? Color(hex: entry.colorHex).darker(by: 0.24) : UntisPalette.lessonBorder)
                    .frame(width: 3)
            }
        }
        .overlay(alignment: .topTrailing) {
            statusIcon
        }
        .clipShape(shape)
        .overlay {
            // Exams, cancellations and changes get a clear outline; regular lessons a hairline.
            shape.strokeBorder(isNormal ? UntisPalette.lessonBorder : accent, lineWidth: isNormal ? 0.65 : 1.6)
        }
        .padding(1.5)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch entry.status {
        case .exam:
            UntisIcon(asset: "untis_ic_exam", symbol: "doc.text")
                .frame(width: 9 * scale, height: 9 * scale)
                .foregroundStyle(entry.status.accent)
                .padding(3)
        case .cancelled:
            UntisIcon(asset: "untis_ic_cancel_lesson", symbol: "xmark.circle")
                .frame(width: 9 * scale, height: 9 * scale)
                .foregroundStyle(entry.status.accent)
                .padding(3)
        default:
            EmptyView()
        }
    }

    // MARK: Lines

    private var teacherLine: some View {
        HStack(spacing: 3) {
            Text(entry.teacher.isEmpty ? "—" : entry.teacher)
                .font(.system(size: 10 * scale, weight: .semibold))
                .strikethrough(isCancelled)
                .foregroundStyle(secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if entry.status == .substitution, !entry.originalTeacher.isEmpty, entry.originalTeacher != entry.teacher {
                Text(entry.originalTeacher)
                    .font(.system(size: 7.5 * scale, weight: .regular))
                    .strikethrough()
                    .foregroundStyle(secondaryText.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }

    private var subjectLine: some View {
        HStack(spacing: 3) {
            Text(entry.subject.isEmpty ? "—" : entry.subject)
                .font(.system(size: 13 * scale, weight: .bold))
                .strikethrough(isCancelled)
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            if entry.status == .substitution, !entry.originalSubject.isEmpty, entry.originalSubject != entry.subject {
                Text(entry.originalSubject)
                    .font(.system(size: 7.5 * scale, weight: .regular))
                    .strikethrough()
                    .foregroundStyle(secondaryText.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var roomLine: some View {
        if entry.status == .roomChange {
            HStack(spacing: 3) {
                Text(entry.room)
                    .font(.system(size: 10 * scale, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .lineLimit(1)
                    .padding(.horizontal, 3)
                    .background(UntisPalette.changeBorder, in: RoundedRectangle(cornerRadius: 2))
                if !entry.originalRoom.isEmpty, entry.originalRoom != entry.room {
                    Text(entry.originalRoom)
                        .font(.system(size: 7.5 * scale, weight: .regular))
                        .strikethrough()
                        .foregroundStyle(secondaryText.opacity(0.7))
                        .lineLimit(1)
                }
            }
        } else {
            Text(entry.room)
                .font(.system(size: 10 * scale, weight: .medium))
                .strikethrough(isCancelled)
                .foregroundStyle(secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

// MARK: - Hatch pattern for cancelled lessons

struct DiagonalHatch: Shape {
    var spacing: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = -rect.height
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: rect.height))
            path.addLine(to: CGPoint(x: x + rect.height, y: 0))
            x += spacing
        }
        return path
    }
}

// MARK: - Edit-mode placeholders (offline demo only)

struct EmptySlotView: View {
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
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(UntisPalette.brand.opacity(0.22), style: StrokeStyle(lineWidth: 0.8, dash: [3, 2]))
        }
        .padding(1.5)
    }
}

struct HiddenSlotView: View {
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
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(UntisPalette.separator, style: StrokeStyle(lineWidth: 0.8, dash: [2, 2]))
        }
        .padding(1.5)
    }
}
