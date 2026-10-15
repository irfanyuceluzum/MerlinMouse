import SwiftUI
import AppKit
import MerlinCore

/// Uygulamaya özel profiller: solda uygulama listesi, sağda seçilen uygulamanın atamaları.
struct ProfilesPage: View {
    @ObservedObject private var store = BindingStore.shared
    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var front = FrontApp.shared
    /// nil = "Tüm uygulamalar".
    @State private var selection: String?
    @State private var adding = false
    @State private var removing = false

    /// Profil listesi ∪ kapsamlı ataması olan uygulamalar.
    private var apps: [AppChoice] {
        var seen = Set<String>()
        var out: [AppChoice] = []
        for p in store.profiles where seen.insert(p.bundleID).inserted {
            out.append(AppChoice(id: p.bundleID, name: p.name))
        }
        for b in store.bindings {
            if let id = b.appBundleID, seen.insert(id).inserted {
                out.append(AppChoice(id: id, name: b.appName ?? id))
            }
        }
        return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var selectedApp: AppChoice? { apps.first { $0.id == selection } }

    var body: some View {
        HStack(spacing: 0) {
            appColumn
            detail
        }
        .sheet(isPresented: $adding) {
            BindingEditorView(existing: nil, presetScope: selectedApp)
        }
    }

    // MARK: Uygulama sütunu

    private func letterColors(_ name: String) -> (Color, Color) {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        switch sum % 3 {
        case 0: return (MM.bttBg, MM.bttText)
        case 1: return (MM.warnBg, MM.warnText)
        default: return (MM.accentSoft, MM.accentText)
        }
    }

    private func appRow(title: String, selected: Bool, bg: Color, fg: Color, letter: String,
                        live: Bool, action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return Button(action: action) {
            HStack(spacing: 10) {
                Text(letter).font(.system(size: 13, weight: .semibold)).foregroundStyle(fg)
                    .frame(width: 28, height: 28)
                    .background(bg, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(title).font(.system(size: 13.5, weight: selected ? .medium : .regular))
                    .foregroundStyle(MM.text).lineLimit(1)
                Spacer(minLength: 0)
                if live { Circle().fill(MM.okDot).frame(width: 8, height: 8).accessibilityLabel(L("Şu an önde")) }
            }
            .padding(8).frame(minHeight: 44)
            .background(selected ? MM.accentSoft : Color.clear, in: shape)
            .overlay { if selected { shape.strokeBorder(MM.accent, lineWidth: 2) } }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var appColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            MMSectionLabel(L("Uygulamalar")).padding(.horizontal, 8).padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 4) {
                    appRow(title: L("Tüm uygulamalar"), selected: selection == nil, bg: MM.neuBg, fg: MM.text,
                           letter: "*", live: false) { selection = nil }
                    ForEach(apps) { app in
                        let c = letterColors(app.name)
                        appRow(title: app.name, selected: selection == app.id, bg: c.0, fg: c.1,
                               letter: String(app.name.prefix(1)).uppercased(),
                               live: front.bundleID == app.id) { selection = app.id }
                    }
                }
            }
            addMenu
        }
        .padding(.horizontal, 12).padding(.vertical, 20)
        .frame(width: 230).frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .trailing) { Rectangle().fill(MM.line).frame(width: 1) }
    }

    private var addMenu: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return Menu {
            ForEach(AppPicker.runningApps()) { app in
                Button(app.name) { add(app) }
            }
            Divider()
            Button(L("Diğer uygulama…")) {
                if let p = AppPicker.pickApp(), let id = p.bundleID { add(AppChoice(id: id, name: p.name)) }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                Text(L("Uygulama ekle")).font(.system(size: 13.5))
                Spacer(minLength: 0)
            }
            .foregroundStyle(MM.text)
            .padding(8).frame(minHeight: 44)
            .overlay(shape.strokeBorder(MM.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .contentShape(shape)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden)
        .padding(.top, 8)
    }

    // MARK: Ayrıntı

    private var detail: some View {
        let app = selectedApp
        return VStack(alignment: .leading, spacing: 16) {
            MMPageHeader(title: app?.name ?? L("Tüm uygulamalar"),
                         subtitle: app.map { LF("%@ öndeyken bu profil kendiliğinden devreye girer. Profili kaldırsan da atamalar kalır.", $0.name) }
                            ?? L("Genel atamalar, profili olmayan her uygulamada çalışır.")) {
                HStack(spacing: 10) {
                    if app != nil && store.profiles.contains(where: { $0.bundleID == selection }) {
                        MMSecondaryButton(L("Profili kaldır")) { removing = true }
                    }
                    MMPrimaryButton(app != nil ? L("Bu uygulama için hareket ekle") : L("Hareket ekle"), "plus") {
                        adding = true
                    }
                }
            }
            if apps.isEmpty && app == nil {
                MMBanner(kind: .info, title: L("Henüz uygulamaya özel profil yok"),
                         message: L("Bir uygulamada genel atamadan farklı davranmak için 'Uygulama ekle' ile başla; o uygulamadaki atamalar genel atamaların önüne geçer."))
            }
            MMSectionLabel(L("Atamalar"))
            BindingListView(scope: app?.id)
                .frame(maxHeight: .infinity)
            if app != nil { testArea }
        }
        .padding(.horizontal, 28).padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog(L("Profil kaldırılsın mı?"), isPresented: $removing) {
            Button(L("Profili kaldır"), role: .destructive) {
                if let id = selection {
                    store.removeProfile(bundleID: id)
                    if !store.bindings.contains(where: { $0.appBundleID == id }) { selection = nil }
                }
            }
            Button(L("Vazgeç"), role: .cancel) {}
        } message: {
            Text(L("Yalnız uygulama listeden çıkar; o uygulamadaki atamalar silinmez."))
        }
    }

    private var testArea: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return HStack(spacing: 20) {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 36, weight: .light)).foregroundStyle(MM.accentText)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Deneme alanı")).font(.system(size: 14, weight: .semibold)).foregroundStyle(MM.accentText)
                Text(L("Burada orta tuşla sürükle; gelen olay burada görünür."))
                    .font(.system(size: 13)).foregroundStyle(MM.accentText)
                Text(model.lastAction ?? L("Henüz yok"))
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(MM.text)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(MM.card, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(MM.accentLine, lineWidth: 1))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MM.accentSoft, in: shape)
        .overlay(shape.strokeBorder(MM.accentLine, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
    }

    private func add(_ app: AppChoice) {
        store.addProfile(ProfileApp(bundleID: app.id, name: app.name))
        selection = app.id
    }
}
