import Foundation

struct RemotePaymentProofRepository: PaymentProofRepository {
    typealias DocumentLoader = @Sendable (URL) throws -> Data
    private let transport: HTTPTransport; private let tokenProvider: AuthTokenProvider
    private let documentLoader: DocumentLoader
    init(transport: HTTPTransport, tokenProvider: AuthTokenProvider,
         documentLoader: @escaping DocumentLoader = { try Data(contentsOf: $0, options: .mappedIfSafe) }) {
        self.transport = transport; self.tokenProvider = tokenProvider; self.documentLoader = documentLoader
    }
    func instructions(bookingId: String) async throws -> PaymentInstructionsResult {
        do {
            guard let token = try await tokenProvider.accessToken() else { return .authRequired }
            let response = try await transport.send(HTTPRequest(
                target: .mobile("trips/\(bookingId)/payment-instructions"),
                authorization: .bearer(token)
            ))
            switch response.statusCode {
            case 200:
                guard let instructions = try? JSONDecoder().decode(PaymentInstructions.self, from: response.data) else {
                    return .failed
                }
                return .available(instructions)
            case 401: return .authRequired
            case 404: return .unavailable
            default: return .failed
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch HTTPTransportError.networkUnavailable, HTTPTransportError.timedOut {
            return .offline
        } catch {
            return .failed
        }
    }

    func upload(bookingId: String, document: PaymentProofAttachment) async throws -> PaymentProofUploadResult {
        guard let contentType = document.mimeType?.split(separator: ";").first.map(String.init)?.lowercased(),
              Self.allowedTypes.contains(contentType), let url = URL(string: document.uriString), url.isFileURL else {
            return .invalidDocument
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let bytes = try? documentLoader(url), !bytes.isEmpty, bytes.count <= Self.maximumBytes else { return .invalidDocument }
        do {
            guard let token = try await tokenProvider.accessToken() else { return .authRequired }
            let body = try JSONEncoder().encode(PaymentProofCreateDTO(
                contentType: contentType, fileName: document.displayName, sizeBytes: bytes.count
            ))
            let createResponse = try await transport.send(HTTPRequest(
                target: .mobile("bookings/\(bookingId)/payment-proof-upload"), method: .post,
                body: body, authorization: .bearer(token)
            ))
            guard createResponse.statusCode != 401 else { return .authRequired }
            guard (200..<300).contains(createResponse.statusCode),
                  let created = try? JSONDecoder().decode(PaymentProofUploadDTO.self, from: createResponse.data),
                  let uploadURL = URL(string: created.uploadUrl) else { return .failed }
            let putResponse = try await transport.send(HTTPRequest(
                target: .absolute(uploadURL), method: .put, headers: created.requiredHeaders,
                body: bytes, authorization: .none
            ))
            guard (200..<300).contains(putResponse.statusCode) else { return .failed }
            let completeResponse = try await transport.send(HTTPRequest(
                target: .mobile("bookings/\(bookingId)/payment-proof-upload/\(created.uploadId)/complete"),
                method: .post, authorization: .bearer(token)
            ))
            guard completeResponse.statusCode != 401 else { return .authRequired }
            guard (200..<300).contains(completeResponse.statusCode),
                  let completed = try? JSONDecoder().decode(PaymentProofCompletedDTO.self, from: completeResponse.data),
                  !completed.id.isEmpty else { return .failed }
            return .success
        } catch is CancellationError { throw CancellationError() }
        catch HTTPTransportError.networkUnavailable, HTTPTransportError.timedOut { return .networkUnavailable }
        catch { return .failed }
    }
    private static let maximumBytes = 10_000_000
    private static let allowedTypes = Set(["application/pdf", "image/jpeg", "image/png"])
}
private struct PaymentProofCreateDTO: Encodable { let contentType, fileName: String; let sizeBytes: Int }
private struct PaymentProofUploadDTO: Decodable { let uploadId, status, uploadUrl: String; let requiredHeaders: [String: String] }
private struct PaymentProofCompletedDTO: Decodable { let id: String }
