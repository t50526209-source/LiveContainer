//
//  PortalDoctor.swift
//  Portal
//
//  Runs every setup check that commonly breaks guest apps and explains how to fix it.
//

import SwiftUI
import UIKit

enum PortalCheckStatus {
    case checking
    case ok
    case warning
    case error

    var color: Color {
        switch self {
        case .checking:
            return .secondary
        case .ok:
            return PortalTheme.success
        case .warning:
            return PortalTheme.warning
        case .error:
            return PortalTheme.danger
        }
    }

    var symbol: String {
        switch self {
        case .checking:
            return "hourglass"
        case .ok:
            return "checkmark.seal.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }
}

enum PortalCheckFix {
    case openSettings
    case openURL(URL)

    var title: String {
        switch self {
        case .openSettings:
            return pl("Ir a Ajustes", "Go to Settings")
        case .openURL:
            return pl("Ver guía", "Open guide")
        }
    }
}

struct PortalCheck: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    var status: PortalCheckStatus
    var detail: String
    var fix: PortalCheckFix? = nil
}

@MainActor
final class PortalDoctor: ObservableObject {
    @Published private(set) var checks: [PortalCheck] = []

    static let jitLessGuide = URL(string: "https://livecontainer.github.io/docs/faq/jit-less-mode-setup")!

    var finishedCount: Int {
        checks.filter { $0.status != .checking }.count
    }

    var okCount: Int {
        checks.filter { $0.status == .ok }.count
    }

    var problemCount: Int {
        checks.filter { $0.status == .warning || $0.status == .error }.count
    }

    var isRunning: Bool {
        checks.contains { $0.status == .checking }
    }

    func run() {
        let isSecondaryLC = DataManager.shared.model.multiLCStatus == 2
        var newChecks: [PortalCheck] = [
            systemCheck(),
            installerCheck(),
            developerCertificateCheck(),
            appGroupCheck(),
            extensionsCheck(),
            storageCheck()
        ]
        if !isSecondaryLC {
            newChecks.insert(certificateImportedCheck(), at: 2)
        }
        checks = newChecks

        if !isSecondaryLC, LCUtils.certificateData() != nil {
            checks.insert(PortalCheck(
                id: "certificateValidity",
                title: pl("Validez del certificado", "Certificate validity"),
                systemImage: "checkmark.shield",
                status: .checking,
                detail: pl("Consultando a Apple…", "Asking Apple…")
            ), at: 3)
            validateCertificate()
        }
    }

    private func update(_ id: String, status: PortalCheckStatus, detail: String, fix: PortalCheckFix? = nil) {
        guard let index = checks.firstIndex(where: { $0.id == id }) else {
            return
        }
        checks[index].status = status
        checks[index].detail = detail
        checks[index].fix = fix
    }

    // MARK: Checks

    private func systemCheck() -> PortalCheck {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = UIDevice.current.systemVersion
        if version.majorVersion >= 16 {
            return PortalCheck(
                id: "system",
                title: pl("Sistema", "System"),
                systemImage: "iphone",
                status: .ok,
                detail: pl("iOS \(versionString): compatible con todo, incluida la multitarea.",
                           "iOS \(versionString): everything is supported, including multitasking.")
            )
        }
        return PortalCheck(
            id: "system",
            title: pl("Sistema", "System"),
            systemImage: "iphone",
            status: .warning,
            detail: pl("iOS \(versionString): las apps funcionan, pero la multitarea necesita iOS 16 o superior.",
                       "iOS \(versionString): apps work, but multitasking needs iOS 16 or later.")
        )
    }

    private func installerCheck() -> PortalCheck {
        let store = LCUtils.store()
        let name: String
        switch store {
        case .SideStore:
            name = "SideStore"
        case .AltStore:
            name = "AltStore"
        case .ADP:
            name = pl("Cuenta de desarrollador de pago", "Paid developer account")
        default:
            return PortalCheck(
                id: "installer",
                title: pl("Instalador", "Installer"),
                systemImage: "shippingbox",
                status: .warning,
                detail: pl("No se detectó SideStore ni AltStore. Tendrás que importar el certificado a mano.",
                           "SideStore or AltStore wasn't detected. You'll need to import the certificate manually."),
                fix: .openURL(Self.jitLessGuide)
            )
        }
        return PortalCheck(
            id: "installer",
            title: pl("Instalador", "Installer"),
            systemImage: "shippingbox",
            status: .ok,
            detail: pl("Instalado con \(name).", "Installed with \(name).")
        )
    }

    private func certificateImportedCheck() -> PortalCheck {
        let hasData = LCUtils.certificateData() != nil
        let hasPassword = LCSharedUtils.certificatePassword() != nil
        if hasData && hasPassword {
            return PortalCheck(
                id: "certificate",
                title: pl("Certificado", "Certificate"),
                systemImage: "signature",
                status: .ok,
                detail: pl("Importado: Portal puede firmar apps sin JIT.", "Imported: Portal can sign apps without JIT.")
            )
        }
        return PortalCheck(
            id: "certificate",
            title: pl("Certificado", "Certificate"),
            systemImage: "signature",
            status: .error,
            detail: pl("Falta importar el certificado. Sin él, las apps solo abren con JIT activado.",
                       "The certificate hasn't been imported. Without it, apps only open with JIT enabled."),
            fix: .openSettings
        )
    }

