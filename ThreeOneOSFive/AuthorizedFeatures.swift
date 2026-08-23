import SwiftUI
import UIKit

struct AuthorizedMainView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Início", systemImage: "house.fill") }
                .tag(0)

            FilesView()
                .tabItem { Label("Arquivos", systemImage: "folder.fill") }
                .tag(1)

            ProfilesView()
                .tabItem { Label("Perfis", systemImage: "sparkles.rectangle.stack.fill") }
                .tag(2)

            CleanerView()
                .tabItem { Label("Limpeza", systemImage: "trash.fill") }
                .tag(3)

            WallpapersView()
                .tabItem { Label("Papéis", systemImage: "photo.on.rectangle") }
                .tag(4)
        }
        .tint(.purple)
        .preferredColorScheme(.dark)
    }
}

private struct PremiumBackground: View {
    var body: some View {
        ZStack {
            Color.black
            LinearGradient(
                colors: [Color.black, Color.purple.opacity(0.12), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

private struct PremiumCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.purple)
            Text(title)
                .font(.title2.bold())
            Spacer()
        }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Início")
                                    .font(.largeTitle.bold())
                                Text("DN External iOS")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "bell")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        PremiumCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("DN External iOS")
                                        .font(.title3.bold())
                                    Text("Bem-vindo(a)!")
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 34))
                                    .foregroundStyle(.purple)
                            }
                        }

                        PremiumCard {
                            Text("Status da Licença")
                                .font(.headline)
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                                Text("ATIVA")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                            }
                            .padding(.top, 6)
                            Text("Licença validada neste dispositivo.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 6)
                        }

                        Text("Acesso Rápido")
                            .font(.headline)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            QuickTile(title: "Arquivos", icon: "folder.fill")
                            QuickTile(title: "Perfis", icon: "sparkles.rectangle.stack.fill")
                            QuickTile(title: "Limpeza", icon: "trash.fill")
                            QuickTile(title: "Papéis", icon: "photo.fill")
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

private struct QuickTile: View {
    let title: String
    let icon: String

    var body: some View {
        PremiumCard {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.purple)
                Text(title)
                    .font(.headline)
            }
        }
    }
}

struct FilesView: View {
    @State private var files: [URL] = []
    @State private var searchText = ""

    private var filteredFiles: [URL] {
        guard !searchText.isEmpty else { return files }
        return files.filter { $0.lastPathComponent.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                VStack(spacing: 14) {
                    SectionHeader(title: "Arquivos", icon: "folder.fill")

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Buscar arquivos", text: $searchText)
                            .textInputAutocapitalization(.never)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if filteredFiles.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            "Nenhum arquivo",
                            systemImage: "folder",
                            description: Text("Os arquivos do próprio aplicativo aparecerão aqui.")
                        )
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredFiles, id: \.self) { url in
                                HStack(spacing: 12) {
                                    Image(systemName: "doc.fill")
                                        .foregroundStyle(.purple)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(url.lastPathComponent)
                                        Text(fileSize(url))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .listRowBackground(Color.clear)
                            }
                            .onDelete(perform: delete)
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
                .padding()
            }
            .task { reload() }
        }
    }

    private func reload() {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        files = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let url = filteredFiles[index]
            try? FileManager.default.removeItem(at: url)
        }
        reload()
    }

    private func fileSize(_ url: URL) -> String {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

struct ProfilesView: View {
    private let profiles = [
        ("Modo Foco", "Reduz distrações visuais dentro do app", "moon.stars.fill"),
        ("Interface Compacta", "Ajusta a densidade dos elementos do próprio app", "rectangle.compress.vertical"),
        ("Modo Leitura", "Prioriza contraste e legibilidade", "textformat.size"),
        ("Perfil Padrão", "Configuração equilibrada para uso diário", "slider.horizontal.3")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "Perfis", icon: "sparkles.rectangle.stack.fill")

                        ForEach(Array(profiles.enumerated()), id: \.offset) { _, item in
                            PremiumCard {
                                HStack(spacing: 12) {
                                    Image(systemName: item.2)
                                        .font(.title3)
                                        .foregroundStyle(.purple)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.0)
                                            .font(.headline)
                                        Text(item.1)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("DISPONÍVEL")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.green)
                                }
                            }
                        }

                        Text("Os perfis acima alteram somente a experiência dentro deste aplicativo.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .padding()
                }
            }
        }
    }
}

struct CleanerView: View {
    @State private var cacheSize: Int64 = 0
    @State private var tempSize: Int64 = 0
    @State private var result = ""

    var totalSize: Int64 { cacheSize + tempSize }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Limpeza", icon: "trash.fill")

                        PremiumCard {
                            Text("Espaço Utilizado")
                                .font(.headline)
                            Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                                .font(.system(size: 38, weight: .bold))
                                .padding(.vertical, 4)
                            Text("Dados temporários do próprio aplicativo")
                                .foregroundStyle(.secondary)
                        }

                        PremiumCard {
                            VStack(spacing: 12) {
                                CleanerRow(title: "Cache", bytes: cacheSize)
                                Divider().overlay(Color.white.opacity(0.08))
                                CleanerRow(title: "Arquivos Temporários", bytes: tempSize)
                            }
                        }

                        Button {
                            clean()
                        } label: {
                            Text("LIMPAR \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file).uppercased())")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)

                        if !result.isEmpty {
                            Text(result)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
            }
            .task { calculate() }
        }
    }

    private func calculate() {
        let fm = FileManager.default
        let cacheURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheSize = directorySize(cacheURL)
        tempSize = directorySize(fm.temporaryDirectory)
    }

    private func clean() {
        let fm = FileManager.default
        let cacheURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!

        for item in (try? fm.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.removeItem(at: item)
        }

        for item in (try? fm.contentsOfDirectory(at: fm.temporaryDirectory, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.removeItem(at: item)
        }

        calculate()
        result = "Limpeza concluída."
    }

    private func directorySize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        var total: Int64 = 0
        while let item = enumerator?.nextObject() as? URL {
            total += Int64((try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}

private struct CleanerRow: View {
    let title: String
    let bytes: Int64

    var body: some View {
        HStack {
            Image(systemName: "checkmark.square.fill")
                .foregroundStyle(.purple)
            Text(title)
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                .foregroundStyle(.secondary)
        }
    }
}

struct WallpapersView: View {
    private let gradients: [[Color]] = [
        [.purple, .black],
        [.blue, .pink],
        [.indigo, .black],
        [.pink, .purple],
        [.cyan, .purple],
        [.orange, .purple],
        [.blue, .black],
        [.purple, .indigo],
        [.pink, .black]
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "Papéis de Parede", icon: "square.grid.2x2.fill")

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(gradients.indices, id: \.self) { index in
                                LinearGradient(
                                    colors: gradients[index],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.08))
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}
