import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Native client for the WebUntis endpoints and JSON-RPC method names
// identified in the supplied Untis 6.8.3 XAPK.
// Credentials are deliberately never persisted by this type.
struct UntisSchool: Codable, Identifiable, Hashable {
    var id: String { "\(tenantID)|\(serverURL)|\(schoolName)" }
    let schoolName: String
    let serverURL: String
    let tenantID: String
    let displayName: String?
    let loginName: String?

    enum CodingKeys: String, CodingKey {
        case schoolName, serverURL, tenantID, displayName, loginName
        case name, address, server, tenantid, tenantId, school
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schoolName = (try? c.decode(String.self, forKey: .schoolName))
            ?? (try? c.decode(String.self, forKey: .name))
            ?? (try? c.decode(String.self, forKey: .school)) ?? ""
        serverURL = (try? c.decode(String.self, forKey: .serverURL))
            ?? (try? c.decode(String.self, forKey: .address))
            ?? (try? c.decode(String.self, forKey: .server)) ?? ""
        tenantID = (try? c.decode(String.self, forKey: .tenantID))
            ?? (try? c.decode(String.self, forKey: .tenantid))
            ?? (try? c.decode(String.self, forKey: .tenantId)) ?? ""
        displayName = try? c.decode(String.self, forKey: .displayName)
        loginName = try? c.decode(String.self, forKey: .loginName)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schoolName, forKey: .schoolName)
        try c.encode(serverURL, forKey: .serverURL)
        try c.encode(tenantID, forKey: .tenantID)
        try c.encodeIfPresent(displayName, forKey: .displayName)
        try c.encodeIfPresent(loginName, forKey: .loginName)
    }
}

struct UntisRPCEnvelope: Decodable {
    let result: AnyCodable?
    let error: UntisRPCError?
}

struct UntisRPCError: Decodable, LocalizedError {
    let code: Int?
    let message: String?
    var errorDescription: String? { message ?? "WebUntis returned a JSON-RPC error." }
}

struct AnyCodable: Decodable {
    let value: Any
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { value = v }
        else if let v = try? c.decode(Int.self) { value = v }
        else if let v = try? c.decode(Double.self) { value = v }
        else if let v = try? c.decode(Bool.self) { value = v }
        else if let v = try? c.decode([String: AnyCodable].self) { value = v.mapValues(\.value) }
        else if let v = try? c.decode([AnyCodable].self) { value = v.map(\.value) }
        else if (try? c.decodeNil()) == true { value = NSNull() }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value") }
    }
}

struct UntisLoginMetadata: Decodable {
    let loginEnabled: Bool?
    let ssoEnabled: Bool?
    let schoolName: String?
    let tenantId: String?
}

enum UntisAPIError: LocalizedError {
    case invalidURL
    case http(Int, String)
    case rpc(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The school server address is invalid."
        case .http(let code, let message): return "WebUntis HTTP \(code): \(message)"
        case .rpc(let message): return message
        case .invalidResponse: return "The school server returned an unreadable response."
        }
    }
}

final class UntisAPIClient {
    static let schoolSearchURL = URL(string: "https://schoolsearch.webuntis.com/schoolquery2")!
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var requestID = 1

    init(session: URLSession = .shared) { self.session = session }