    private func developerCertificateCheck() -> PortalCheck {
        let task = SecTaskCreateFromSelf(nil)
        var allowed = false
        if let value = SecTaskCopyValueForEntitlement(task, "get-task-allow" as CFString, nil) {
            allowed = (value.takeRetainedValue() as? NSNumber)?.boolValue ?? false
        }
        if allowed {
            return PortalCheck(
                id: "getTaskAllow",
                title: pl("Firma de desarrollo", "Development signing"),
                systemImage: "hammer",
                status: .ok,
                detail: pl("Portal está firmado con un perfil de desarrollo.", "Portal is signed with a development profile.")
            )
        }
        return PortalCheck(
            id: "getTaskAllow",
            title: pl("Firma de desarrollo", "Development signing"),
            systemImage: "hammer",
            status: .error,
            detail: pl("Portal no se instaló con un certificado de desarrollo (falta get-task-allow). Reinstálalo con SideStore o AltStore.",
                       "Portal wasn't installed with a development certificate (get-task-allow is missing). Reinstall it with SideStore or AltStore."),
            fix: .openURL(Self.jitLessGuide)
        )
    }

    private func appGroupCheck() -> PortalCheck {
        if LCSharedUtils.appGroupPath() != nil {
            return PortalCheck(
                id: "appGroup",
                title: "App Group",
                systemImage: "square.stack.3d.up",
                status: .ok,
                detail: pl("Accesible: las extensiones y el modo compartido funcionarán.",
                           "Accessible: extensions and shared mode will work.")
            )
        }
        return PortalCheck(
            id: "appGroup",
            title: "App Group",
            systemImage: "square.stack.3d.up",
            status: .warning,
            detail: pl("No hay App Group. Las apps compartidas y las extensiones no estarán disponibles.",
                       "No App Group. Shared apps and extensions won't be available.")
        )
    }

    private func extensionsCheck() -> PortalCheck {
        let pluginsURL = Bundle.main.builtInPlugInsURL
        let fm = FileManager.default
        let required = ["LiveProcess.appex"]
        let missing = required.filter { name in
            guard let pluginsURL else {
                return true
            }
            return !fm.fileExists(atPath: pluginsURL.appendingPathComponent(name).path)
        }
        if missing.isEmpty {
            return PortalCheck(
                id: "extensions",
                title: pl("Extensiones", "Extensions"),
                systemImage: "puzzlepiece.extension",
                status: .ok,
                detail: pl("La extensión de multitarea está instalada.", "The multitasking extension is installed.")
            )
        }
        return PortalCheck(
            id: "extensions",
            title: pl("Extensiones", "Extensions"),
            systemImage: "puzzlepiece.extension",
            status: .warning,
            detail: pl("Falta la extensión de multitarea. Reinstala Portal eligiendo \"Conservar extensiones\" en SideStore/AltStore.",
                       "The multitasking extension is missing. Reinstall Portal choosing \"Keep extensions\" in SideStore/AltStore.")
        )
    }

    private func storageCheck() -> PortalCheck {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let available = (try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage ?? 0
        let formatted = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
        let status: PortalCheckStatus
        let detail: String
        if available >= 2_000_000_000 {
            status = .ok
            detail = pl("\(formatted) libres.", "\(formatted) free.")
        } else if available >= 500_000_000 {
            status = .warning
            detail = pl("Solo \(formatted) libres. Las IPAs grandes pueden fallar al instalarse.",
                        "Only \(formatted) free. Large IPAs may fail to install.")
        } else {
            status = .error
            detail = pl("Casi sin espacio (\(formatted)). Libera espacio antes de instalar apps.",
                        "Almost out of space (\(formatted)). Free some space before installing apps.")
        }
        return PortalCheck(
            id: "storage",
            title: pl("Almacenamiento", "Storage"),
            systemImage: "internaldrive",
            status: status,
            detail: detail
        )
    }

    private func validateCertificate() {
        _ = LCUtils.validateCertificate { [weak self] status, date, _, error in
            Task { @MainActor in
                guard let self else {
                    return
                }
                if let error {
                    self.update("certificateValidity", status: .warning,
                                detail: pl("No se pudo comprobar: \(error.loc)", "Couldn't verify: \(error.loc)"))
                    return
                }
                var expiry = ""
                if let date {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .none
                    expiry = formatter.string(from: date)
                }
                if status == 0 {
                    self.update("certificateValidity", status: .ok,
                                detail: expiry.isEmpty
                                    ? pl("Válido.", "Valid.")
                                    : pl("Válido hasta el \(expiry).", "Valid until \(expiry)."))
                } else {
                    self.update("certificateValidity", status: .error,
                                detail: pl("El certificado fue revocado o no es válido. Vuelve a importarlo desde tu instalador.",
                                           "The certificate was revoked or is invalid. Import it again from your installer."),
                                fix: .openSettings)
                }
            }
        }
    }
}
