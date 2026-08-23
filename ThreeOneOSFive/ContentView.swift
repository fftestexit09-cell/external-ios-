import SwiftUI
import Security

struct ContentView: View {
    @StateObject private var dnLicense = DNLicenseManager()

    var body: some View {
        Group {
            if dnLicense.isLicensed {
                MainTabsView()
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

private struct MainTabsView: View {
    var body: some View {
        TabView {
            SafeHomeView()
                .tabItem { Label("Início", systemImage: "house.fill") }
            SafeFilesView()
                .tabItem { Label("Arquivos", systemImage: "folder.fill") }
            SafePatchesView()
                .tabItem { Label("Patches", systemImage: "shippingbox.fill") }
            SafeCleanerView()
                .tabItem { Label("Limpeza", systemImage: "sparkles") }
            SafeWallpapersView()
                .tabItem { Label("Papéis", systemImage: "photo.on.rectangle.angled") }
        }
    }
}

private struct SafeHomeView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("EXTERNAL IOS") {
                    Label("DN License ativo", systemImage: "checkmark.shield.fill")
                    Label("Modo seguro: somente dados do próprio app", systemImage: "lock.shield")
                }
                Section("Recursos") {
                    Label("Gerenciador de arquivos do sandbox do app", systemImage: "folder")
                    Label("Limpeza de cache e temporários do app", systemImage: "sparkles")
                    Label("Biblioteca de wallpapers para importar/exportar", systemImage: "photo")
                    Label("Patches apenas como catálogo/projetos locais, sem alterar outros apps", systemImage: "doc.badge.gearshape")
                }
            }
            .navigationTitle("EXTERNAL IOS")
        }
    }
}

private struct SafeFilesView: View {
    @State private var items: [URL] = []
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorText {
                    Text(errorText).foregroundStyle(.secondary)
                } else if items.isEmpty {
                    ContentUnavailableView("Sem arquivos", systemImage: "folder", description: Text("A pasta Documents do app está vazia."))
                } else {
                    ForEach(items, id: \.self) { url in
                        Label(url.lastPathComponent, systemImage: url.hasDirectoryPath ? "folder" : "doc")
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("Arquivos")
            .toolbar { Button { reload() } label: { Image(systemName: "arrow.clockwise") } }
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        do {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            items = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            try? FileManager.default.removeItem(at: items[index])
        }
        reload()
    }
}

private struct SafePatchesView: View {
    var body: some View {
        NavigationStack {
            List {
                ContentUnavailableView(
                    "Patches seguros",
                    systemImage: "shippingbox",
                    description: Text("Este build não inclui exploração, bypass, injeção ou alteração de outros aplicativos. Use esta área apenas para projetos e metadados locais do próprio app.")
                )
            }
            .navigationTitle("Patches")
        }
    }
}

private struct SafeCleanerView: View {
    @State private var status = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Limpeza segura") {
                    Button("Limpar Caches") { clear(.cachesDirectory) }
                    Button("Limpar Temporários") { clearTemporary() }
                }
                if !status.isEmpty { Text(status).foregroundStyle(.secondary) }
            }
            .navigationTitle("Limpeza")
        }
    }

    private func clear(_ directory: FileManager.SearchPathDirectory) {
        guard let url = FileManager.default.urls(for: directory, in: .userDomainMask).first else { return }
        clearContents(of: url)
    }

    private func clearTemporary() {
        clearContents(of: FileManager.default.temporaryDirectory)
    }

    private func clearContents(of url: URL) {
        do {
            for item in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                try? FileManager.default.removeItem(at: item)
            }
            status = "Limpeza concluída."
        } catch {
            status = error.localizedDescription
        }
    }
}

private struct SafeWallpapersView: View {
    var body: some View {
        NavigationStack {
            List {
                ContentUnavailableView(
                    "Wallpapers",
                    systemImage: "photo.on.rectangle",
                    description: Text("Importe imagens para Documents/Wallpapers e compartilhe/exporte pelo iOS. O app não altera o wallpaper do sistema diretamente.")
                )
            }
            .navigationTitle("Papéis")
        }
    }
}
