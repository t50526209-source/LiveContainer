//
//  PortalDoctorView.swift
//  Portal
//

import SwiftUI

struct PortalDoctorView: View {
    @StateObject private var doctor = PortalDoctor()
    @Environment(\.dismiss) private var dismiss

    /// Called when a fix needs to leave this screen (e.g. jump to the Settings tab).
    var onOpenSettings: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: PortalTheme.Spacing.l) {
                PortalDoctorSummary(doctor: doctor)

                ForEach(doctor.checks) { check in
                    PortalCheckRow(check: check, onFix: handle)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                NavigationLink {
                    LCJITLessDiagnoseView()
                } label: {
                    HStack {
                        Label(pl("Diagnóstico avanzado", "Advanced diagnostics"), systemImage: "stethoscope")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.primary)
                    .padding(PortalTheme.Spacing.l)
                    .portalGlassCard(cornerRadius: PortalTheme.Radius.control + 4)
                }
                .buttonStyle(PortalPressableStyle(scale: 0.97))
            }
            .padding()
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: doctor.finishedCount)
        }
        .background(PortalBackground())
        .navigationTitle("Doctor")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    PortalHaptics.tap()
                    doctor.run()
                } label: {
                    Label(pl("Repetir", "Run again"), systemImage: "arrow.clockwise")
                }
                .disabled(doctor.isRunning)
            }
        }
        .onAppear {
            if doctor.checks.isEmpty {
                doctor.run()
            }
        }
    }

    private func handle(_ fix: PortalCheckFix) {
        switch fix {
        case .openSettings:
            if let onOpenSettings {
                onOpenSettings()
            } else {
                DataManager.shared.model.selectedTab = .settings
                dismiss()
            }
        case .openURL(let url):
            UIApplication.shared.open(url)
        }
    }
}

struct PortalDoctorSummary: View {
    @ObservedObject var doctor: PortalDoctor

    private var total: Int {
        max(doctor.checks.count, 1)
    }

    private var title: String {
        if doctor.isRunning {
            return pl("Revisando…", "Checking…")
        }
        if doctor.problemCount == 0 {
            return pl("Todo listo", "All set")
        }
        return doctor.problemCount == 1
            ? pl("1 cosa por revisar", "1 thing to review")
            : pl("\(doctor.problemCount) cosas por revisar", "\(doctor.problemCount) things to review")
    }

    private var subtitle: String {
        if doctor.problemCount == 0 && !doctor.isRunning {
            return pl("Tu instalación está lista para ejecutar apps.", "Your setup is ready to run apps.")
        }
        return pl("Toca una tarjeta para ver cómo solucionarlo.", "Each card explains how to fix it.")
    }

    var body: some View {
        HStack(spacing: PortalTheme.Spacing.l) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: CGFloat(doctor.okCount) / CGFloat(total))
                    .stroke(PortalTheme.accentGradient, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: doctor.okCount)
                Text("\(doctor.okCount)/\(doctor.checks.count)")
                    .font(PortalTheme.rounded(.headline))
                    .monospacedDigit()
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PortalTheme.rounded(.title2))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(PortalTheme.Spacing.l)
        .portalGlassCard(tint: doctor.problemCount == 0 && !doctor.isRunning ? PortalTheme.success.opacity(0.4) : PortalTheme.accent.opacity(0.35))
    }
}

struct PortalCheckRow: View {
    let check: PortalCheck
    let onFix: (PortalCheckFix) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PortalTheme.Spacing.m) {
            HStack(spacing: PortalTheme.Spacing.m) {
                Image(systemName: check.systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(check.status.color)
                    .frame(width: 36, height: 36)
                    .background(check.status.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(check.title)
                    .font(.headline)
                Spacer()
                if check.status == .checking {
                    ProgressView()
                } else {
                    Image(systemName: check.status.symbol)
                        .font(.title3)
                        .foregroundStyle(check.status.color)
                }
            }
            Text(check.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let fix = check.fix {
                Button {
                    PortalHaptics.tap()
                    onFix(fix)
                } label: {
                    Text(fix.title)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, PortalTheme.Spacing.l)
                        .padding(.vertical, PortalTheme.Spacing.s)
                        .foregroundStyle(.white)
                        .background(check.status.color, in: Capsule())
                }
                .buttonStyle(PortalPressableStyle(scale: 0.95))
            }
        }
        .padding(PortalTheme.Spacing.l)
        .portalGlassCard(cornerRadius: PortalTheme.Radius.control + 6)
    }
}
