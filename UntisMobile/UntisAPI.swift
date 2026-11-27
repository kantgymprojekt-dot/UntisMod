import Foundation
import Security

// MARK: - Errors

enum UntisError: LocalizedError {
    case invalidURL
    case network(String)
    case server(code: Int, message: String)
    case badResponse
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server address is not valid."
        case .network(let text):
            return "Network error: \(text)"
        case .server(let code, let message):
            switch code {
            case -8504: return "Wrong user name or password."
            case -8520: return "Your session has expired. Please log in again."
            case -8509: return "Your account is not allowed to load this data. Try choosing a class instead."
            default: return "\(message) (code \(code))"
            }
        case .badResponse:
            return "The Untis server sent an answer this app does not understand."
        case .notLoggedIn:
            return "You are not logged in."
        }
    }

    var isSessionExpired: Bool {
        if case .server(let code, let message) = self {
            return code == -8520 || message.lowercased().contains("not authenticated")
        }
        return false
    }
}

// MARK: - API models

struct UntisSchool: Identifiable, Decodable, Hashable {
    let server: String
    let displayName: String
    let loginName: String
    let address: String

    var id: String { "\(server)|\(loginName)" }

    private enum CodingKeys: String, CodingKey {
        case server, displayName, loginName, address
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        server = try container.decodeIfPresent(String.self, forKey: .server) ?? ""
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        loginName = try container.decodeIfPresent(String.self, forKey: .loginName) ?? ""
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
    }
}

struct UntisSession {
    let server: String
    let school: String
    var sessionId: String
    let personType: Int
    let personId: Int
    let klasseId: Int
}

struct UntisKlasse: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let longName: String?
}

struct RawTimeUnit: Decodable {
    let name: String
    let startTime: Int
    let endTime: Int

    private enum CodingKeys: String, CodingKey { case name, startTime, endTime }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try? container.decode(String.self, forKey: .name) {
            name = text
        } else if let number = try? container.decode(Int.self, forKey: .name) {
            name = String(number)
        } else {
            name = ""
        }
        startTime = try container.decode(Int.self, forKey: .startTime)
        endTime = try container.decode(Int.self, forKey: .endTime)
    }
}

struct RawTimegridDay: Decodable {
    let day: Int
    let timeUnits: [RawTimeUnit]
}

struct RawElement: Decodable {
    let id: Int?
    let name: String?
    let longname: String?
    let orgid: Int?
    let orgname: String?

    var isChanged: Bool { orgid != nil || (orgname?.isEmpty == false) }
}

struct RawPeriod: Decodable {
    let id: Int?
    let date: Int
    let startTime: Int
    let endTime: Int
    let kl: [RawElement]?
    let te: [RawElement]?
    let su: [RawElement]?
    let ro: [RawElement]?
    let lstype: String?
    let code: String?
    let lstext: String?
    let substText: String?
    let info: String?
}

// MARK: - JSON-RPC client (WebUntis)

