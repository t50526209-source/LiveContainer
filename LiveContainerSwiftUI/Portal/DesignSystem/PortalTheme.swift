//
//  PortalTheme.swift
//  Portal
//
//  Design tokens and the Liquid Glass modifier used across Portal's UI.
//  Everything here degrades gracefully: Liquid Glass on iOS 26+, blurred materials on older systems.
//

import SwiftUI
import UIKit

/// Returns the Spanish string when the device's preferred language is Spanish, English otherwise.
func pl(_ es: String, _ en: String) -> String {
    PortalTheme.prefersSpanish ? es : en
}

enum PortalTheme {
    static let prefersSpanish: Bool = (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("es")

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 26
        static let tile: CGFloat = 22
        static let control: CGFloat = 14
    }

    static let accent = Color(red: 0.45, green: 0.36, blue: 0.98)
    static let accentSecondary = Color(red: 0.15, green: 0.72, blue: 0.97)
    static let success = Color(red: 0.20, green: 0.78, blue: 0.45)
    static let warning = Color(red: 1.00, green: 0.62, blue: 0.10)
    static let danger = Color(red: 0.96, green: 0.28, blue: 0.32)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded).weight(weight)
    }

    /// Liquid Glass is only used when the system supports it and the app isn't forced into compatibility mode.
    static var usesLiquidGlass: Bool {
        SharedModel.isLiquidGlassEnabled
    }
}

// MARK: - Glass

struct PortalGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color?
    var interactive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if PortalTheme.usesLiquidGlass {
                content.glassEffect(makeGlass(), in: shape)
            } else {
                materialFallback(content)
            }
        } else {
            materialFallback(content)
        }
    }

    @available(iOS 26.0, *)
    private func makeGlass() -> Glass {
        var glass = Glass.regular
        if let tint {
            glass = glass.tint(tint)
        }
        if interactive {
            glass = glass.interactive()
        }
        return glass
    }

    @ViewBuilder
    private func materialFallback(_ content: Content) -> some View {
        content.background(
            ZStack {
                shape.fill(.ultraThinMaterial)
                if let tint {
                    shape.fill(tint.opacity(0.16))
                }
                shape.stroke(Color.white.opacity(0.18), lineWidth: 0.6)
            }
        )
    }
}

extension View {
    func portalGlass<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(PortalGlassModifier(shape: shape, tint: tint, interactive: interactive))
    }

    func portalGlassCard(tint: Color? = nil, cornerRadius: CGFloat = PortalTheme.Radius.card) -> some View {
        portalGlass(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: tint)
    }
}

// MARK: - Background

/// Soft gradient backdrop that gives the glass surfaces something to refract.
struct PortalBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            if #available(iOS 18.0, *) {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.5], [0.6, 0.45], [1, 0.5],
                        [0, 1], [0.5, 1], [1, 1]
                    ],
                    colors: [
                        PortalTheme.accent, .clear, PortalTheme.accentSecondary,
                        .clear, .clear, .clear,
                        PortalTheme.accentSecondary.opacity(0.6), .clear, PortalTheme.accent.opacity(0.7)
                    ]
                )
                .opacity(colorScheme == .dark ? 0.30 : 0.18)
            } else {
                LinearGradient(
                    colors: [PortalTheme.accent.opacity(0.22), .clear, PortalTheme.accentSecondary.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Interaction

struct PortalPressableStyle: ButtonStyle {
    var scale: CGFloat = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

enum PortalHaptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
