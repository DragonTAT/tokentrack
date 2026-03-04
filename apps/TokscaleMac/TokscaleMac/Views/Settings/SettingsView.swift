import SwiftUI
import Sparkle

/// Settings window with Theme, Time Zone, and Update sections.
struct SettingsView: View {
    @Environment(DataStore.self) private var store
    @State private var settings = AppSettings.shared

    // Sparkle updater controller
    private let updaterController: SPUStandardUpdaterController

    init() {
        // Create updater controller; startingUpdater=true starts automatic checks
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                Text("Settings")
                    .font(.title2.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Appearance
                    settingsSection(title: "Appearance", icon: "paintpalette.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Theme")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            // Theme grid
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                                ForEach(ThemeName.allCases) { theme in
                                    themeCard(theme)
                                }
                            }
                        }
                    }

                    // MARK: - Time
                    settingsSection(title: "Time", icon: "clock.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Day Boundary")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            Text("Choose how a \"day\" is calculated for usage statistics.")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)

                            Picker("", selection: Bindable(settings).useUTC) {
                                Label("Local Time", systemImage: "location.fill")
                                    .tag(false)
                                Label("UTC", systemImage: "globe")
                                    .tag(true)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 10))
                                Text(settings.useUTC
                                     ? "Days are calculated using UTC (Coordinated Universal Time)."
                                     : "Days are calculated using your local timezone (\(TimeZone.current.abbreviation() ?? "")).")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(.tertiary)
                        }
                    }

                    // MARK: - Updates
                    settingsSection(title: "Updates", icon: "arrow.triangle.2.circlepath") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("TokenTrack")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Version \(appVersion)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Check for Updates") {
                                    updaterController.checkForUpdates(nil)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            Toggle(
                                "Automatically check for updates",
                                isOn: Binding(
                                    get: { updaterController.updater.automaticallyChecksForUpdates },
                                    set: { updaterController.updater.automaticallyChecksForUpdates = $0 }
                                )
                            )
                            .font(.system(size: 12))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 420, height: 520)
        .background(.regularMaterial)
        .preferredColorScheme(.dark)
    }

    // MARK: - Theme Card

    private func themeCard(_ theme: ThemeName) -> some View {
        let isSelected = settings.themeName == theme
        let themeObj = Theme.from(theme)

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                settings.themeName = theme
            }
        }) {
            VStack(spacing: 6) {
                // Color preview squares
                HStack(spacing: 2) {
                    ForEach(1..<themeObj.colors.count, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(themeObj.colors[i])
                            .frame(height: 16)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(theme.displayName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(8)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? themeObj.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Builder

    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .semibold))

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}
