// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum DefaultInputSourceSupport {
    /// Empty source ID means choose an enabled ASCII keyboard layout.
    static func decode(_ raw: String) -> [String: String] {
        guard let data = raw.data(using: .utf8),
              let rules = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return rules.filter { !$0.key.isEmpty }
    }

    static func encode(_ rules: [String: String]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(rules) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func apply(target: String?, currentID: String?,
                      clearCapsLock: () -> Bool, select: (String) -> Bool) -> Bool {
        let capsCleared = clearCapsLock()
        guard let target else { return false }
        let sourceSelected = target == currentID || select(target)
        return sourceSelected && capsCleared
    }

    static func target(bundleID: String?, rules: [String: String],
                       sources: [InputSourceSelection.Snapshot],
                       fallbackSourceID: String? = nil) -> String? {
        guard let bundleID, !bundleID.isEmpty,
              let sourceID = rules[bundleID] ?? fallbackSourceID else { return nil }
        if sourceID.isEmpty {
            return sources.first { $0.isLayout && $0.isASCIICapable }?.id
        }
        // A removed or disabled input source must never switch to an unrelated one.
        return sources.first { $0.id == sourceID }?.id
    }
}
