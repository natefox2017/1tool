// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum SuperRightClickTests {
    static func run(_ suite: TestSuite) {
        suite.expect(AppFeature.superRightClick.settingsDestination.page == .superRightClick,
                     "feature routes to its dedicated settings page")
        suite.expect(SettingsBackupSupport.exportKeys().contains(DefaultsKey.superRightClickConfiguration),
                     "custom menus travel with settings backups")
        suite.expect(AppFeature.superRightClick.enabledKeys == [DefaultsKey.superRightClickEnabled],
                     "availability and behavior use independent switches")
        var config = SuperRightClickConfiguration()
        config.order = [.copyPath, .copyPath, .directories]
        config.hiddenGroups = [.directories]
        suite.expect(config.visibleGroups == [.copyPath, .newFile, .openWith],
                     "menu order deduplicates and retains newly added groups")
        config.templates[0].content = "中文 \"quotes\" 'single' \\ slash\nnext"
        suite.expect(SuperRightClickIPC.encode(config).flatMap {
            SuperRightClickIPC.decode(SuperRightClickConfiguration.self, from: $0)
        } == config, "configuration survives IPC and persistence")
        let legacy = #"{"templates":[],"applications":[],"directories":[],"order":["copyPath"]}"#
        let restored = SuperRightClickIPC.decode(SuperRightClickConfiguration.self, from: legacy)
        suite.expect(restored?.templates.isEmpty == true && restored?.disabledApplications.isEmpty == true,
                     "old settings preserve explicit empty lists and default new app switches")
        let custom = SuperRightClickEntry(name: "Custom editor", value: "/Applications/Editor.app")
        let duplicate = SuperRightClickEntry(name: "Detected editor", value: custom.value)
        let missing = SuperRightClickEntry(name: "Missing app", value: "/Applications/Missing.app")
        let detected = SuperRightClickEntry(name: "VS Code", value: "/Applications/Visual Studio Code.app")
        let available = SuperRightClickApplications.available(custom: [custom, missing], detected: [duplicate, detected]) {
            $0 != missing.value
        }
        suite.expect(available == [custom, detected], "installed apps deduplicate while retaining custom labels")
        suite.expect(!SuperRightClickApplications.supportedBundleIDs.contains("com.apple.Safari"),
                     "discovery excludes unrelated applications")
        config.disabledApplications = [custom.id]
        suite.expect(SuperRightClickIPC.encode(config).flatMap {
            SuperRightClickIPC.decode(SuperRightClickConfiguration.self, from: $0)
        }?.disabledApplications == [custom.id], "disabled app choices persist")
        suite.expect(SuperRightClickIPC.decode(SuperRightClickRequest.self, from: "{}") == nil,
                     "incomplete requests fail closed")
        suite.expect(SuperRightClickIPC.decode(SuperRightClickConfiguration.self,
                                              from: String(repeating: "x", count: 256 * 1024 + 1)) == nil,
                     "oversized IPC is rejected")
        for name in ["", ".", "..", "../outside", "folder/name", "nul\0name", "a:b", String(repeating: "a", count: 256)] {
            suite.expect(!SuperRightClickFiles.validName(name), "unsafe file name is rejected: \(name.debugDescription)")
        }
        suite.expect(SuperRightClickFiles.validName("中文 'quoted' file.txt"), "ordinary Unicode and quoted names work")
        suite.expect(SuperRightClickFiles.directory("relative/path") == nil, "relative directories are rejected")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let original = Data("original content\n中文".utf8)
            let file = try SuperRightClickFiles.create(name: "quoted ' file.txt", in: root, content: original)
            suite.expect((try? Data(contentsOf: file)) == original, "template bytes are preserved")
            do {
                _ = try SuperRightClickFiles.create(name: file.lastPathComponent, in: root, content: Data("replacement".utf8))
                suite.expect(false, "duplicate creation must throw")
            } catch { suite.expect((try? Data(contentsOf: file)) == original, "duplicate creation preserves the existing file") }
            let link = root.appendingPathComponent("dangling.txt")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root.appendingPathComponent("missing.txt"))
            do {
                _ = try SuperRightClickFiles.create(name: "dangling.txt", in: root, content: Data())
                suite.expect(false, "dangling symlink must not be followed")
            } catch { suite.expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("missing.txt").path),
                                   "symlink target remains untouched") }
            let empty = try SuperRightClickFiles.create(name: "empty.txt", in: root, content: Data())
            suite.expect((try? Data(contentsOf: empty))?.isEmpty == true, "empty template creates an empty file")
            suite.expect(SuperRightClickFiles.directory(file.path) == nil, "files cannot be used as target directories")
            suite.expect(SuperRightClickFiles.insertionDirectory(target: file.path, selection: [file.path])?.resolvingSymlinksInPath().path == root.resolvingSymlinksInPath().path,
                         "selected file actions use its parent folder")
            suite.expect(SuperRightClickFiles.insertionDirectory(target: root.path, selection: [])?.resolvingSymlinksInPath().path == root.resolvingSymlinksInPath().path,
                         "background actions use the current folder")
            let child = root.appendingPathComponent("child")
            try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
            suite.expect(SuperRightClickFiles.insertionDirectory(target: root.path, selection: [child.path])?.resolvingSymlinksInPath().path == child.resolvingSymlinksInPath().path,
                         "selected folder actions use that folder")
        } catch { suite.expect(false, "file safety test failed: \(error)") }
    }
}
