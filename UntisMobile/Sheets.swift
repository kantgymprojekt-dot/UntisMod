import SwiftUI

// MARK: - Lesson editor (offline demo only)

struct LessonEditorSheet: View {
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

// MARK: - Edit code sheets (offline demo only)

enum PasscodeSheetMode {
    case set
    case enter
}

struct PasscodeSheet: View {
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

// MARK: - Go to date

struct GoToDateSheet: View {
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

// MARK: - Class / timetable picker (live Untis data)

struct ClassPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var app: AppModel
    @State private var search = ""

    private var filtered: [UntisKlasse] {
        let term = search.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return app.klassen }
        return app.klassen.filter {
            $0.name.localizedCaseInsensitiveContains(term)
                || ($0.longName ?? "").localizedCaseInsensitiveContains(term)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        app.selectOwnTimetable()
                        dismiss()
                    } label: {
                        pickerRow(title: "My timetable",
                                  subtitle: app.profile?.username ?? "",
                                  isSelected: app.isOwnTimetableSelected)
                    }
                }

                Section("Classes") {
                    if app.klassen.isEmpty {
                        Text(app.klassenError ?? "Loading classes…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filtered) { klasse in
                            Button {
                                app.select(TimetableElement(type: 1, id: klasse.id, name: klasse.name))
                                dismiss()
                            } label: {
                                pickerRow(title: klasse.name,
                                          subtitle: klasse.longName ?? "",
                                          isSelected: app.element == TimetableElement(type: 1, id: klasse.id, name: klasse.name))
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search classes")
            .navigationTitle("Timetable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task {
                if app.klassen.isEmpty { await app.loadKlassen() }
            }
        }
        .presentationDetents([.large])
    }

    private func pickerRow(title: String, subtitle: String, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(UntisPalette.title)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(UntisPalette.subtitle)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(UntisPalette.brand)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Options, help and info

struct TimetableOptionsSheet: View {
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
                    Text("These preferences are saved on this device. Pinch the timetable to zoom; single periods show their room once zoomed in.")
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

struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    let isLive: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("Timetable colours") {
                    Label("Cancellation", systemImage: "xmark.circle.fill").foregroundStyle(UntisPalette.cancelledBorder)
                    Label("Change / substitution", systemImage: "arrow.left.arrow.right.circle.fill").foregroundStyle(UntisPalette.changeBorder)
                    Label("Exam", systemImage: "doc.text.fill").foregroundStyle(UntisPalette.examBorder)
                }
                Section("Gestures") {
                    Text("Swipe left or right to move through the timetable. Pinch to zoom in or out. Pull down to refresh.")
                }
                if !isLive {
                    Section("Editing the demo timetable") {
                        Text("Set a four-digit code from the three-dot menu. Enter that code to unlock editing of the demo week. After three incorrect attempts, editing is locked for five minutes.")
                    }
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

struct InfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let isLive: Bool

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
                            Text("Unofficial iOS client · visual reference 6.8.3")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Data") {
                    Text(isLive
                         ? "Timetable data is loaded from your school's WebUntis server (JSON-RPC). Your password is kept in the iOS keychain."
                         : "You are looking at the offline demo week, stored locally. Log in from the Profile tab to see your real timetable.")
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
