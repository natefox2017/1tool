// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum DefaultInputSourceTests {
    static func run(_ suite: TestSuite) {
        var clears = 0
        var selections: [String] = []
        suite.expect(DefaultInputSourceSupport.apply(target: "ABC", currentID: "ABC", clearCapsLock: {
            clears += 1; return true
        }, select: { selections.append($0); return true }),
                     "an already-selected input source still clears Caps Lock")
        suite.expect(clears == 1 && selections.isEmpty,
                     "same-source activation clears the lock without reselecting the input source")
        suite.expect(DefaultInputSourceSupport.apply(target: "Pinyin", currentID: "ABC", clearCapsLock: {
            clears += 1; return true
        }, select: { selections.append($0); return true }) && selections == ["Pinyin"],
                     "a different app source is selected and Caps Lock is cleared")
        suite.expect(!DefaultInputSourceSupport.apply(target: "ABC", currentID: "ABC", clearCapsLock: {
            false
        }, select: { _ in true }), "a Caps Lock reset failure is surfaced even when the source is already correct")
        suite.expect(!DefaultInputSourceSupport.apply(target: "Missing", currentID: "ABC", clearCapsLock: {
            true
        }, select: { _ in false }), "input source selection failures are surfaced")
        suite.expect(!DefaultInputSourceSupport.apply(target: nil, currentID: "ABC", clearCapsLock: {
            clears += 1; return true
        }, select: { _ in selections.append("unexpected"); return true })
                     && clears == 3 && !selections.contains("unexpected"),
                     "an unavailable configured source still clears Caps Lock without selecting an unrelated source")
        let english = InputSourceSelection.Snapshot(id: "ABC", isLayout: true, isASCIICapable: true)
        let chinese = InputSourceSelection.Snapshot(id: "Pinyin", isLayout: false, isASCIICapable: true)
        let sources = [chinese, english]
        let rules = ["terminal": "", "notes": "Pinyin", "removed": "Missing"]
        suite.expect(DefaultInputSourceSupport.target(bundleID: "terminal", rules: rules, sources: sources) == "ABC",
                     "automatic English skips bilingual input methods")
        suite.expect(DefaultInputSourceSupport.target(bundleID: "notes", rules: rules, sources: sources) == "Pinyin",
                     "each app can explicitly select Chinese")
        suite.expect(DefaultInputSourceSupport.target(bundleID: "other", rules: rules, sources: sources) == nil,
                     "unconfigured applications keep their system source")
        suite.expect(DefaultInputSourceSupport.target(bundleID: nil, rules: rules, sources: sources) == nil,
                     "apps without bundle identities are ignored")
        suite.expect(DefaultInputSourceSupport.target(bundleID: "removed", rules: rules, sources: sources) == nil,
                     "removed sources never fall back to unrelated keyboards")
        suite.expect(DefaultInputSourceSupport.target(bundleID: "terminal", rules: rules, sources: [chinese]) == nil,
                     "automatic English refuses a bilingual method when no ASCII layout is enabled")
        suite.expect(DefaultInputSourceSupport.target(bundleID: "other", rules: rules, sources: sources,
                     fallbackSourceID: "Pinyin") == "Pinyin", "unconfigured apps use the global default")
        suite.expect(DefaultInputSourceSupport.target(bundleID: "notes", rules: rules, sources: sources,
                     fallbackSourceID: "ABC") == "Pinyin", "an app override takes precedence over the global default")
        suite.expect(DefaultInputSourceSupport.target(bundleID: "terminal", rules: rules, sources: sources,
                     fallbackSourceID: "Pinyin") == "ABC", "automatic English app overrides still take precedence")
        suite.expect(DefaultInputSourceSupport.target(bundleID: "removed", rules: rules, sources: sources,
                     fallbackSourceID: "ABC") == nil, "a missing explicit override never silently uses another source")
        suite.expect(DefaultInputSourceSupport.target(bundleID: "other", rules: rules, sources: sources,
                     fallbackSourceID: "Missing") == nil, "a removed global source never switches to another keyboard")
        suite.expect(DefaultInputSourceSupport.target(bundleID: nil, rules: rules, sources: sources,
                     fallbackSourceID: "Pinyin") == nil, "the global default still ignores apps without identities")
        suite.expect(DefaultInputSourceSupport.target(bundleID: "", rules: rules, sources: sources,
                     fallbackSourceID: "Pinyin") == nil, "empty identities never trigger the global default")
        suite.expect(DefaultInputSourceSupport.target(bundleID: "other", rules: [:], sources: sources,
                     fallbackSourceID: "Pinyin") == "Pinyin", "global defaults work without any per-app rules")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.defaultInputSourceFallback] as? String == "",
                     "updating preserves system behavior until a global default is selected")
        suite.expect(DefaultInputSourceSupport.decode(DefaultInputSourceSupport.encode(rules)) == rules,
                     "per-app preferences survive persistence, including automatic English")
        suite.expect(DefaultInputSourceSupport.decode("{broken}").isEmpty,
                     "invalid settings do not activate any app rules")
        suite.expect(DefaultInputSourceSupport.decode(#"{"":"ABC","notes":"Pinyin"}"#) == ["notes": "Pinyin"],
                     "empty app identities are rejected")
        suite.expect(AppFeature.defaultInputSource.settingsDestination.page == .defaultInputSource
                     && FeatureVisibilitySupport.features(for: .defaultInputSource) == [.defaultInputSource],
                     "default input source has a dedicated feature settings page")
        suite.expect(!AppFeature.defaultInputSource.installedByDefault
                     && AppFeature.defaultInputSource.permissions.isEmpty,
                     "default input source is opt-in and requires no accessibility permission")
        suite.expect(SettingsBackupSupport.exportKeys().isSuperset(of: [DefaultsKey.defaultInputSourceRules, DefaultsKey.defaultInputSourceFallback]),
                     "backups carry global and per-app input source choices")
    }
}
