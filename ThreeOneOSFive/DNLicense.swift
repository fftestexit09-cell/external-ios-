import Foundation
import SwiftUI
import Security

private enum DNKeychain {
    static let service = "com.externalios.dnlicense"

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}

@MainActor
final class DNLicenseManager: ObservableObject {
    @Published var isLicensed = false
    @Published var message = ""
    @Published var isLoading = false

    private let account = "2aca6104"
    private let policyID = "61ec76e6-511e-4888-8f99-8177ee8abeff"
    private let apiRoot = URL(string: "https://api.keygen.sh/v1")!

    private var installationID: String {
        if let existing = DNKeychain.read("installation_id") { return existing }
        let value = UUID().uuidString.lowercased()
        DNKeychain.write(value, account: "installation_id")
        return value
    }

    func validateSavedLicense() async {
        guard let key = DNKeychain.read("license_key"), !key.isEmpty else { return }
        await validateOrActivate(key: key, allowActivation: false)
    }

    func activate(key: String) async {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            isLicensed = false
            message = "Digite uma key válida."
            return
        }

        await validateOrActivate(key: normalized, allowActivation: true)
        if isLicensed {
            DNKeychain.write(normalized, account: "license_key")
        }
    }

    private func validateOrActivate(key: String, allowActivation: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await validateKey(key)
            let code = result.code.uppercased()

            if result.valid {
                isLicensed = true
                message = "Licença válida."
                return
            }

            if allowActivation && (code == "NO_MACHINE" || code == "NO_MACHINES") {
                guard let licenseID = result.licenseID, !licenseID.isEmpty else {
                    isLicensed = false
                    message = "Resposta de licença inválida."
                    return
                }

                try await activateMachine(key: key, licenseID: licenseID)
                let second = try await validateKey(key)
                isLicensed = second.valid
                message = second.valid ? "Licença ativada neste iPhone." : friendlyMessage(for: second.code, detail: second.detail)
                return
            }

            isLicensed = false
            message = friendlyMessage(for: code, detail: result.detail)
        } catch let error as URLError {
            isLicensed = false
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                message = "Sem conexão com a internet."
            case .timedOut:
                message = "O servidor demorou para responder."
            default:
                message = "Falha de comunicação com o Keygen."
            }
        } catch {
            isLicensed = false
            message = "Não foi possível validar a licença."
        }
    }

    private struct ValidationResult {
        let valid: Bool
        let code: String
        let detail: String?
        let licenseID: String?
    }

    private func validateKey(_ key: String) async throws -> ValidationResult {
        let url = apiRoot
            .appendingPathComponent("accounts")
            .appendingPathComponent(account)
            .appendingPathComponent("licenses/actions/validate-key")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "meta": [
                "key": key,
                "scope": [
                    "policy": policyID,
                    "fingerprint": installationID
                ]
            ]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 404 {
                return ValidationResult(valid: false, code: "INVALID", detail: "Key não encontrada.", licenseID: nil)
            }
            throw URLError(.badServerResponse)
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        let meta = object["meta"] as? [String: Any]
        let valid = meta?["valid"] as? Bool ?? false
        let code = meta?["code"] as? String ?? (valid ? "VALID" : "INVALID")
        let detail = meta?["detail"] as? String

        let license = object["data"] as? [String: Any]
        let licenseID = license?["id"] as? String

        return ValidationResult(valid: valid, code: code, detail: detail, licenseID: licenseID)
    }

    private func activateMachine(key: String, licenseID: String) async throws {
        let url = apiRoot
            .appendingPathComponent("accounts")
            .appendingPathComponent(account)
            .appendingPathComponent("machines")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Accept")
        request.setValue("License \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "data": [
                "type": "machines",
                "attributes": [
                    "fingerprint": installationID,
                    "platform": "iOS",
                    "name": "iPhone"
                ],
                "relationships": [
                    "license": [
                        "data": [
                            "type": "licenses",
                            "id": licenseID
                        ]
                    ]
                ]
            ]
        ])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(http.statusCode) else {
            throw URLError(.cannotCreateFile)
        }
    }

    private func friendlyMessage(for code: String, detail: String?) -> String {
        switch code.uppercased() {
        case "VALID":
            return "Licença válida."
        case "FINGERPRINT_SCOPE_MISMATCH":
            return "Esta key já está vinculada a outro dispositivo."
        case "POLICY_SCOPE_MISMATCH":
            return "Esta key não pertence ao EXTERNAL IOS."
        case "EXPIRED":
            return "Esta key expirou."
        case "SUSPENDED":
            return "Esta key foi suspensa."
        case "BANNED":
            return "Esta licença foi bloqueada."
        case "NO_MACHINE", "NO_MACHINES":
            return "Esta key ainda não foi ativada neste iPhone."
        case "INVALID", "NOT_FOUND":
            return "Key inválida."
        default:
            return detail ?? "Licença não autorizada (\(code))."
        }
    }
}

enum DNVisualTheme {
    static let accent = Color.purple
}

struct DNLicenseActivationView: View {
    @ObservedObject var manager: DNLicenseManager
    @State private var key = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "key.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(DNVisualTheme.accent)
                Text("EXTERNAL IOS")
                    .font(.largeTitle.bold())
                Text("Keygen License")
                    .foregroundStyle(.secondary)
                SecureField("Digite sua key", text: $key)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await manager.activate(key: key) }
                } label: {
                    if manager.isLoading { ProgressView() } else { Text("Ativar") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isLoading)
                if !manager.message.isEmpty {
                    Text(manager.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(24)
        }
    }
}
