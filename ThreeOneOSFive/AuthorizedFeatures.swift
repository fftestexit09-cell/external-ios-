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

private struct ManagedFileItem: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let size: Int64
    let modifiedAt: Date?
    var id: URL { url }
}

struct FilesView: View {
    @State private var currentDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    @State private var items: [ManagedFileItem] = []
    @State private var searchText = ""
    @State private var showCreateFolder = false
    @State private var folderName = ""
    @State private var renameTarget: ManagedFileItem?
    @State private var renameText = ""
    @State private var moveTarget: ManagedFileItem?
    @State private var showMoveSheet = false
    @State private var errorMessage = ""

    private var rootDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var filteredItems: [ManagedFileItem] {
        let base = searchText.isEmpty ? items : items.filter { $0.url.lastPathComponent.localizedCaseInsensitiveContains(searchText) }
        return base.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory && !$1.isDirectory }
            return $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                VStack(spacing: 12) {
                    HStack {
                        if currentDirectory.standardizedFileURL != rootDirectory.standardizedFileURL {
                            Button {
                                goUp()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.headline)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Arquivos")
                                .font(.title2.bold())
                            Text(relativePath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()

                        Menu {
                            Button("Nova pasta", systemImage: "folder.badge.plus") {
                                folderName = ""
                                showCreateFolder = true
                            }
                            Button("Atualizar", systemImage: "arrow.clockwise") {
                                reload()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Buscar nesta pasta", text: $searchText)
                            .textInputAutocapitalization(.never)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if filteredItems.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            searchText.isEmpty ? "Pasta vazia" : "Nada encontrado",
                            systemImage: "folder",
                            description: Text(searchText.isEmpty ? "Crie uma pasta ou adicione arquivos ao Documents do app." : "Nenhum item corresponde à busca.")
                        )
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredItems) { item in
                                Button {
                                    if item.isDirectory {
                                        currentDirectory = item.url
                                        searchText = ""
                                        reload()
                                    }
                                } label: {
                                    FileManagerRow(item: item)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.clear)
                                .contextMenu {
                                    if item.isDirectory {
                                        Button("Abrir", systemImage: "folder") {
                                            currentDirectory = item.url
                                            searchText = ""
                                            reload()
                                        }
                                    }
                                    Button("Renomear", systemImage: "pencil") {
                                        renameTarget = item
                                        renameText = item.url.lastPathComponent
                                    }
                                    Button("Mover", systemImage: "folder") {
                                        moveTarget = item
                                        showMoveSheet = true
                                    }
                                    Button("Excluir", systemImage: "trash", role: .destructive) {
                                        delete(item)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        delete(item)
                                    } label: {
                                        Label("Excluir", systemImage: "trash")
                                    }

                                    Button {
                                        renameTarget = item
                                        renameText = item.url.lastPathComponent
                                    } label: {
                                        Label("Renomear", systemImage: "pencil")
                                    }
                                    .tint(.purple)
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.plain)
                    }
                }
                .padding()
            }
            .task { reload() }
            .alert("Nova pasta", isPresented: $showCreateFolder) {
                TextField("Nome da pasta", text: $folderName)
                Button("Cancelar", role: .cancel) {}
                Button("Criar") { createFolder() }
            }
            .alert("Renomear", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("Novo nome", text: $renameText)
                Button("Cancelar", role: .cancel) { renameTarget = nil }
                Button("Salvar") { renameSelected() }
            }
            .sheet(isPresented: $showMoveSheet) {
                MoveDestinationView(root: rootDirectory, current: currentDirectory) { destination in
                    moveSelected(to: destination)
                    showMoveSheet = false
                }
                .preferredColorScheme(.dark)
            }
            .alert("Erro", isPresented: Binding(
                get: { !errorMessage.isEmpty },
                set: { if !$0 { errorMessage = "" } }
            )) {
                Button("OK", role: .cancel) { errorMessage = "" }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var relativePath: String {
        let root = rootDirectory.standardizedFileURL.path
        let current = currentDirectory.standardizedFileURL.path
        guard current != root else { return "Documents" }
        let suffix = current.replacingOccurrences(of: root, with: "")
        return "Documents" + suffix
    }

    private func reload() {
        let fm = FileManager.default
        guard isInsideRoot(currentDirectory) else {
            currentDirectory = rootDirectory
            return reload()
        }
        let urls = (try? fm.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        items = urls.map { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            return ManagedFileItem(
                url: url,
                isDirectory: values?.isDirectory ?? false,
                size: Int64(values?.fileSize ?? 0),
                modifiedAt: values?.contentModificationDate
            )
        }
    }

    private func goUp() {
        let parent = currentDirectory.deletingLastPathComponent()
        guard isInsideRoot(parent) else { return }
        currentDirectory = parent
        searchText = ""
        reload()
    }

    private func createFolder() {
        let clean = sanitizedName(folderName)
        guard !clean.isEmpty else {
            errorMessage = "Digite um nome válido."
            return
        }
        let destination = currentDirectory.appendingPathComponent(clean, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func renameSelected() {
        guard let item = renameTarget else { return }
        defer { renameTarget = nil }
        let clean = sanitizedName(renameText)
        guard !clean.isEmpty else {
            errorMessage = "Digite um nome válido."
            return
        }
        let destination = item.url.deletingLastPathComponent().appendingPathComponent(clean, isDirectory: item.isDirectory)
        guard isInsideRoot(destination) else {
            errorMessage = "Destino inválido."
            return
        }
        do {
            try FileManager.default.moveItem(at: item.url, to: destination)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moveSelected(to destinationFolder: URL) {
        guard let item = moveTarget else { return }
        defer { moveTarget = nil }
        guard isInsideRoot(destinationFolder) else {
            errorMessage = "Destino inválido."
            return
        }
        if item.isDirectory {
            let itemPath = item.url.standardizedFileURL.path + "/"
            let destinationPath = destinationFolder.standardizedFileURL.path + "/"
            if destinationPath.hasPrefix(itemPath) {
                errorMessage = "Não é possível mover uma pasta para dentro dela mesma."
                return
            }
        }
        let destination = destinationFolder.appendingPathComponent(item.url.lastPathComponent, isDirectory: item.isDirectory)
        do {
            try FileManager.default.moveItem(at: item.url, to: destination)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ item: ManagedFileItem) {
        do {
            try FileManager.default.removeItem(at: item.url)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sanitizedName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }

    private func isInsideRoot(_ url: URL) -> Bool {
        let root = rootDirectory.standardizedFileURL.path
        let target = url.standardizedFileURL.path
        return target == root || target.hasPrefix(root + "/")
    }
}

private struct FileManagerRow: View {
    let item: ManagedFileItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isDirectory ? "folder.fill" : iconName)
                .font(.title3)
                .foregroundStyle(item.isDirectory ? .purple : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.url.lastPathComponent)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(item.isDirectory ? "Pasta" : ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                    if let date = item.modifiedAt {
                        Text(date, style: .date)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    private var iconName: String {
        switch item.url.pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "heic", "gif", "webp": return "photo.fill"
        case "pdf": return "doc.richtext.fill"
        case "zip": return "archivebox.fill"
        case "txt", "md", "json", "plist", "xml", "swift", "js", "html", "css": return "doc.text.fill"
        case "mp4", "mov": return "film.fill"
        case "mp3", "m4a", "wav": return "waveform"
        default: return "doc.fill"
        }
    }
}

private struct MoveDestinationView: View {
    let root: URL
    let current: URL
    let onChoose: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: URL
    @State private var folders: [URL] = []

    init(root: URL, current: URL, onChoose: @escaping (URL) -> Void) {
        self.root = root
        self.current = current
        self.onChoose = onChoose
        _selected = State(initialValue: root)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Destino") {
                    Button {
                        onChoose(selected)
                        dismiss()
                    } label: {
                        Label("Mover para \(displayPath(selected))", systemImage: "arrow.right.folder.fill")
                    }
                }

                if selected.standardizedFileURL != root.standardizedFileURL {
                    Button {
                        selected = selected.deletingLastPathComponent()
                        reload()
                    } label: {
                        Label("Voltar", systemImage: "chevron.left")
                    }
                }

                ForEach(folders, id: \.self) { folder in
                    Button {
                        selected = folder
                        reload()
                    } label: {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.purple)
                            Text(folder.lastPathComponent)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Mover item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .task { reload() }
        }
    }

    private func reload() {
        let fm = FileManager.default
        folders = ((try? fm.contentsOfDirectory(at: selected, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func displayPath(_ url: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let target = url.standardizedFileURL.path
        if target == rootPath { return "Documents" }
        return "Documents" + target.replacingOccurrences(of: rootPath, with: "")
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
