import SwiftUI
import AppKit
import MerlinCore

/// Hazır uygulama profili: eklenecek atamalar, notlar, kaynaklar ve uygulama seçimi.
struct PresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preset: AppPreset
    /// Uygulandıktan sonra profil sayfasında seçilecek paket kimliği.
    var onApplied: (String) -> Void

    @State private var app: PickedApp?
    /// Uygulama kendiliğinden bulundu mu (kullanıcı seçtiyse false)?
    @State private var found = false
    @State private var searched = false
    @State private var result: (added: Int, skipped: Int)?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LF("%@ hazır profili", preset.name))
                            .font(.system(size: 18, weight: .semibold)).foregroundStyle(MM.text)
                        Text(L("Atamalar yalnız bu uygulamada geçerli olur. Var olan atamaların değişmez; aynı hareket zaten atanmışsa atlanır."))
                            .font(.system(size: 13)).foregroundStyle(MM.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    appCard
                    bindingsCard
                    notesCard
                    sourcesCard
                }
                .padding(.horizontal, 24).padding(.vertical, 20)
            }
            footer
        }
        .frame(width: 600, height: 640)
        .background(MM.card)
        .onAppear {
            guard !searched else { return }
            searched = true
            if let a = Self.locate(preset) {
                app = a
                found = true
            }
        }
    }

    // MARK: Uygulama

    private var appCard: some View {
        MMCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                MMSectionLabel(L("Uygulama"))
                if let app {
                    HStack(spacing: 8) {
                        Image(systemName: found ? "checkmark.circle.fill" : "app")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(MM.accentText)
                        Text(found ? LF("Bulundu: %@", app.name) : LF("Seçildi: %@", app.name))
                            .font(.system(size: 13.5, weight: .medium)).foregroundStyle(MM.text)
                        Spacer(minLength: 0)
                        MMSecondaryButton(L("Başka uygulama seç…")) { pick() }
                    }
                    Text(verbatim: app.path).font(.system(size: 11.5)).foregroundStyle(MM.text2).lineLimit(1)
                    if app.bundleID == nil {
                        MMBanner(kind: .warning, title: L("Uygulamanın paket kimliği okunamadı"),
                                 message: L("Kimliği olmayan uygulamaya profil uygulanamaz; başka bir uygulama seç."))
                    } else if !AppPresets.matches(preset, bundleID: app.bundleID, name: app.name) {
                        MMBanner(kind: .warning,
                                 title: LF("Seçilen uygulama %@ gibi görünmüyor; yine de uygulanabilir.", preset.name))
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "questionmark.app").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(MM.warnText)
                        Text(L("Uygulama bulunamadı")).font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(MM.text)
                        Spacer(minLength: 0)
                        MMPrimaryButton(L("Uygulamayı seç…")) { pick() }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func pick() {
        guard let p = AppPicker.pickApp() else { return }
        app = p
        found = false
        result = nil
    }

    /// Önce bilinen kimlikler, sonra /Applications ve ~/Applications (yalnız ilk düzey) içinde adı eşleşen paket.
    static func locate(_ preset: AppPreset) -> PickedApp? {
        for id in preset.bundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                return AppPicker.app(at: url)
            }
        }
        let needle = preset.nameMatch.lowercased()
        guard !needle.isEmpty else { return nil }
        let fm = FileManager.default
        let dirs = [URL(fileURLWithPath: "/Applications"),
                    fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)]
        for dir in dirs {
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles]) else { continue }
            let hit = items
                .filter { $0.pathExtension == "app" && $0.deletingPathExtension().lastPathComponent.lowercased().contains(needle) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .first
            if let hit { return AppPicker.app(at: hit) }
        }
        return nil
    }

    // MARK: İçerik

    private var bindingsCard: some View {
        MMCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                MMSectionLabel(L("Eklenecek atamalar"))
                ForEach(Array(preset.bindings.enumerated()), id: \.offset) { _, b in
                    HStack(spacing: 8) {
                        Text(b.trigger.title).font(.system(size: 13.5, weight: .medium)).foregroundStyle(MM.text)
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(MM.text2)
                        Text(b.action.title).font(.system(size: 13.5)).foregroundStyle(MM.text)
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var notesCard: some View {
        MMCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                MMSectionLabel(L("Notlar"))
                ForEach(Array(preset.notes.enumerated()), id: \.offset) { _, note in
                    HStack(alignment: .top, spacing: 8) {
                        Text(verbatim: "•").foregroundStyle(MM.text2)
                        Text(note).font(.system(size: 13)).foregroundStyle(MM.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var sourcesCard: some View {
        MMCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                MMSectionLabel(L("Kaynaklar"))
                ForEach(preset.sources, id: \.self) { s in
                    if let url = URL(string: s) {
                        Link(destination: url) {
                            Text(verbatim: s).font(.system(size: 12.5)).foregroundStyle(MM.accentText)
                                .lineLimit(1).truncationMode(.middle)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Alt çubuk

    private var canApply: Bool { app?.bundleID != nil && result == nil }

    private var footer: some View {
        HStack(spacing: 10) {
            if let result {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(MM.accentText)
                Text(LF("%lld atama eklendi, %lld atama zaten vardı", result.added, result.skipped))
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(MM.text)
            } else if app != nil, app?.bundleID == nil {
                Text(L("Paket kimliği okunamadığı için uygulanamaz."))
                    .font(.system(size: 12.5)).foregroundStyle(MM.warnText)
            }
            Spacer()
            if result != nil {
                MMPrimaryButton(L("Tamam")) { dismiss() }.keyboardShortcut(.defaultAction)
            } else {
                MMSecondaryButton(L("Vazgeç")) { dismiss() }.keyboardShortcut(.cancelAction)
                MMPrimaryButton(L("Profili uygula")) { apply() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canApply).opacity(canApply ? 1 : 0.4)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 14)
        .background(MM.card2)
        .overlay(alignment: .top) { Rectangle().fill(MM.line).frame(height: 1) }
    }

    private func apply() {
        guard let app, let id = app.bundleID, result == nil else { return }
        let r = BindingStore.shared.applyPreset(preset, bundleID: id, appName: app.name)
        Log.write("Hazır profil uygulandı: \(preset.id) → \(id) · eklenen \(r.added), atlanan \(r.skipped)")
        result = r
        onApplied(id)
    }
}
