import Foundation
import SwiftUI
import Security

private enum DNKeychain {
    static let service = "com.externalios.keygen"

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}

private struct KeygenValidationResult { let valid: Bool; let code: String; let detail: String?; let licenseID: String? }

@MainActor
final class DNLicenseManager: ObservableObject {
    @Published var isLicensed = false
    @Published var message = ""
    @Published var isLoading = false
    @Published var debugStatus = "READY"

    private let account = "renatokaua07"
    private let policyID = "ba96ef96-7a3c-49df-8747-a22b76248d25"
    private let apiRoot = URL(string: "https://api.keygen.sh/v1")!

    private var installationID: String {
        if let existing = DNKeychain.read("installation_id"), !existing.isEmpty { return existing }
        let value = UUID().uuidString.lowercased(); DNKeychain.write(value, account: "installation_id"); return value
    }

    func validateSavedLicense() async { guard let key = DNKeychain.read("license_key"), !key.isEmpty else { return }; await validateOrActivate(key: key, allowActivation: false) }
    func activate(key: String) async { let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines); guard !normalized.isEmpty else { message = "Digite uma key válida."; return }; await validateOrActivate(key: normalized, allowActivation: true); if isLicensed { DNKeychain.write(normalized, account: "license_key") } }

    private func validateOrActivate(key: String, allowActivation: Bool) async {
        isLoading = true; isLicensed = false; debugStatus = "VALIDATING"; defer { isLoading = false }
        do {
            let first = try await validateKey(key); let code = first.code.uppercased(); debugStatus = "KEYGEN: \(code)"
            if first.valid { isLicensed = true; message = "Licença válida."; return }
            if allowActivation && ["NO_MACHINE", "NO_MACHINES", "FINGERPRINT_SCOPE_MISMATCH"].contains(code) {
                guard let licenseID = first.licenseID, !licenseID.isEmpty else { message = first.detail ?? "Key encontrada, mas a API não retornou o ID da licença."; return }
                try await activateMachine(key: key, licenseID: licenseID)
                let second = try await validateKey(key); debugStatus = "KEYGEN: \(second.code.uppercased())"; isLicensed = second.valid; message = second.valid ? "Licença ativada neste iPhone." : friendlyMessage(for: second.code, detail: second.detail); return
            }
            message = friendlyMessage(for: first.code, detail: first.detail)
        } catch let error as NSError { debugStatus = "ERROR: \(error.code)"; message = error.localizedDescription }
    }

    private func validateKey(_ key: String) async throws -> KeygenValidationResult {
        let url = apiRoot.appendingPathComponent("accounts").appendingPathComponent(account).appendingPathComponent("licenses/actions/validate-key")
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 20
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Content-Type"); request.setValue("application/vnd.api+json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["meta": ["key": key, "scope": ["fingerprint": installationID, "policy": policyID]]])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NSError(domain: "Keygen", code: -1, userInfo: [NSLocalizedDescriptionKey: "Resposta HTTP inválida do Keygen."]) }
        guard (200..<300).contains(http.statusCode) else { let detail = parseAPIError(data) ?? String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"; throw NSError(domain: "KeygenHTTP", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Keygen HTTP \(http.statusCode): \(detail)"]) }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw NSError(domain: "Keygen", code: -2, userInfo: [NSLocalizedDescriptionKey: "Não foi possível interpretar a resposta do Keygen."]) }
        let meta = object["meta"] as? [String: Any]; let valid = meta?["valid"] as? Bool ?? false; let code = (meta?["code"] as? String) ?? (valid ? "VALID" : "INVALID"); let detail = meta?["detail"] as? String; let licenseID = (object["data"] as? [String: Any])?["id"] as? String
        return KeygenValidationResult(valid: valid, code: code, detail: detail, licenseID: licenseID)
    }

    private func activateMachine(key: String, licenseID: String) async throws {
        let url = apiRoot.appendingPathComponent("accounts").appendingPathComponent(account).appendingPathComponent("machines")
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 20
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Content-Type"); request.setValue("application/vnd.api+json", forHTTPHeaderField: "Accept"); request.setValue("License \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["data": ["type": "machines", "attributes": ["fingerprint": installationID, "platform": "iOS", "name": "EXTERNAL IOS iPhone"], "relationships": ["license": ["data": ["type": "licenses", "id": licenseID]]]]])
        let (data, response) = try await URLSession.shared.data(for: request); guard let http = response as? HTTPURLResponse else { throw NSError(domain: "Keygen", code: -3, userInfo: [NSLocalizedDescriptionKey: "Resposta inválida ao ativar dispositivo."]) }
        guard (200..<300).contains(http.statusCode) else { let detail = parseAPIError(data) ?? String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"; throw NSError(domain: "KeygenActivation", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ativação HTTP \(http.statusCode): \(detail)"]) }
    }

    private func parseAPIError(_ data: Data) -> String? { guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let errors = object["errors"] as? [[String: Any]], let first = errors.first else { return nil }; return (first["detail"] as? String) ?? (first["title"] as? String) ?? (first["code"] as? String) }
    private func friendlyMessage(for code: String, detail: String?) -> String { switch code.uppercased() { case "VALID": return "Licença válida."; case "NO_MACHINE", "NO_MACHINES": return "Key válida, mas ainda não ativada neste iPhone."; case "FINGERPRINT_SCOPE_MISMATCH": return "Key válida, porém vinculada a outro dispositivo."; case "POLICY_SCOPE_MISMATCH": return "Esta key pertence a outra policy."; case "POLICY_SCOPE_REQUIRED": return "O Keygen exige o escopo da policy."; case "FINGERPRINT_SCOPE_REQUIRED": return "O Keygen exige o fingerprint do dispositivo."; case "EXPIRED": return "Esta key expirou."; case "SUSPENDED": return "Esta key foi suspensa."; case "TOO_MANY_MACHINES": return "Esta key atingiu o limite de dispositivos."; case "INVALID", "NOT_FOUND": return "Key inválida."; default: return detail ?? "Licença não autorizada (\(code))." } }
}

enum DNVisualTheme { static let accent = Color.purple }
struct DNLicenseActivationView: View {
    @ObservedObject var manager: DNLicenseManager; @State private var key = ""
    var body: some View { NavigationStack { VStack(spacing: 18) { Spacer(); Image(systemName: "key.fill").font(.system(size: 50)).foregroundStyle(DNVisualTheme.accent); Text("EXTERNAL IOS").font(.largeTitle.bold()); Text("KEYGEN BUILD 5").font(.headline.bold()).foregroundStyle(.purple); Text("Account renatokaua07 • Policy ...48d25").font(.caption2).foregroundStyle(.secondary); SecureField("Digite sua key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder); Button { Task { await manager.activate(key: key) } } label: { if manager.isLoading { ProgressView() } else { Text("Ativar") } }.buttonStyle(.borderedProminent).disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isLoading); Text(manager.debugStatus).font(.caption.monospaced()).foregroundStyle(.secondary); if !manager.message.isEmpty { Text(manager.message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).textSelection(.enabled) }; Spacer() }.padding(24) } }
}
