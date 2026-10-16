// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import FinderSync

final class SuperRightClickService: NSObject, ObservableObject {
    static let shared = SuperRightClickService()
    @Published var configuration: SuperRightClickConfiguration
    @Published private(set) var error: String?
    @Published private(set) var detectedApplications: [SuperRightClickEntry] = []
    private let token = UUID().uuidString
    private let workQueue = DispatchQueue(label: "com.vorssaint.utils.super-right-click.actions")
    private var busy = false
    private var started = false
    private var lastPublished: SuperRightClickConfiguration?

    override init() {
        configuration = SuperRightClickIPC.decode(
            SuperRightClickConfiguration.self,
            from: UserDefaults.standard.string(forKey: DefaultsKey.superRightClickConfiguration))
            ?? .initial(home: FileManager.default.homeDirectoryForCurrentUser)
        super.init()
    }
    var chinese: Bool { L10n.shared.language.rawValue.hasPrefix("zh") }
    func text(_ zh: String, _ en: String) -> String { chinese ? zh : en }
    var availableApplications: [SuperRightClickEntry] {
        SuperRightClickApplications.available(custom: configuration.applications,
                                              detected: detectedApplications) {
            FileManager.default.fileExists(atPath: $0)
                && Bundle(url: URL(fileURLWithPath: $0))?.bundleIdentifier != nil
        }
    }
    private var activeApplications: [SuperRightClickEntry] {
        availableApplications.filter { !configuration.disabledApplications.contains($0.id) }
    }
    func refreshApplications() {
        let installed = SuperRightClickApplications.supportedBundleIDs.compactMap { id -> SuperRightClickEntry? in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id),
                  Bundle(url: url)?.bundleIdentifier == id else { return nil }
            return SuperRightClickEntry(id: "detected:" + id,
                                       name: FileManager.default.displayName(atPath: url.path), value: url.path)
        }
        if installed != detectedApplications { detectedApplications = installed }
        syncWithPreferences()
    }

    func start() {
        guard !started else { return }
        started = true
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(requestConfiguration(_:)), name: SuperRightClickIPC.request, object: nil)
        center.addObserver(self, selector: #selector(receiveAction(_:)), name: SuperRightClickIPC.action, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesChanged(_:)),
                                               name: UserDefaults.didChangeNotification, object: nil)
        refreshApplications()
    }
    func stop() {
        guard started else { return }
        var disabled = configuration
        disabled.enabled = false
        publish(disabled)
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        started = false
    }
    func save() {
        if let raw = SuperRightClickIPC.encode(configuration) {
            guard raw.utf8.count <= 256 * 1024 else {
                error = text("模板内容过大，请缩短后再保存。", "Template content is too large. Shorten it to save.")
                return
            }
            UserDefaults.standard.set(raw, forKey: DefaultsKey.superRightClickConfiguration)
            error = nil
        }
        syncWithPreferences()
    }
    func syncWithPreferences(force: Bool = false) {
        guard AppFeature.superRightClick.isAvailable else { stop(); return }
        guard started else { start(); return }
        var value = configuration
        value.enabled = AppFeature.superRightClick.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.superRightClickEnabled)
        value.chinese = chinese
        value.token = token
        value.applications = activeApplications
        publish(value, force: force)
    }
    private func publish(_ value: SuperRightClickConfiguration, force: Bool = false) {
        guard force || value != lastPublished else { return }
        guard let raw = SuperRightClickIPC.encode(value) else { return }
        lastPublished = value
        DistributedNotificationCenter.default().postNotificationName(
            SuperRightClickIPC.configuration, object: raw, userInfo: nil, deliverImmediately: true)
    }
    @objc private func requestConfiguration(_ notification: Notification) {
        refreshApplications()
        syncWithPreferences(force: true)
    }
    @objc private func preferencesChanged(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.preferencesChanged(notification) }
            return
        }
        if let saved = SuperRightClickIPC.decode(SuperRightClickConfiguration.self,
               from: UserDefaults.standard.string(forKey: DefaultsKey.superRightClickConfiguration)),
           saved != configuration {
            configuration = saved
        }
        syncWithPreferences()
    }

    @objc private func receiveAction(_ notification: Notification) {
        guard let request = SuperRightClickIPC.decode(SuperRightClickRequest.self, from: notification.object),
              request.token == token, AppFeature.superRightClick.isAvailable,
              UserDefaults.standard.bool(forKey: DefaultsKey.superRightClickEnabled),
              request.selection.count <= 1000,
              request.selection.allSatisfy({ $0.hasPrefix("/") && !$0.contains("\0") }),
              let directory = SuperRightClickFiles.insertionDirectory(target: request.directory,
                                                                       selection: request.selection) else { return }
        let config = configuration
        let group: SuperRightClickGroup
        switch request.action {
        case "newFile": group = .newFile
        case "directory": group = .directories
        case "copyPath": group = .copyPath
        case "application", "hiddenFiles": group = .openWith
        default: return
        }
        guard config.visibleGroups.contains(group) else { return }
        switch request.action {
        case "copyPath":
            let paths = request.selection.isEmpty ? [directory.path] : request.selection
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
        case "newFile":
            guard !busy else { return }
            let template = config.templates.first { $0.id == request.entryID }
            guard request.entryID == nil || template != nil else { return }
            createFile(in: directory, template: template)
        case "directory":
            guard let entry = config.directories.first(where: { $0.id == request.entryID }),
                  let folder = SuperRightClickFiles.directory(entry.value) else {
                fail(text("常用目录不存在或无法访问。", "The favorite folder is missing or inaccessible.")); return
            }
            if !NSWorkspace.shared.open(folder) { fail(text("无法打开目录。", "Could not open the folder.")) }
        case "application":
            guard let entry = activeApplications.first(where: { $0.id == request.entryID }) else { return }
            openApplication(entry, directory: directory)
        case "hiddenFiles":
            guard config.showHiddenToggle else { return }
            QuickTogglesService.shared.toggleHiddenFiles(authorizedBy: .superRightClick)
        default: break
        }
    }

    private func createFile(in directory: URL, template: SuperRightClickEntry?) {
        busy = true
        defer { busy = false }
        let alert = NSAlert()
        alert.messageText = text("新建文件", "New File")
        alert.informativeText = directory.path
        let field = NSTextField(string: template.map { "Untitled." + $0.value } ?? "Untitled.txt")
        field.frame = NSRect(x: 0, y: 0, width: 340, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: text("创建", "Create"))
        alert.addButton(withTitle: text("取消", "Cancel"))
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            let url = try SuperRightClickFiles.create(name: field.stringValue, in: directory,
                                                     content: Data((template?.content ?? "").utf8))
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch { fail(error.localizedDescription) }
    }

    private func openApplication(_ entry: SuperRightClickEntry, directory: URL) {
        let app = URL(fileURLWithPath: entry.value)
        guard app.pathExtension == "app", let bundle = Bundle(url: app) else {
            fail(text("软件不存在，请重新选择。", "The app is missing. Choose it again.")); return
        }
        let id = bundle.bundleIdentifier
        if id == "com.apple.Terminal" || id == "com.googlecode.iterm2" {
            // Shell quoting and AppleScript quoting are separate trust boundaries.
            let command = "cd -- " + HomebrewCommandBuilder.shellQuote(directory.path)
            let literal = "\"" + command.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r") + "\""
            let source: String
            if id == "com.apple.Terminal" {
                source = "tell application id \"com.apple.Terminal\"\nactivate\ndo script \(literal)\nend tell"
            } else {
                source = """
                tell application id "com.googlecode.iterm2"
                    activate
                    set newWindow to (create window with default profile)
                    tell current session of newWindow to write text \(literal)
                end tell
                """
            }
            workQueue.async {
                let result = AppleScriptRunner.runDetailed(source)
                if !result.ok { DispatchQueue.main.async { self.fail(result.message) } }
            }
        } else {
            NSWorkspace.shared.open([directory], withApplicationAt: app,
                                    configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error { DispatchQueue.main.async { self.fail(error.localizedDescription) } }
            }
        }
    }
    private func fail(_ message: String) {
        error = message
        let alert = NSAlert()
        alert.messageText = text("超级右键", "Super Right Click")
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
