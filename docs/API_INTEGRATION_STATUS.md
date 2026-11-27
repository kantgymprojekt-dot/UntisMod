# WebUntis API integration status

## Included now

- `UntisMobile/UntisAPI.swift` is part of the Xcode target's Sources phase.
- School-search endpoint: `https://schoolsearch.webuntis.com/schoolquery2`.
- Public login metadata path: `/WebUntis/api/public/v1/login-meta`.
- JSON-RPC path: `/WebUntis/jsonrpc_intern.do?school=...`.
- Method wrappers named after methods identified in the supplied Untis 6.8.3 XAPK: `getAuthToken`, `getUserData2017`, `getTimetable2017`, `getPeriodData2017`, and `getExams2017`.

## Not yet complete

The API transport is not yet a complete account implementation. The current SwiftUI screens do not call it. The exact authentication payload/token serialization, OTP or challenge flow, cookie/session behavior, response DTOs, and real-school login have not been verified end to end. Consequently this project should not yet be described as capable of logging into a school or loading a live timetable.

## Security

Do not commit school credentials, passwords, tokens, cookies, or personal timetable exports. Persist secrets in iOS Keychain when a verified login flow is implemented. Keep GitHub Actions logs free of credentials and response bodies containing personal data.
