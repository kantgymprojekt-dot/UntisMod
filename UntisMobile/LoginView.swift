import SwiftUI

// MARK: - School search and login against the Untis JSON-RPC API

struct LoginView: View {
    @ObservedObject var app: AppModel
    let allowsDemo: Bool
    let onFinished: () -> Void

    @State private var query = ""
    @State private var results: [UntisSchool] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var selectedSchool: UntisSchool?
    @State private var username = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var loginError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let school = selectedSchool {
                    credentialsForm(for: school)
                } else {
                    schoolSearch
                }

                if allowsDemo {
                    Button(action: onFinished) {
                        Text("Continue with demo timetable")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(UntisPalette.subtitle)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(UntisPalette.surface.ignoresSafeArea())
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            UntisIcon(asset: "untis_logo_round", symbol: "graduationcap.circle.fill", template: false)
                .foregroundStyle(UntisPalette.brand)
                .frame(width: 54, height: 54)
                .padding(.top, 24)
            Text(selectedSchool == nil ? "Search your school" : "Log in")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(UntisPalette.title)
            Text(selectedSchool == nil
                 ? "Enter school name or address"
                 : "Log in with your Untis user name and password.")
                .font(.system(size: 15))
                .foregroundStyle(UntisPalette.subtitle)
        }
    }

    // MARK: Step 1 – school search

    private var schoolSearch: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                UntisIcon(asset: "untis_ic_search", symbol: "magnifyingglass")
                    .foregroundStyle(UntisPalette.subtitle)
                    .frame(width: 20, height: 20)
                TextField("Search school", text: $query)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                if isSearching {
                    ProgressView()
                }
            }
            .padding(12)
            .background(UntisPalette.timetableBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if let searchError {
                Text(searchError)
                    .font(.system(size: 13))
                    .foregroundStyle(UntisPalette.cancelledBorder)
            } else if results.isEmpty, query.trimmingCharacters(in: .whitespaces).count >= 3, !isSearching {
                Text("No school found")
                    .font(.system(size: 13))
                    .foregroundStyle(UntisPalette.subtitle)
            }

            VStack(spacing: 0) {
                ForEach(results) { school in
                    Button {
                        selectedSchool = school
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(school.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(UntisPalette.title)
                                .multilineTextAlignment(.leading)
                            if !school.address.isEmpty {
                                Text(school.address)
                                    .font(.system(size: 13))
                                    .foregroundStyle(UntisPalette.subtitle)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
        .task(id: query) {
            await search()
        }
    }

    private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 3 else {
            results = []
            searchError = nil
            return
        }

        do {
            try await Task.sleep(nanoseconds: 400_000_000)
        } catch {
            return
        }

        isSearching = true
        defer { isSearching = false }
        do {
            let found = try await app.searchSchools(term)
            if !Task.isCancelled {
                results = found
                searchError = nil
            }
        } catch {
            if !Task.isCancelled {
                searchError = error.localizedDescription
            }
        }
    }

    // MARK: Step 2 – credentials

    private func credentialsForm(for school: UntisSchool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                selectedSchool = nil
                loginError = nil
            } label: {
                HStack(spacing: 6) {
                    UntisIcon(asset: "untis_ic_arrow_back", symbol: "chevron.left")
                        .frame(width: 20, height: 20)
                    Text(school.displayName)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(UntisPalette.brand)
            }
            .buttonStyle(.plain)

            TextField("Username", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(13)
                .background(UntisPalette.timetableBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            SecureField("Password", text: $password)
                .textContentType(.password)
                .padding(13)
                .background(UntisPalette.timetableBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if let loginError {
                Text(loginError)
                    .font(.system(size: 13))
                    .foregroundStyle(UntisPalette.cancelledBorder)
            }

            Button(action: logIn) {
                HStack {
                    if isLoggingIn { ProgressView().tint(.white) }
                    Text("Log in")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canLogIn ? UntisPalette.brand : UntisPalette.brand.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .disabled(!canLogIn)

            Text("Your password is kept in the iOS keychain on this device and only sent to your school's Untis server.")
                .font(.system(size: 12))
                .foregroundStyle(UntisPalette.subtitle)
        }
    }

    private var canLogIn: Bool {
        !isLoggingIn
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
    }

    private func logIn() {
        guard let school = selectedSchool else { return }
        isLoggingIn = true
        loginError = nil

        Task {
            do {
                try await app.login(
                    school: school,
                    username: username.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                isLoggingIn = false
                onFinished()
            } catch {
                loginError = error.localizedDescription
                isLoggingIn = false
            }
        }
    }
}