final class UntisClient {
    private let urlSession: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 25
        configuration.httpShouldSetCookies = false
        urlSession = URLSession(configuration: configuration)
    }

    // MARK: Public calls

    func searchSchools(_ term: String) async throws -> [UntisSchool] {
        struct Found: Decodable { let schools: [UntisSchool] }

        guard let url = URL(string: "https://mobile.webuntis.com/ms/schoolquery2") else {
            throw UntisError.invalidURL
        }
        let body: [String: Any] = [
            "id": "UntisMod",
            "method": "searchSchool",
            "params": [["search": term]],
            "jsonrpc": "2.0"
        ]
        let data = try await post(url, body: body, sessionId: nil)
        let found: Found = try decodeEnvelope(Found.self, from: data)
        return found.schools.filter { !$0.server.isEmpty && !$0.loginName.isEmpty }
    }

    func authenticate(server: String, school: String, user: String, password: String) async throws -> UntisSession {
        struct AuthPayload: Decodable {
            let sessionId: String
            let personType: Int?
            let personId: Int?
            let klasseId: Int?
        }

        let params: [String: Any] = ["user": user, "password": password, "client": "UntisMod"]
        let result = try await call(AuthPayload.self, server: server, school: school, sessionId: nil,
                                    method: "authenticate", params: params)
        return UntisSession(
            server: server,
            school: school,
            sessionId: result.sessionId,
            personType: result.personType ?? 0,
            personId: result.personId ?? 0,
            klasseId: result.klasseId ?? 0
        )
    }

    func klassen(_ session: UntisSession) async throws -> [UntisKlasse] {
        try await call([UntisKlasse].self, server: session.server, school: session.school,
                       sessionId: session.sessionId, method: "getKlassen", params: [String: Any]())
    }

    func timegrid(_ session: UntisSession) async throws -> [RawTimegridDay] {
        try await call([RawTimegridDay].self, server: session.server, school: session.school,
                       sessionId: session.sessionId, method: "getTimegridUnits", params: [String: Any]())
    }

    /// `elementType`: 1 class, 2 teacher, 3 subject, 4 room, 5 student.
    func timetable(
        _ session: UntisSession,
        elementType: Int,
        elementId: Int,
        from: Date,
        to: Date
    ) async throws -> [RawPeriod] {
        let fields = ["id", "name", "longname"]
        let options: [String: Any] = [
            "element": ["id": elementId, "type": elementType],
            "startDate": UntisCalendar.key(from),
            "endDate": UntisCalendar.key(to),
            "showInfo": true,
            "showSubstText": true,
            "showLsText": true,
            "showLsNumber": true,
            "showStudentgroup": true,
            "showBooking": false,
            "klasseFields": fields,
            "roomFields": fields,
            "subjectFields": fields,
            "teacherFields": fields
        ]
        return try await call([RawPeriod].self, server: session.server, school: session.school,
                              sessionId: session.sessionId, method: "getTimetable", params: ["options": options])
    }

    func logout(_ session: UntisSession) async {
        guard let url = endpoint(server: session.server, school: session.school) else { return }
        let body: [String: Any] = ["id": "UntisMod", "method": "logout", "params": [String: Any](), "jsonrpc": "2.0"]
        _ = try? await post(url, body: body, sessionId: session.sessionId)
    }

    // MARK: Plumbing

    private struct RPCError: Decodable {
        let code: Int
        let message: String
    }

    private struct RPCEnvelope<Payload: Decodable>: Decodable {
        let result: Payload?
        let error: RPCError?
    }

    private func endpoint(server: String, school: String) -> URL? {
        var host = server.trimmingCharacters(in: .whitespacesAndNewlines)
        host = host.replacingOccurrences(of: "https://", with: "")
        host = host.replacingOccurrences(of: "http://", with: "")
        if let slash = host.firstIndex(of: "/") { host = String(host[..<slash]) }

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/WebUntis/jsonrpc.do"
        components.queryItems = [URLQueryItem(name: "school", value: school)]
        return components.url
    }

    private func call<Payload: Decodable>(
        _ type: Payload.Type,
        server: String,
        school: String,
        sessionId: String?,
        method: String,
        params: Any
    ) async throws -> Payload {
        guard let url = endpoint(server: server, school: school) else { throw UntisError.invalidURL }
        let body: [String: Any] = ["id": "UntisMod", "method": method, "params": params, "jsonrpc": "2.0"]
        let data = try await post(url, body: body, sessionId: sessionId)
        return try decodeEnvelope(Payload.self, from: data)
    }

    private func decodeEnvelope<Payload: Decodable>(_ type: Payload.Type, from data: Data) throws -> Payload {
        let envelope: RPCEnvelope<Payload>
        do {
            envelope = try JSONDecoder().decode(RPCEnvelope<Payload>.self, from: data)
        } catch {
            throw UntisError.badResponse
        }
        if let error = envelope.error {
            throw UntisError.server(code: error.code, message: error.message)
        }
        guard let result = envelope.result else { throw UntisError.badResponse }
        return result
    }

    private func post(_ url: URL, body: [String: Any], sessionId: String?) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let sessionId {
            request.setValue("JSESSIONID=\(sessionId)", forHTTPHeaderField: "Cookie")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await urlSession.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                if http.statusCode == 401 {
                    throw UntisError.server(code: -8520, message: "Not authenticated")
                }
                throw UntisError.network("HTTP \(http.statusCode)")
            }
            return data
        } catch let error as UntisError {
            throw error
        } catch {
            throw UntisError.network(error.localizedDescription)
        }
    }
}

// MARK: - Keychain (the Untis password never goes into UserDefaults)

enum Keychain {
    private static let service = "UntisMod"

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func save(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        SecItemDelete(baseQuery(account: account) as CFDictionary)

        var item = baseQuery(account: account)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    static func load(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
}
