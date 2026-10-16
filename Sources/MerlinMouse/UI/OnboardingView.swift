import SwiftUI
import MerlinCore

/// İlk açılış rehberi: izin → fareyi tanı → ilk hareket.
struct OnboardingView: View {
    var onClose: () -> Void

    @ObservedObject private var model = AppModel.shared
    @ObservedObject private var s = Settings.shared
    @State private var flow = OnboardingFlow()
    @State private var touchSeen = false
    /// 3. adıma girildiğinde günlüğün en yeni kaydı; sonrasında gelen orta tuş eylemi aranır.
    @State private var baselineEntry: UUID?
    @State private var twoButton = false

    private var middleSeen: Bool {
        guard let e = model.eventLog.entries.first, !e.dryRun, e.id != baselineEntry else { return false }
        return e.text.hasPrefix(L("Orta tıklama")) || e.text.hasPrefix(L("Orta tuş sürükleme"))
    }

    private var shownStep: OnboardingStep { flow.step == .done ? .firstGesture : flow.step }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text(L("Merlin Mouse'a hoş geldin")).font(.system(size: 24, weight: .semibold)).foregroundStyle(MM.text)
                indicator
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 32).padding(.top, 28).padding(.bottom, 16)
            MMDivider()
            footer.padding(.horizontal, 32).padding(.vertical, 16)
        }
        .frame(width: 640, height: 520)
        .background(MM.win)
        .onAppear {
            twoButton = AppModel.shared.conflictEnvironment().mouseButtonMode == "TwoButton"
            evaluate()
        }
        .onChange(of: model.trusted) { _, _ in evaluate() }
        .onChange(of: model.miceCount) { _, _ in evaluate() }
        .onChange(of: model.liveTouches) { _, touches in
            if !touches.isEmpty { touchSeen = true }
            evaluate()
        }
        .onChange(of: model.eventLog) { _, _ in evaluate() }
        .onChange(of: flow.step) { _, step in
            if step == .firstGesture { baselineEntry = model.eventLog.entries.first?.id }
        }
    }

    private func evaluate() {
        flow.update(trusted: model.trusted, miceCount: model.miceCount, touchSeen: touchSeen,
                    middleActionSeen: flow.step == .firstGesture && middleSeen)
    }

    private func finish() {
        s.onboardingCompleted = true
        onClose()
    }

    // MARK: Adım göstergesi

    private var indicator: some View {
        let titles = [L("İzin ver"), L("Fareyi tanı"), L("İlk hareketi dene")]
        return HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                let current = i == shownStep.rawValue && flow.step != .done
                let complete = i < flow.step.rawValue
                HStack(spacing: 7) {
                    ZStack {
                        Circle().fill(complete || current ? MM.accent : MM.neuBg).frame(width: 22, height: 22)
                        if complete {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(MM.accentInk)
                        } else {
                            Text("\(i + 1)").font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(current ? MM.accentInk : MM.neuText)
                        }
                    }
                    Text(titles[i]).font(.system(size: 13, weight: current ? .semibold : .regular))
                        .foregroundStyle(current ? MM.text : MM.text2)
                }
                if i < 2 { Rectangle().fill(MM.line).frame(height: 1).frame(maxWidth: 28) }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: İçerik

    @ViewBuilder private var content: some View {
        switch shownStep {
        case .permission: permissionStep
        case .recognizeMouse: recognizeStep
        default: gestureStep
        }
    }

    private var permissionStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("Merlin Mouse'un tıklamaları orta tuşa çevirebilmesi için Erişilebilirlik izni gerekir. İzni Sistem Ayarları'nda ver; verilince bu rehber kendiliğinden ilerler."))
                .font(.system(size: 13.5)).foregroundStyle(MM.text2).fixedSize(horizontal: false, vertical: true)
            status(ok: model.trusted, okText: L("İzin verildi"), noText: L("İzin henüz verilmedi"))
            if let help = model.permissionHelp {
                Text(help).font(.system(size: 12.5)).foregroundStyle(MM.warnText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                MMSecondaryButton(L("Ayarları aç")) { model.requestPermission() }
                MMSecondaryButton(L("İzni sıfırla ve yeniden iste")) { model.resetAccessibilityPermission() }
            }
        }
    }

    private var recognizeStep: some View {
        HStack(alignment: .top, spacing: 28) {
            MouseZoneMap(touches: model.liveTouches, layout: s.zoneLayout, flipped: s.flipY,
                         image: model.mouseImage, secondaryRightZone: twoButton, width: 120)
            VStack(alignment: .leading, spacing: 14) {
                Text(L("Parmaklarını farenin üstüne koy"))
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(MM.text)
                Text(L("Noktalar parmaklarını izler. Fareyi tanıdığımızda burada onay işareti görünür."))
                    .font(.system(size: 13.5)).foregroundStyle(MM.text2).fixedSize(horizontal: false, vertical: true)
                if model.miceCount <= 0 {
                    MMBanner(kind: .warning, title: L("Magic Mouse bulunamadı"),
                             message: L("Magic Mouse'un Bluetooth ile bağlı ve açık olduğundan emin ol."))
                } else {
                    status(ok: touchSeen, okText: L("Parmakların algılandı"), noText: L("Henüz parmak algılanmadı"))
                }
            }
        }
    }

    private var gestureStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("Orta bölgeye bas")).font(.system(size: 16, weight: .semibold)).foregroundStyle(MM.text)
            Text(L("Tek parmağını farenin orta bölgesine (turkuaz alan) koyup fareye bas. Orta tıklama gerçekleşecek."))
                .font(.system(size: 13.5)).foregroundStyle(MM.text2).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 28) {
                MouseZoneMap(touches: model.liveTouches, layout: s.zoneLayout, flipped: s.flipY,
                             image: model.mouseImage, secondaryRightZone: twoButton, width: 120)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 4) {
                        Text(L("Son eylem: ")).foregroundStyle(MM.text)
                        Text(model.lastAction ?? L("Henüz yok")).foregroundStyle(MM.text2)
                    }
                    .font(.system(size: 13))
                    if flow.step == .done || middleSeen {
                        MMBanner(kind: .info, title: L("Harika! Orta tıklama çalışıyor."))
                    }
                }
            }
        }
    }

    private func status(ok: Bool, okText: String, noText: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 16)).foregroundStyle(ok ? MM.okDot : MM.text2)
            Text(ok ? okText : noText).font(.system(size: 13.5, weight: .medium)).foregroundStyle(MM.text)
        }
    }

    // MARK: Alt şerit

    private var footer: some View {
        HStack(spacing: 10) {
            MMSecondaryButton(L("Geri")) { flow.back() }
                .opacity(flow.step == .permission ? 0.4 : 1)
                .disabled(flow.step == .permission)
            Spacer(minLength: 0)
            MMSecondaryButton(L("Atla")) {
                flow.skip()
                finish()
            }
            if shownStep == .firstGesture {
                MMPrimaryButton(L("Bitir")) { finish() }
            } else {
                MMPrimaryButton(L("Sonraki")) { flow.next() }
            }
        }
    }
}
