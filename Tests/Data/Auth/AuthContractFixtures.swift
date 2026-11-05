import Foundation

enum AuthContractFixtures {
    static let now = Date(timeIntervalSince1970: 1_777_800_000)

    static let tokenEnvelope = Data(#"{"redirect":false,"token":"body-token","future":true,"user":{"id":"user-1","name":"Selam","email":"selam@example.com","emailVerified":true,"image":null,"createdAt":"2026-05-03T12:00:00.000Z","updatedAt":"2026-05-03T12:00:00.000Z","future":"ignored"}}"#.utf8)

    static let tokenEnvelopeWithoutVerificationField = Data(#"{"token":"body-token","user":{"id":"user-1","name":"Selam","email":"selam@example.com","image":null}}"#.utf8)

    static let tokenEnvelopeWithoutToken = Data(#"{"user":{"id":"user-1","name":"Selam","email":"selam@example.com","emailVerified":true,"image":null}}"#.utf8)

    static let signupPending = Data(#"{"token":null,"user":{"id":"user-1","name":"Selam","email":"selam@example.com","emailVerified":false,"image":null}}"#.utf8)

    static let signupTokenForUnverifiedUser = Data(#"{"token":"must-not-store","user":{"id":"user-1","name":"Selam","email":"selam@example.com","emailVerified":false,"image":null}}"#.utf8)

    static let tokenEnvelopeMissingUser = Data(#"{"token":"body-token"}"#.utf8)

    static let sessionEnvelope = Data(#"{"session":{"id":"session-1","userId":"user-1","token":"session-token","expiresAt":"2026-09-04T12:00:00.000Z","createdAt":"2026-08-28T12:00:00Z","updatedAt":"2026-08-28T12:00:00Z"},"user":{"id":"user-1","name":"Selam","email":"selam@example.com","emailVerified":true,"image":null}}"#.utf8)

    static let nullSession = Data("null".utf8)

    static func error(code: String, message: String = "Authentication request failed.",
                      fieldErrors: [String: String]? = nil) -> Data {
        (try? JSONEncoder().encode(ErrorFixture(code: code, message: message, fieldErrors: fieldErrors))) ?? Data()
    }

    private struct ErrorFixture: Encodable {
        let code: String
        let message: String
        let fieldErrors: [String: String]?
    }
}
