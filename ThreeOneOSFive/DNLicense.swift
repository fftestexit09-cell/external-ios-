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
    private func friendlyMessage(for code: String, detail: String?) -> String { switch code.uppercased() { case "VALID": return "Licença válida."; case "NO_MACHINE", "NO_MACHINES": return "Key válida, mas ainda não ativada neste iPhone."; case "FINGERPRINT_SCOPE_MISMATCH": return "Key válida, porém vinculada a outro dispositivo."; case "POLICY_SCOPE_MISMATCH": return "Esta key pertence a outra policy."; case "POLICY_SCOPE_REQUIRED": return "O Keygen exige o escopo da policy."; case "FINGERPRINT_SCOPE_REQUIRED": return "O Keygen exige o fingerprint do dispositivo."; case "EXPIRED": return "Esta key expirou."; case "SUSPENDED": return "Esta key foi suspensa."; case "TOO_MANY_MACHINES": return "Esta key atingiu o limite de dispositivos."; case "INVALID", "NOT_FOUND": return "Key inválida ou expirada."; default: return detail ?? "Licença não autorizada (\(code))." } }
}

enum DNVisualTheme {
    static let accent = Color.purple
    static let bg = LinearGradient(colors: [.black, Color.purple.opacity(0.12), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
}

private struct ActivationCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08)))
    }
}

struct DNLicenseActivationView: View {
    @ObservedObject var manager: DNLicenseManager
    @State private var key = ""

    var body: some View {
        ZStack {
            DNVisualTheme.bg.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.18))
                        .frame(width: 82, height: 82)
                        .overlay(Circle().stroke(Color.purple.opacity(0.65), lineWidth: 1))
                    Image(systemName: "key.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                }

                Text("Ativar Licença")
                    .font(.title.bold())

                Text("Digite sua key para ativar o DN External iOS")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SecureField("Cole sua key aqui", text: $key)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color.purple.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.35)))

                Button {
                    Task { await manager.activate(key: key) }
                } label: {
                    HStack {
                        Spacer()
                        if manager.isLoading {
                            ProgressView()
                        } else {
                            Text("ATIVAR LICENÇA")
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isLoading)

                ActivationCard {
                    Text("Informações")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 10) {
                        Label("A key é vinculada ao seu dispositivo", systemImage: "checkmark.circle")
                        Label("Uso exclusivo e pessoal", systemImage: "person.crop.circle")
                        Label("Não compartilhe sua key", systemImage: "lock.fill")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                }

                if manager.isLoading {
                    VStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(1.15)
                            .tint(.purple)
                        Text("Validando sua key, aguarde.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !manager.message.isEmpty && !manager.isLoading {
                    VStack(spacing: 8) {
                        Image(systemName: manager.isLicensed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(manager.isLicensed ? .green : .red)
                        Text(manager.isLicensed ? "Licença Ativada!" : "Erro na Ativação")
                            .font(.headline)
                        Text(manager.message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }
}
