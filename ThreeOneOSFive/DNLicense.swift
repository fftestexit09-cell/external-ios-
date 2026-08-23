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
        SecItemAdd(add as CFDictionary, nil)
    }
}

@MainActor
final class DNLicenseManager: ObservableObject {
    @Published var isLicensed = false
    @Published var message = ""
    @Published var isLoading = false

    private var baseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "DN_LICENSE_API_URL") as? String,
              let url = URL(string: raw), url.scheme == "https" else { return nil }
        return url
    }

    private var installationID: String {
        if let existing = DNKeychain.read("installation_id") { return existing }
        let value = UUID().uuidString
        DNKeychain.write(value, account: "installation_id")
        return value
    }

    func validateSavedLicense() async {
        guard let key = DNKeychain.read("license_key") else { return }
        await validate(key: key, endpoint: "validate")
    }

    func activate(key: String) async {
        await validate(key: key, endpoint: "activate")
        if isLicensed { DNKeychain.write(key, account: "license_key") }
    }

    private func validate(key: String, endpoint: String) async {
        guard let baseURL else {
            message = "Configure DN_LICENSE_API_URL com uma URL HTTPS válida."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/license/\(endpoint)"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "key": key,
                "installation_id": installationID,
                "product": "external-ios"
            ])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                isLicensed = false
                message = "Licença não autorizada."
                return
            }
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let status = (object?["status"] as? String)?.uppercased() ?? "INVALID"
            isLicensed = status == "VALID"
            message = isLicensed ? "Licença válida." : "Status: \(status)"
        } catch {
            isLicensed = false
            message = "Falha de comunicação com o servidor."
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
                Text("DN License")
                    .foregroundStyle(.secondary)
                SecureField("Digite sua key", text: $key)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await manager.activate(key: key.trimmingCharacters(in: .whitespacesAndNewlines)) }
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
