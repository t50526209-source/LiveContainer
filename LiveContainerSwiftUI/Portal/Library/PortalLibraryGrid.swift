//
//  PortalLibraryGrid.swift
//  Portal
//
//  Grid presentation of the app library with a "Recent" shelf on top.
//

import SwiftUI

enum PortalLibraryLayout: String, CaseIterable {
    case grid
    case list

    var title: String {
        switch self {
        case .grid:
            return pl("Cuadrícula", "Grid")
        case .list:
            return pl("Lista", "List")
        }
    }

    var systemImage: String {
        switch self {
        case .grid:
            return "square.grid.3x3.fill"
        case .list:
            return "list.bullet.rectangle.portrait"
        }
    }
}

struct PortalLibraryGrid: View {
    let apps: [LCAppModel]
    let delegate: LCAppBannerDelegate
    var showsRecents = true

    private let columns = [GridItem(.adaptive(minimum: 76, maximum: 100), spacing: 14, alignment: .top)]

    private var recentApps: [LCAppModel] {
        let launched = apps.filter { $0.appInfo.lastLaunched != nil }
        let sorted = launched.sorted {
            ($0.appInfo.lastLaunched ?? Date.distantPast) > ($1.appInfo.lastLaunched ?? Date.distantPast)
        }
        return Array(sorted.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PortalTheme.Spacing.xl) {
            if showsRecents && apps.count > 4 && !recentApps.isEmpty {
                VStack(alignment: .leading, spacing: PortalTheme.Spacing.m) {
                    PortalSectionHeader(title: pl("Recientes", "Recent"), systemImage: "clock.arrow.circlepath")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: PortalTheme.Spacing.m) {
                            ForEach(recentApps, id: \.self) { app in
                                PortalAppTile(model: app, delegate: delegate, style: .card)
                            }
                        }
                        .padding(.vertical, PortalTheme.Spacing.s)
                    }
                }
            }

            VStack(alignment: .leading, spacing: PortalTheme.Spacing.m) {
                if showsRecents && apps.count > 4 && !recentApps.isEmpty {
                    PortalSectionHeader(title: pl("Todas las apps", "All apps"), systemImage: "square.grid.2x2.fill")
                }
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(apps, id: \.self) { app in
                        PortalAppTile(model: app, delegate: delegate)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
    }
}
