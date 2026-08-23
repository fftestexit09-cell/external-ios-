import SwiftUI
import UIKit

struct AuthorizedMainView: View {
    @State private var selection = 0
    var body: some View {
        TabView(selection: $selection) {
            HomeView().tabItem { Label("Início", systemImage: "house.fill") }.tag(0)
            FilesView().tabItem { Label("Arquivos", systemImage: "folder.fill") }.tag(1)
            PatchesView().tabItem { Label("Patches", systemImage: "square.stack.3d.up.fill") }.tag(2)
            CleanerView().tabItem { Label("Limpeza", systemImage: "sparkles") }.tag(3)
            WallpapersView().tabItem { Label("Papéis", systemImage: "photo.on.rectangle") }.tag(4)
        }
        .tint(.purple)
        .preferredColorScheme(.dark)
    }
}

private struct PremiumBackground: View {
    var body: some View {
        LinearGradient(colors: [.black, Color(red: 0.10, green: 0.04, blue: 0.16), .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
    }
}

private struct PremiumCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { content.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(.purple.opacity(0.25))) }
}

struct HomeView: View {
    var body: some View {
        NavigationStack { ZStack { PremiumBackground(); ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text("EXTERNAL IOS").font(.largeTitle.bold())
            Text("Central de recursos").foregroundStyle(.secondary)
            PremiumCard { Label("Licença ativa", systemImage: "checkmark.shield.fill").foregroundStyle(.green) }
            Text("Recursos").font(.title2.bold())
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                FeatureTile(title: "Arquivos", icon: "folder.fill")
                FeatureTile(title: "Patches", icon: "square.stack.3d.up.fill")
                FeatureTile(title: "Limpeza", icon: "sparkles")
                FeatureTile(title: "Papéis de parede", icon: "photo.fill")
            }
        }.padding() } } }
    }
}

private struct FeatureTile: View { let title: String; let icon: String; var body: some View { PremiumCard { VStack(alignment: .leading, spacing: 14) { Image(systemName: icon).font(.title).foregroundStyle(.purple); Text(title).font(.headline) } } } }

struct FilesView: View {
    @State private var files: [URL] = []
    var body: some View { NavigationStack { ZStack { PremiumBackground(); Group { if files.isEmpty { ContentUnavailableView("Nenhum arquivo", systemImage: "folder", description: Text("Os arquivos do aplicativo aparecerão aqui.")) } else { List { ForEach(files, id: \.self) { url in HStack { Image(systemName: "doc.fill").foregroundStyle(.purple); VStack(alignment: .leading) { Text(url.lastPathComponent); Text(fileSize(url)).font(.caption).foregroundStyle(.secondary) } } }.onDelete(perform: delete) }.scrollContentBackground(.hidden) } }.padding(.horizontal) }.navigationTitle("Arquivos").task { reload() } }
    }
    private func reload() { let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!; files = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])) ?? [] }
    private func delete(at offsets: IndexSet) { for i in offsets { try? FileManager.default.removeItem(at: files[i]) }; reload() }
    private func fileSize(_ url: URL) -> String { let n = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0; return ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .file) }
}

struct PatchesView: View {
    var body: some View { NavigationStack { ZStack { PremiumBackground(); VStack(spacing: 16) { PremiumCard { Label("Catálogo conectado à licença", systemImage: "shield.lefthalf.filled").foregroundStyle(.purple); Text("Nenhum patch autorizado disponível no momento.").foregroundStyle(.secondary).padding(.top, 8) }; Spacer() }.padding() }.navigationTitle("Patches") } }
}

struct CleanerView: View {
    @State private var cacheSize: Int64 = 0
    @State private var result = ""
    var body: some View { NavigationStack { ZStack { PremiumBackground(); VStack(spacing: 16) { PremiumCard { Text("Dados temporários").font(.headline); Text(ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)).font(.system(size: 34, weight: .bold)).foregroundStyle(.purple).padding(.vertical, 4); Text("Somente dados gerenciados pelo próprio aplicativo.").foregroundStyle(.secondary) }; Button("Limpar cache") { clean() }.buttonStyle(.borderedProminent).tint(.purple); if !result.isEmpty { Text(result).foregroundStyle(.secondary) }; Spacer() }.padding() }.navigationTitle("Limpeza").task { calculate() } } }
    private func calculate() { let u = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!; cacheSize = directorySize(u) }
    private func clean() { let fm = FileManager.default; let u = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!; for x in (try? fm.contentsOfDirectory(at: u, includingPropertiesForKeys: nil)) ?? [] { try? fm.removeItem(at: x) }; calculate(); result = "Limpeza concluída." }
    private func directorySize(_ u: URL) -> Int64 { let fm = FileManager.default; let e = fm.enumerator(at: u, includingPropertiesForKeys: [.fileSizeKey]); var total:Int64 = 0; while let x = e?.nextObject() as? URL { total += Int64((try? x.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }; return total }
}

struct WallpapersView: View {
    private let gradients: [[Color]] = [[.purple,.black],[.indigo,.black],[.purple,.indigo],[.black,.purple],[.pink,.purple],[.blue,.purple]]
    var body: some View { NavigationStack { ZStack { PremiumBackground(); ScrollView { LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible())], spacing: 14) { ForEach(gradients.indices, id: \.self) { i in LinearGradient(colors: gradients[i], startPoint: .topLeading, endPoint: .bottomTrailing).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08))) } }.padding() } }.navigationTitle("Papéis de parede") } }
}
