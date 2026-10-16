// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine

/// Uses activation notifications rather than polling or intercepting typing.
final class DefaultInputSourceService: ObservableObject {
    static let shared = DefaultInputSourceService()
    @Published private(set) var failed = false
    private var activationObserver: NSObjectProtocol?
    private var preferencesObserver: NSObjectProtocol?
    private var pendingSwitch: DispatchWorkItem?
    private var enabled = false
    private var fallbackSourceID = ""
    private var rules: [String: String] = [:]

    private init() {
        preferencesObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.syncWithPreferences() }
    }

    func syncWithPreferences() {
        let nextEnabled = AppFeature.defaultInputSource.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.defaultInputSourceEnabled)
        let nextRules = DefaultInputSourceSupport.decode(
            UserDefaults.standard.string(forKey: DefaultsKey.defaultInputSourceRules) ?? "")
        let nextFallback = UserDefaults.standard.string(forKey: DefaultsKey.defaultInputSourceFallback) ?? ""
        guard enabled != nextEnabled || rules != nextRules || fallbackSourceID != nextFallback else { return }
        enabled = nextEnabled
        rules = nextRules
        fallbackSourceID = nextFallback
        if enabled {
            if activationObserver == nil {
                activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                    forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
                ) { [weak self] _ in self?.scheduleSwitch() }
            }
            scheduleSwitch()
        } else {
            stop()
        }
    }

    func stop() {
        pendingSwitch?.cancel()
        pendingSwitch = nil
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
        enabled = false
        failed = false
    }

    private func scheduleSwitch() {
        pendingSwitch?.cancel()
        failed = false
        guard enabled, let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              rules[bundleID] != nil || !fallbackSourceID.isEmpty else { return }
        let pid = app.processIdentifier
        // Let macOS finish restoring its per-document input source first.
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.enabled,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
            let target = DefaultInputSourceSupport.target(
                bundleID: bundleID, rules: self.rules, sources: InputSourceSelection.snapshots(),
                fallbackSourceID: self.fallbackSourceID.isEmpty ? nil : self.fallbackSourceID)
            self.failed = !DefaultInputSourceSupport.apply(
                target: target, currentID: InputSourceSelection.currentSourceID(),
                clearCapsLock: DefaultInputSourceCapsLock.clear,
                select: { target in
                    guard InputSourceSelection.select(sourceID: target) else { return false }
                    if AppFeature.notch.isAvailable { NotchService.shared.noteOwnInputSourceSwitch(to: target) }
                    return true
                })
        }
        pendingSwitch = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }
}
