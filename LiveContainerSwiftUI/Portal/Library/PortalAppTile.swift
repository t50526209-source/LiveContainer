//
//  PortalAppTile.swift
//  Portal
//
//  Home-screen style tile for a guest app. Tap to launch, long-press for every action
//  the classic LiveContainer banner offers.
//

import SwiftUI
import UIKit

struct PortalAppTile: View {
    enum Style {
        case grid
        case card
    }

    @ObservedObject var model: LCAppModel
    let delegate: LCAppBannerDelegate
    var style: Style = .grid

    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false
    @State private var errorText: String? = nil
    @State private var showUninstallDialog = false

    private var icon: UIImage? {
        PortalIconStore.shared.icon(for: model.appInfo, dark: darkModeIcon)
    }

    private var tint: Color {
        PortalIconStore.shared.mainColor(for: model.appInfo, dark: darkModeIcon)
    }

    var body: some View {
        Button(action: launch) {
            switch style {
            case .grid:
                gridLabel
            case .card:
                cardLabel
            }
        }
        .buttonStyle(PortalPressableStyle(scale: style == .grid ? 0.9 : 0.96))
        .disabled(model.isSigningInProgress)
        .contextMenu { menuContent }
        .accessibilityLabel(model.displayName)
        .accessibilityHint(pl("Abre la app", "Opens the app"))
        .confirmationDialog(
            pl("¿Desinstalar \(model.displayName)?", "Uninstall \(model.displayName)?"),
            isPresented: $showUninstallDialog,
            titleVisibility: .visible
        ) {
            Button(pl("Desinstalar y conservar datos", "Uninstall, keep data"), role: .destructive) {
                uninstall(deleteData: false)
            }
            if !model.appInfo.containers.isEmpty {
                Button(pl("Desinstalar y borrar datos", "Uninstall and delete data"), role: .destructive) {
                    uninstall(deleteData: true)
                }
            }
            Button(pl("Cancelar", "Cancel"), role: .cancel) {}
        } message: {
            Text(pl("Conservar los datos te permite reinstalar la app sin perder tu sesión.",
                    "Keeping data lets you reinstall the app without losing your session."))
        }
        .alert(
            pl("Error", "Error"),
            isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })
        ) {
            Button(pl("Copiar", "Copy")) {
                UIPasteboard.general.string = errorText
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    // MARK: Labels

    private var gridLabel: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                PortalAppIcon(image: icon, size: 62)
                    .overlay(signingOverlay(size: 62))
                badges
                    .offset(x: 7, y: -7)
            }
            Text(model.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Circle()
                .fill(model.isAppRunning ? PortalTheme.success : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var cardLabel: some View {
        HStack(spacing: PortalTheme.Spacing.m) {
            PortalAppIcon(image: icon, size: 46)
                .overlay(signingOverlay(size: 46))
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(model.uiSelectedContainer?.name ?? model.version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: PortalTheme.Spacing.xs)
            Image(systemName: model.isAppRunning ? "arrow.up.forward.app.fill" : "play.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint, in: Circle())
        }
        .padding(PortalTheme.Spacing.m)
        .frame(width: 236)
        .portalGlassCard(tint: tint.opacity(0.5), cornerRadius: PortalTheme.Radius.tile)
        .contentShape(RoundedRectangle(cornerRadius: PortalTheme.Radius.tile, style: .continuous))
    }

    @ViewBuilder
    private func signingOverlay(size: CGFloat) -> some View {
        if model.isSigningInProgress {
            ZStack {
                Color.black.opacity(0.45)
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 3)
                    .frame(width: size * 0.42, height: size * 0.42)
                Circle()
                    .trim(from: 0, to: max(0.02, min(model.signProgress, 1)))
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size * 0.42, height: size * 0.42)
                    .animation(.easeInOut, value: model.signProgress)
            }
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
        }
    }

    private var badges: some View {
        HStack(spacing: 2) {
            if model.uiIsLocked && !model.uiIsHidden {
                badge("lock.fill", color: PortalTheme.warning)
            }
            if model.uiIsJITNeeded && !model.uiIs32bit {
                badge("bolt.fill", color: .purple)
            }
            if model.uiIsShared {
                badge("arrowshape.turn.up.left.fill", color: PortalTheme.accentSecondary)
            }
        }
    }

    private func badge(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(color, in: Circle())
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
    }

    // MARK: Menu

    @ViewBuilder
    private var menuContent: some View {
        if model.uiContainers.count > 1 {
            Picker(selection: Binding(get: { model.uiSelectedContainer }, set: { model.uiSelectedContainer = $0 })) {
                ForEach(model.uiContainers, id: \.self) { container in
                    Text(container.name).tag(Optional(container))
                }
            } label: {
                Label(pl("Contenedor", "Container"), systemImage: "shippingbox")
            }
        }

        Button(action: launch) {
            Label(pl("Abrir", "Open"), systemImage: "play.fill")
        }

        if #available(iOS 16.0, *) {
            let inWindow = model.shouldLaunchInMultitaskMode
            Button {
                run(multitask: !inWindow)
            } label: {
                Label(inWindow ? pl("Abrir a pantalla completa", "Open full screen") : pl("Abrir en ventana", "Open in window"),
                      systemImage: inWindow ? "arrow.up.left.and.arrow.down.right" : "macwindow.badge.plus")
            }
        }

        Divider()

        Menu {
            Button(action: copyLaunchUrl) {
                Label(pl("Copiar enlace de apertura", "Copy launch link"), systemImage: "link")
            }
            Button {
                Task { await createWebClip() }
            } label: {
                Label(pl("Crear icono en pantalla de inicio", "Create Home Screen icon"), systemImage: "plus.app")
            }
        } label: {
            Label(pl("Pantalla de inicio", "Home Screen"), systemImage: "apps.iphone")
        }

        if !model.uiIsShared, model.uiSelectedContainer != nil {
            Button(action: openDataFolder) {
                Label(pl("Abrir carpeta de datos", "Open data folder"), systemImage: "folder")
            }
        }

        Button(action: openSettings) {
            Label(pl("Ajustes de la app", "App settings"), systemImage: "gearshape")
        }

        if !model.uiIsShared {
            Divider()
            Button(role: .destructive) {
                showUninstallDialog = true
            } label: {
                Label(pl("Desinstalar", "Uninstall"), systemImage: "trash")
            }
        }
    }

    // MARK: Actions

    private func launch() {
        PortalHaptics.tap()
        if #available(iOS 16.0, *),
           let folderName = model.uiSelectedContainer?.folderName,
           MultitaskManager.isUsing(container: folderName) {
            var found = false
            if #available(iOS 16.1, *) {
                found = MultitaskWindowManager.openExistingAppWindow(dataUUID: folderName)
            }
            if !found {
                found = MultitaskDockManager.shared.bringMultitaskViewToFront(uuid: folderName)
            }
            if found {
                return
            }
        }
        run(multitask: nil)
    }

    private func run(multitask: Bool?) {
        Task { @MainActor in
            if model.appInfo.isLocked && !DataManager.shared.model.isHiddenAppUnlocked {
                do {
                    if !(try await LCUtils.authenticateUser()) {
                        return
                    }
                } catch {
                    errorText = error.localizedDescription
                    return
                }
            }
            do {
                try await model.runApp(multitask: multitask)
            } catch {
                PortalHaptics.error()
                errorText = error.localizedDescription
            }
        }
    }

    private func openSettings() {
        delegate.openNavigationView(view: AnyView(LCAppSettingsView(model: model)))
    }

    private func openDataFolder() {
        guard let folderName = model.uiSelectedContainer?.folderName,
              let url = URL(string: "shareddocuments://\(LCPath.dataPath.path)/\(folderName)") else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func copyLaunchUrl() {
        guard let relativeBundlePath = model.appInfo.relativeBundlePath else {
            return
        }
        var url = "livecontainer://livecontainer-launch?bundle-name=\(relativeBundlePath)"
        if let folderName = model.uiSelectedContainer?.folderName {
            url += "&container-folder-name=\(folderName)"
        }
        UIPasteboard.general.string = url
        PortalHaptics.success()
    }

    @MainActor
    private func createWebClip() async {
        guard let style = await delegate.promptForGeneratedIconStyle() else {
            return
        }
        do {
            guard let profile = model.appInfo.generateWebClipConfig(
                withContainerId: model.uiSelectedContainer?.folderName,
                iconStyle: style
            ) else {
                throw CocoaError(.propertyListWriteInvalid)
            }
            let data = try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
            delegate.installMdm(data: data)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func uninstall(deleteData: Bool) {
        let appInfo = model.appInfo
        let containers = appInfo.containers
        do {
            guard let bundlePath = appInfo.bundlePath() else {
                throw CocoaError(.fileNoSuchFile)
            }
            let fileManager = FileManager.default
            try fileManager.removeItem(atPath: bundlePath)
            delegate.removeApp(app: model)

            if deleteData {
                for container in containers {
                    let dataUUID = container.folderName
                    try fileManager.removeItem(at: LCPath.dataPath.appendingPathComponent(dataUUID))
                    LCUtils.removeAppKeychain(dataUUID: dataUUID)
                    DataManager.shared.model.appDataFolderNames.removeAll { $0 == dataUUID }
                }
            }
            PortalHaptics.success()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