    /// Calls the XAPK's school-search endpoint (`schoolquery2`) with the
    /// `search` and `tenantid` request fields found in SchoolSearchRequest.
    func searchSchools(_ query: String, tenantID: String = "") async throws -> [UntisSchool] {
        struct SearchBody: Encodable {
            let search: String
            let tenantid: String
        }
        var request = URLRequest(url: Self.schoolSearchURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "id": "untis-mobile-ios-1.0",
            "jsonrpc": "2.0",
            "method": "searchSchool",
            "params": [["search": query, "tenantid": tenantID]]
        ])
        let data = try await perform(request)
        if let wrapped = try? decoder.decode(SchoolSearchWrapper.self, from: data) {
            return wrapped.schools
        }
        if let direct = try? decoder.decode([UntisSchool].self, from: data) { return direct }
        throw UntisAPIError.invalidResponse
    }

    /// Reads the public login metadata endpoint present in the supplied XAPK.
    func loginMetadata(for school: UntisSchool) async throws -> Data {
        let base = try normalizedServerURL(school.serverURL)
        var components = URLComponents(url: base.appendingPathComponent("WebUntis/api/public/v1/login-meta"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "school", value: school.tenantID.isEmpty ? school.schoolName : school.tenantID)]
        guard let url = components?.url else { throw UntisAPIError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request)
    }

    /// Sends a JSON-RPC call to the original internal endpoint. The mobile
    /// method names below are taken from the supplied 6.8.3 XAPK.
    func call<T: Decodable>(
        school: UntisSchool,
        method: String,
        params: [String: Any],
        sessionCookie: String? = nil,
        response: T.Type = T.self
    ) async throws -> T {
        let base = try normalizedServerURL(school.serverURL)
        var components = URLComponents(url: base.appendingPathComponent("WebUntis/jsonrpc_intern.do"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "school", value: school.tenantID.isEmpty ? school.schoolName : school.tenantID)]
        guard let url = components?.url else { throw UntisAPIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let sessionCookie { request.setValue(sessionCookie, forHTTPHeaderField: "Cookie") }
        let body: [String: Any] = ["id": "untis-mobile-ios-\(nextID())", "method": method, "params": [params], "jsonrpc": "2.0"]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await perform(request)
        let envelope = try decoder.decode(RPCResult<T>.self, from: data)
        if let error = envelope.error { throw UntisAPIError.rpc(error.message ?? "JSON-RPC error \(error.code ?? 0)") }
        guard let result = envelope.result else { throw UntisAPIError.invalidResponse }
        return result
    }

    /// Original mobile API methods identified in the XAPK. The caller supplies
    /// the request DTO values and auth object so no undocumented credentials
    /// or token fields are guessed or hard-coded here.
    func getAuthenticationToken(school: UntisSchool, params: [String: Any]) async throws -> Data {
        try await rawRPC(school: school, method: "getAuthToken", params: params)
    }

    func getUserData(school: UntisSchool, auth: [String: Any], additional: [String: Any] = [:]) async throws -> Data {
        try await rawRPC(school: school, method: "getUserData2017", params: authenticated(auth, additional))
    }

    func getTimetable(school: UntisSchool, auth: [String: Any], type: String, id: Int, startDate: String, endDate: String, masterDataTimestamp: Int64 = 0, timetableTimestamp: Int64 = 0) async throws -> Data {
        let dto: [String: Any] = ["type": type, "id": id, "startDate": startDate, "endDate": endDate, "masterDataTimestamp": masterDataTimestamp, "timetableTimestamp": timetableTimestamp]
        return try await rawRPC(school: school, method: "getTimetable2017", params: authenticated(auth, dto))
    }

    func getPeriodData(school: UntisSchool, auth: [String: Any], timetableIDs: [Int]) async throws -> Data {
        try await rawRPC(school: school, method: "getPeriodData2017", params: authenticated(auth, ["ttIds": timetableIDs]))
    }

    func getExams(school: UntisSchool, auth: [String: Any], type: String, id: Int, startDate: String, endDate: String) async throws -> Data {
        let dto: [String: Any] = ["type": type, "id": id, "startDate": startDate, "endDate": endDate]
        return try await rawRPC(school: school, method: "getExams2017", params: authenticated(auth, dto))
    }

    private func rawRPC(school: UntisSchool, method: String, params: [String: Any]) async throws -> Data {
        let base = try normalizedServerURL(school.serverURL)
        var components = URLComponents(url: base.appendingPathComponent("WebUntis/jsonrpc_intern.do"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "school", value: school.tenantID.isEmpty ? school.schoolName : school.tenantID)]
        guard let url = components?.url else { throw UntisAPIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["id": "untis-mobile-ios-\(nextID())", "method": method, "params": [params], "jsonrpc": "2.0"])
        return try await perform(request)
    }

    private func authenticated(_ auth: [String: Any], _ values: [String: Any]) -> [String: Any] {
        var result = values
        result["auth"] = auth
        return result
    }

    private func normalizedServerURL(_ value: String) throws -> URL {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate), let scheme = url.scheme, ["https", "http"].contains(scheme), url.host != nil else { throw UntisAPIError.invalidURL }
        return url
    }

    private func nextID() -> Int { requestID += 1; return requestID }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UntisAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw UntisAPIError.http(http.statusCode, String(message.prefix(300)))
        }
        return data
    }
}

private struct SchoolSearchWrapper: Decodable { let schools: [UntisSchool] }
private struct RPCResult<T: Decodable>: Decodable {
    let result: T?
    let error: UntisRPCError?
}
