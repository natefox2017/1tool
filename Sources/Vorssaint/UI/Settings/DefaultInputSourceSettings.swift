// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Carbon.HIToolbox
import SwiftUI

struct DefaultInputSourceSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = DefaultInputSourceService.shared
    @AppStorage(DefaultsKey.defaultInputSourceEnabled) private var enabled = false
    @AppStorage(DefaultsKey.defaultInputSourceRules) private var rawRules = ""
    @AppStorage(DefaultsKey.defaultInputSourceFallback) private var fallbackSourceID = ""
    @State private var showingAppPicker = false
    @State private var sources: [InputSourceSelection.Reading] = []
    @State private var hasEnglishLayout = false

    private var rules: [String: String] { DefaultInputSourceSupport.decode(rawRules) }
    private func text(_ key: String) -> String { DefaultInputSourceStrings.text(key, language: l10n.language) }

    var body: some View {
        Form {
            Section {
                Toggle(text("enabled"), isOn: $enabled)
                Text(text("hint")).font(.caption).foregroundStyle(.secondary)
            }
            Section(text("global")) {
                HStack(spacing: 12) {
                    Text(text("source"))
                    Spacer(minLength: 12)
                    Picker(text("source"), selection: $fallbackSourceID) {
                        Text(text("system")).tag("")
                        ForEach(sources, id: \.id) { source in
                            Text(source.name).tag(source.id)
                        }
                        if fallbackMissing { Text(fallbackSourceID).tag(fallbackSourceID) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityIdentifier("defaultInputSource.global")
                }
                Text(text("globalHint")).font(.caption).foregroundStyle(.secondary)
                if fallbackMissing {
                    Text(text("missing")).font(.caption).foregroundStyle(.orange)
                }
                if service.failed {
                    Label(text("failed"), systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            Section(text("apps")) {
                if rules.isEmpty {
                    Text(text("empty")).foregroundStyle(.secondary)
                }
                ForEach(rules.keys.sorted(), id: \.self) { bundleID in
                    appRow(bundleID)
                }
                Button { showingAppPicker = true } label: {
                    Label(text("add"), systemImage: "plus")
                }
            }
            Section {
                if !hasEnglishLayout {
                    Label(text("noEnglish"), systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
                Text(text("bilingual")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(onCancel: { showingAppPicker = false }, onSelect: { url in
                showingAppPicker = false
                guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
                var next = rules
                next[bundleID] = ""
                rawRules = DefaultInputSourceSupport.encode(next)
            }, loadApps: {
                InstalledApps.installedBundleApplications(excluding: Set(rules.keys))
            })
        }
        .onAppear { refreshSources(); service.syncWithPreferences() }
        .onChange(of: enabled) { _, _ in service.syncWithPreferences() }
        .onChange(of: fallbackSourceID) { _, _ in service.syncWithPreferences() }
        .onChange(of: rawRules) { _, _ in service.syncWithPreferences() }
        .onReceive(DistributedNotificationCenter.default.publisher(
            for: Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String))) { _ in
                refreshSources()
            }
    }

    private var fallbackMissing: Bool {
        !fallbackSourceID.isEmpty && !sources.contains { $0.id == fallbackSourceID }
    }

    private func appRow(_ bundleID: String) -> some View {
        let sourceID = rules[bundleID] ?? ""
        let missing = !sourceID.isEmpty && !sources.contains { $0.id == sourceID }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(nsImage: InstalledApps.icon(for: bundleID))
                    .resizable().frame(width: 24, height: 24)
                Text(InstalledApps.name(for: bundleID))
                Spacer()
                Picker(text("source"), selection: Binding(get: {
                    rules[bundleID] ?? ""
                }, set: { value in
                    var next = rules
                    next[bundleID] = value
                    rawRules = DefaultInputSourceSupport.encode(next)
                })) {
                    Text(text("automatic")).tag("")
                    ForEach(sources, id: \.id) { source in
                        Text(source.name).tag(source.id)
                    }
                    if missing { Text(sourceID).tag(sourceID) }
                }
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel("\(InstalledApps.name(for: bundleID)): \(text("source"))")
                Button {
                    var next = rules
                    next.removeValue(forKey: bundleID)
                    rawRules = DefaultInputSourceSupport.encode(next)
                } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.bordered)
                .help(text("remove"))
                .accessibilityLabel(text("remove") + " " + InstalledApps.name(for: bundleID))
            }
            if missing {
                Text(text("missing")).font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private func refreshSources() {
        sources = InputSourceSelection.availableReadings()
        hasEnglishLayout = InputSourceSelection.snapshots().contains { $0.isLayout && $0.isASCIICapable }
    }
}
