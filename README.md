# Untis API integration layer

This patch adds a native Swift networking layer based on the endpoint paths, JSON-RPC method names, and DTO field names observed in the user-supplied Untis 6.8.3 XAPK.

Included verified source details:
- School search URL: `https://schoolsearch.webuntis.com/schoolquery2`
- School search request fields: `search`, `tenantid`
- Public login metadata path: `/WebUntis/api/public/v1/login-meta`
- JSON-RPC path: `/WebUntis/jsonrpc_intern.do?school=...`
- Mobile method names: `getAuthToken`, `getUserData2017`, `getTimetable2017`, `getPeriodData2017`, `getExams2017`
- Timetable DTO fields: `type`, `id`, `startDate`, `endDate`, `masterDataTimestamp`, `timetableTimestamp`
- Period data DTO field: `ttIds`
- Exam DTO fields: `type`, `id`, `startDate`, `endDate`

## Apply
1. Copy `UntisMobile/UntisAPI.swift` into the `UntisMobile` folder in your Xcode project.
2. Replace `UntisMobile.xcodeproj/project.pbxproj` with the supplied `UntisMobile.xcodeproj.project.pbxproj` (rename it to `project.pbxproj`).

## Important integration status
This is the API transport layer, not a finished school-login UI. The XAPK's DTO classes show the method names and payload members, but this inspection output does not reveal the complete authentication credential/token serialization or every school-search response field. The `getAuthenticationToken` call therefore accepts the auth request dictionary from the login flow rather than inventing its fields. Before enabling login in the shipped app, test against a real school account and confirm the exact login response, token object, cookie/session behavior, and server response mapping. Do not send credentials to an unverified endpoint or store them in UserDefaults.
