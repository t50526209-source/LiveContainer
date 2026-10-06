//
//  PortalComponents.swift
//  Portal
//
//  Reusable building blocks: glass cards, pills, icons and section headers.
//

import SwiftUI
import UIKit

struct PortalCard<Content: View>: View {
    var tint: Color? = nil
    var padding: CGFloat = PortalTheme.Spacing.l
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .portalGlassCard(tint: tint)
    }
}

struct PortalPill: View {
    let text: String
    var systemImage: String? = nil
    var color: Color = PortalTheme.accent

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(color)
        .background(color.opacity(0.16), in: Capsule())
    }
}

struct PortalSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PortalTheme.Spacing.s) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(PortalTheme.accentGradient)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PortalTheme.rounded(.title3))
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct PortalAppIcon: View {
    let image: UIImage?
    var size: CGFloat = 62

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
    }

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.22)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.16), radius: size * 0.08, x: 0, y: size * 0.05)
    }
}

/// Caches guest app icons and their dominant colour so grids stay smooth while scrolling.
final class PortalIconStore {
    static let shared = PortalIconStore()

    private let icons = NSCache<NSString, UIImage>()

    private func key(_ appInfo: LCAppInfo, dark: Bool) -> NSString {
        "\(ObjectIdentifier(appInfo).hashValue)-\(appInfo.relativeBundlePath ?? "")-\(dark)" as NSString
    }

    func icon(for appInfo: LCAppInfo, dark: Bool) -> UIImage? {
        let cacheKey = key(appInfo, dark: dark)
        if let cached = icons.object(forKey: cacheKey) {
            return cached
        }
        guard let image = appInfo.iconIsDarkIcon(dark) else {
            return nil
        }
        icons.setObject(image, forKey: cacheKey)
        return image
    }

    /// Same hue-preserving average the classic banner uses, cached on the app info object.
    func mainColor(for appInfo: LCAppInfo, dark: Bool) -> Color {
        if dark, let cached = appInfo.cachedColorDark {
            return Color(cached)
        }
        if !dark, let cached = appInfo.cachedColor {
            return Color(cached)
        }
        guard let cgImage = icon(for: appInfo, dark: dark)?.cgImage else {
            return PortalTheme.accent
        }

        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return PortalTheme.accent
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        let average = UIColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        )
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        average.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let color: UIColor
        if brightness < 0.1 && saturation < 0.1 {
            color = .systemRed
        } else {
            color = UIColor(hue: hue, saturation: saturation, brightness: max(brightness, 0.3), alpha: 1)
        }
        if dark {
            appInfo.cachedColorDark = color
        } else {
            appInfo.cachedColor = color
        }
        return Color(color)
    }
}
