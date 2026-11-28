import SwiftUI

// MARK: - Lesson detail in the Untis style (opaque page, no system glass sheet)

struct LessonDetailView: View {
    let entry: TimetableEntry
    let periodLabel: String
    let showRooms: Bool
    let onClose: () -> Void

    private var statusTitle: String? {
        switch entry.status {
        case .normal: return nil
        case .cancelled: return "Cancelled"
        case .roomChange: return "Change"
        case .substitution: return "Change"
        case .exam: return "Exam"
        }
    }

    private var statusIcon: String {
        switch entry.status {
        case .cancelled: return "untis_ic_cancel_lesson"
        case .roomChange, .substitution: return "untis_ic_my_timetable"
        case .exam: return "untis_ic_exam"
        case .normal: return "untis_ic_info"
        }
    }

    private var title: String {
        if !entry.subjectLong.isEmpty { return entry.subjectLong }
        return entry.subject.isEmpty ? "Lesson" : entry.subject
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let statusTitle {
                        statusBanner(statusTitle)
                    }

                    VStack(spacing: 0) {
                        row(icon: "untis_ic_timetable_clock", symbol: "clock",
                            caption: UntisFormat.fullDate.string(from: entry.date),
                            value: timeText)

                        if !entry.teacher.isEmpty || !entry.teacherLong.isEmpty {
                            divider
                            row(icon: "untis_ic_teacher", symbol: "person",
                                caption: "Teacher",
                                value: entry.teacherLong.isEmpty ? entry.teacher : "\(entry.teacherLong) (\(entry.teacher))",
                                original: entry.status == .substitution ? entry.originalTeacher : "")
                        }

                        if showRooms, !entry.room.isEmpty {
                            divider
                            row(icon: "untis_ic_room", symbol: "door.left.hand.open",
                                caption: "Room",
                                value: entry.roomLong.isEmpty || entry.roomLong == entry.room ? entry.room : "\(entry.room) – \(entry.roomLong)",
                                original: entry.originalRoom)
                        }

                        if !entry.classNames.isEmpty {
                            divider
                            row(icon: "untis_ic_class", symbol: "person.3",
                                caption: "Class", value: entry.classNames)
                        }

                        if entry.status == .substitution, !entry.originalSubject.isEmpty, entry.originalSubject != entry.subject {
                            divider
                            row(icon: "untis_ic_my_timetable", symbol: "circle",
                                caption: "Subject", value: entry.originalSubject)
                        }
                    }
                    .background(UntisPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if !entry.infoText.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Period info")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(UntisPalette.subtitle)
                            Text(entry.infoText)
                                .font(.system(size: 16))
                                .foregroundStyle(UntisPalette.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(UntisPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UntisPalette.timetableBackground.ignoresSafeArea())
    }

    // MARK: Pieces

    private var topBar: some View {
        ZStack {
            Text("Period")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(UntisPalette.title)

            HStack {
                Button(action: onClose) {
                    HStack(spacing: 4) {
                        UntisIcon(asset: "untis_ic_arrow_back", symbol: "chevron.left")
                            .frame(width: 22, height: 22)
                        Text("Timetable")
                            .font(.system(size: 17))
                    }
                    .foregroundStyle(UntisPalette.brand)
                    .padding(.vertical, 8)
                    .padding(.trailing, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(UntisPalette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(UntisPalette.separator).frame(height: 0.6)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(entry.status == .normal ? Color(hex: entry.colorHex).darker(by: 0.24) : entry.status.accent)
                .frame(width: 5, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(UntisPalette.title)
                    .strikethrough(entry.status == .cancelled)
                if !entry.subjectLong.isEmpty, !entry.subject.isEmpty {
                    Text(entry.subject)
                        .font(.system(size: 14))
                        .foregroundStyle(UntisPalette.subtitle)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private func statusBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            UntisIcon(asset: statusIcon, symbol: "circle")
                .foregroundStyle(entry.status.accent)
                .frame(width: 22, height: 22)
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(UntisPalette.title)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(entry.status.fill)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(entry.status.accent, lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var timeText: String {
        var parts: [String] = []
        if !entry.startTime.isEmpty, !entry.endTime.isEmpty {
            parts.append("\(entry.startTime) – \(entry.endTime)")
        }
        if !periodLabel.isEmpty { parts.append(periodLabel) }
        return parts.joined(separator: "  ·  ")
    }

    private var divider: some View {
        Rectangle()
            .fill(UntisPalette.separator.opacity(0.7))
            .frame(height: 0.6)
            .padding(.leading, 54)
    }

    private func row(icon: String, symbol: String, caption: String, value: String, original: String = "") -> some View {
        HStack(alignment: .top, spacing: 14) {
            UntisIcon(asset: icon, symbol: symbol)
                .frame(width: 22, height: 22)
                .foregroundStyle(UntisPalette.navigationTint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(caption)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(UntisPalette.subtitle)
                Text(value.isEmpty ? "—" : value)
                    .font(.system(size: 17))
                    .foregroundStyle(UntisPalette.title)
                if !original.isEmpty {
                    Text(original)
                        .font(.system(size: 14))
                        .strikethrough()
                        .foregroundStyle(UntisPalette.subtitle)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}
