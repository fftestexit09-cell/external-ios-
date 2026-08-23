import SwiftUI

struct ContentView: View {
    @StateObject private var dnLicense = DNLicenseManager()

    var body: some View {
        Group {
            if dnLicense.isLicensed {
                AuthorizedMainView()
            } else {
                DNLicenseActivationView(manager: dnLicense)
            }
        }
        .task {
            if !dnLicense.isLicensed {
                await dnLicense.validateSavedLicense()
            }
        }
        .tint(DNVisualTheme.accent)
        .preferredColorScheme(.dark)
    }
}
