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
        suite.expect(SuperRightClickTemplates.normalizedExtension(" .MD ") == "md",
                     "extensions normalize pasted dots, whitespace and case")
        for invalid in ["", ".", "../html", "a/b", "bad ext", "xls\0", "x;y", String(repeating: "x", count: 33)] {
            suite.expect(!SuperRightClickTemplates.validExtension(invalid), "unsafe template extension is rejected")
        }
        let presets = SuperRightClickTemplatePreset.allCases.filter { $0 != .custom }
        suite.expect(["txt", "md", "html", "js", "docx", "xlsx"].allSatisfy { value in
            presets.contains { $0.entry.value == value }
        }, "common file types are offered in the template editor")
        suite.expect(presets.allSatisfy { SuperRightClickTemplates.validExtension($0.entry.value) },
                     "every built-in template has a valid extension")
        let resources = URL(fileURLWithPath: "Resources/FileTemplates", isDirectory: true)
        do {
            let html = try SuperRightClickTemplates.data(for: SuperRightClickTemplatePreset.html.entry,
                                                       resourceDirectory: resources)
            suite.expect(String(data: html, encoding: .utf8)?.hasPrefix("<!DOCTYPE html>") == true,
                         "HTML preset writes its actual starter content")
            for type in [SuperRightClickTemplatePreset.docx, .xlsx] {
                let data = try SuperRightClickTemplates.data(for: type.entry, resourceDirectory: resources)
                suite.expect(data.starts(with: [0x50, 0x4b, 0x03, 0x04]),
                             "Office templates write a document package, not an empty renamed text file")
            }
            do {
                _ = try SuperRightClickTemplates.data(for: SuperRightClickTemplatePreset.xlsx.entry,
                                                     resourceDirectory: nil)
                suite.expect(false, "missing Office resources must fail instead of writing a corrupt file")
            } catch { suite.expect(true, "missing Office resources fail closed") }
        } catch { suite.expect(false, "template data generation failed: \(error)") }
        let external = URL(fileURLWithPath: "/Volumes/External Drive")
        let scopes = SuperRightClickScope.directories(volumes: [external, external])
        suite.expect(scopes.contains(external) && scopes.contains(URL(fileURLWithPath: "/")),
                     "external volumes have explicit scopes alongside the startup disk")
        suite.expect(scopes.contains(URL(fileURLWithPath: "/System/Volumes/Data")),
                     "the APFS data volume has its own scope")
        suite.expect(!SuperRightClickScope.directories(volumes: []).contains(external),
                     "refreshing after unmount removes the old volume scope")
        let selectedURL = external.appendingPathComponent("tagged.txt")
        suite.expect(SuperRightClickScope.target(targeted: nil, selection: [selectedURL]) == selectedURL,
                     "tag item menus use the selected file when no directory target exists")
        suite.expect(SuperRightClickScope.target(targeted: URL(string: "search://tags"),
                                                selection: [selectedURL]) == selectedURL,
                     "virtual targets do not hide menus for real selected files")
        suite.expect(SuperRightClickScope.target(targeted: nil, selection: []) == nil,
                     "virtual backgrounds without a real location do not invent a directory")
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
            suite.expect(SuperRightClickFiles.insertionDirectory(
                target: root.appendingPathComponent("virtual/missing.savedSearch").path,
                selection: [file.path])?.resolvingSymlinksInPath().path == root.resolvingSymlinksInPath().path,
                         "tag and search selections resolve the actual containing directory")
            let child = root.appendingPathComponent("child")
            try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
            suite.expect(SuperRightClickFiles.insertionDirectory(target: root.path, selection: [child.path])?.resolvingSymlinksInPath().path == child.resolvingSymlinksInPath().path,
                         "selected folder actions use that folder")
        } catch { suite.expect(false, "file safety test failed: \(error)") }
    }
}
