//
//  PortalOnboardingView.swift
//  Portal
//
//  First-launch walkthrough that ends with a live Doctor check of the user's setup.
//

import SwiftUI

struct PortalOnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("PortalOnboardingDone") private var onboardingDone = false
    @StateObject private var doctor = PortalDoctor()
    @State private var page = 0

    private let lastPage = 2

    var body: some View {
        ZStack {
            PortalBackground()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    howItWorksPage.tag(1)
                    checkupPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button(action: advance) {
                    Text(page == lastPage ? pl("Empezar", "Get started") : pl("Continuar", "Continue"))
                        .font(PortalTheme.rounded(.headline))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PortalTheme.Spacing.l)
                        .background(PortalTheme.accentGradient, in: Capsule())
                }
                .buttonStyle(PortalPressableStyle(scale: 0.97))
                .padding(.horizontal, PortalTheme.Spacing.xl)
                .padding(.bottom, PortalTheme.Spacing.l)
            }
        }
        .onChange(of: page) { newPage in
            if newPage == lastPage && doctor.checks.isEmpty {
                doctor.run()
            }
        }
    }

    private func advance() {
        PortalHaptics.tap()
        if page < lastPage {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                page += 1
            }
        } else {
            finish()
        }
    }

    private func finish() {
        onboardingDone = true
        isPresented = false
    }

    // MARK: Pages

    private var welcomePage: some View {
        VStack(spacing: PortalTheme.Spacing.xl) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(PortalTheme.accentGradient)
                    .frame(width: 128, height: 128)
                    .shadow(color: PortalTheme.accent.opacity(0.45), radius: 24, y: 12)
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(spacing: PortalTheme.Spacing.s) {
                Text(pl("Bienvenido a Portal", "Welcome to Portal"))
                    .font(PortalTheme.rounded(.largeTitle))
                    .multilineTextAlignment(.center)
                Text(pl("Ejecuta apps IPA sin instalarlas, cada una con sus propios datos, como si fueran nativas.",
                        "Run IPA apps without installing them, each with its own data, as if they were native."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, PortalTheme.Spacing.xl)
            Spacer()
            Spacer()
        }
    }

    private var howItWorksPage: some View {
        VStack(alignment: .leading, spacing: PortalTheme.Spacing.l) {
            Spacer()
            Text(pl("Cómo funciona", "How it works"))
                .font(PortalTheme.rounded(.largeTitle))
                .padding(.bottom, PortalTheme.Spacing.s)
            featureRow(symbol: "doc.badge.plus",
                       title: pl("Importa una IPA", "Import an IPA"),
                       detail: pl("Desde Archivos, Safari, AirDrop o un enlace.", "From Files, Safari, AirDrop or a link."))
            featureRow(symbol: "signature",
                       title: pl("Portal la firma", "Portal signs it"),
                       detail: pl("Con tu propio certificado; sin gastar huecos de apps de tu cuenta.",
                                  "With your own certificate, without using up your account's app slots."))
            featureRow(symbol: "play.circle.fill",
                       title: pl("Ábrela al instante", "Open it instantly"),
                       detail: pl("En pantalla completa o en una ventana flotante, con contenedores de datos separados.",
                                  "Full screen or in a floating window, with separate data containers."))
            PortalCard(tint: PortalTheme.warning.opacity(0.4)) {
                Label(pl("Usa solo apps que te pertenezcan o que tengas derecho a usar.",
                         "Only use apps you own or have the right to use."),
                      systemImage: "hand.raised.fill")
                    .font(.footnote.weight(.medium))
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, PortalTheme.Spacing.xl)
    }

    private var checkupPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PortalTheme.Spacing.m) {
                Text(pl("Revisemos tu instalación", "Let's check your setup"))
                    .font(PortalTheme.rounded(.title))
                    .padding(.top, PortalTheme.Spacing.xl)
                PortalDoctorSummary(doctor: doctor)
                ForEach(doctor.checks) { check in
                    PortalCheckRow(check: check) { fix in
                        switch fix {
                        case .openSettings:
                            DataManager.shared.model.selectedTab = .settings
                            finish()
                        case .openURL(let url):
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            .padding(.horizontal, PortalTheme.Spacing.xl)
            .padding(.bottom, 48)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: doctor.finishedCount)
        }
    }

    private func featureRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: PortalTheme.Spacing.l) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(PortalTheme.accentGradient)
                .frame(width: 44, height: 44)
                .portalGlass(RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
