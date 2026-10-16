// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import AppKit
import FinderSync

struct SuperRightClickSettings: View {
    @ObservedObject private var service = SuperRightClickService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.superRightClickEnabled) private var enabled = false
    @State private var editingTemplate: SuperRightClickEntry?
    @State private var extensionEnabled = FIFinderSyncController.isExtensionEnabled

    private func text(_ zh: String, _ en: String) -> String { service.text(zh, en) }

    var body: some View {
        Form {
            Section {
                if let error = service.error {
                    Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red)
                }
                Toggle(text("启用超级右键", "Enable Super Right Click"), isOn: $enabled)
                    .onChange(of: enabled) { _, _ in service.syncWithPreferences() }
                HStack {
                    Label(extensionEnabled
                          ? text("Finder 扩展已启用", "Finder extension enabled")
                          : text("需要启用 Finder 扩展", "Enable the Finder extension"),
                          systemImage: extensionEnabled ? "checkmark.circle" : "exclamationmark.circle")
                    Spacer()
                    Button(text("管理扩展…", "Manage Extensions…")) {
                        FIFinderSyncController.showExtensionManagementInterface()
                    }
                }
                Text(text("在系统扩展设置中启用 \(AppInfo.name) 的 Finder 扩展。菜单在 Finder 文件、文件夹和目录空白处可用；\(AppInfo.name) 需保持运行。",
                          "Enable \(AppInfo.name)’s Finder extension in System Settings. Menus work on Finder items and folder backgrounds while \(AppInfo.name) is running."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(text("菜单项目与顺序", "Menu Items & Order")) {
                ForEach(service.configuration.order) { group in
                    HStack {
                        Toggle(group.title(chinese: service.chinese), isOn: Binding(
                            get: { !service.configuration.hiddenGroups.contains(group) },
                            set: { visible in
                                service.configuration.hiddenGroups.removeAll { $0 == group }
                                if !visible { service.configuration.hiddenGroups.append(group) }
                            }))
                        Spacer()
                        Button { moveGroup(group, by: -1) } label: { Image(systemName: "chevron.up") }
                            .disabled(service.configuration.order.first == group)
                            .accessibilityLabel(text("上移", "Move Up") + " " + group.title(chinese: service.chinese))
                        Button { moveGroup(group, by: 1) } label: { Image(systemName: "chevron.down") }
                            .disabled(service.configuration.order.last == group)
                            .accessibilityLabel(text("下移", "Move Down") + " " + group.title(chinese: service.chinese))
                    }
                }
                Toggle(text("提供隐藏文件显示切换", "Include Show / Hide Hidden Files"),
                       isOn: $service.configuration.showHiddenToggle)
                Text(text("此操作切换 Finder 对隐藏文件的显示，并重新启动 Finder，不改变文件的隐藏属性。",
                          "This switches visibility of hidden files and restarts Finder; file attributes are unchanged."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(text("新建文件模板", "New File Templates")) {
                ForEach(service.configuration.templates) { entry in
                    HStack(alignment: .center, spacing: 12) {
                        Text(entry.name)
                            .lineLimit(1).truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("." + entry.value)
                            .foregroundStyle(.secondary).lineLimit(1)
                            .frame(width: 80, alignment: .leading)
                        Button { editingTemplate = entry } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .help(text("编辑模板", "Edit Template"))
                        .accessibilityLabel(text("编辑模板", "Edit Template") + " " + entry.name)
                        removeButton(name: entry.name) {
                            service.configuration.templates.removeAll { $0.id == entry.id }
                        }
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 28)
                }
                Button(text("添加模板…", "Add Template…")) {
                    editingTemplate = SuperRightClickTemplatePreset.txt.entry
                }.disabled(service.configuration.templates.count >= 32)
            }
            Section(text("常用目录", "Favorite Folders")) {
                ForEach($service.configuration.directories) { $entry in
                    entryRow($entry) { service.configuration.directories.removeAll { $0.id == entry.id } }
                }
                Button(text("添加目录…", "Add Folder…")) { choosePath(application: false) }
                    .disabled(service.configuration.directories.count >= 32)
            }
            Section(text("快捷打开软件", "Open Apps Here")) {
                ForEach(service.availableApplications) { entry in
                    HStack(spacing: 12) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: entry.value))
                            .resizable().frame(width: 24, height: 24).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.name)
                            Text(entry.value).font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Text(service.configuration.disabledApplications.contains(entry.id)
                             ? text("已关闭", "Off") : text("已启用", "On"))
                            .font(.caption).foregroundStyle(.secondary)
                        Toggle("", isOn: Binding(
                            get: { !service.configuration.disabledApplications.contains(entry.id) },
                            set: { active in
                                service.configuration.disabledApplications.removeAll { $0 == entry.id }
                                if !active { service.configuration.disabledApplications.append(entry.id) }
                            })).labelsHidden().fixedSize()
                            .accessibilityLabel(text("启用软件入口", "Enable App Shortcut") + " " + entry.name)
                        if !service.detectedApplications.contains(where: { $0.value == entry.value }) {
                            removeButton(name: entry.name) {
                                service.configuration.applications.removeAll { $0.id == entry.id }
                            }
                        }
                    }
                }
                if service.availableApplications.isEmpty {
                    Text(text("未检测到可用软件，可以手动添加。", "No supported apps found. Add an app manually."))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button(text("刷新已安装软件", "Refresh Installed Apps")) { service.refreshApplications() }
                    Spacer()
                    Button(text("添加其他软件…", "Add Other App…")) { choosePath(application: true) }
                        .disabled(service.configuration.applications.count >= 32)
                }
                Text(text("只自动显示本机已安装的常用终端、代码编辑器和 IDE；其他软件可手动添加。关闭某个入口后，它不会出现在右键菜单中。",
                          "Only installed terminals, code editors and IDEs are detected automatically. Other apps can be added manually. Disabled shortcuts stay out of Finder menus."))
                    .font(.caption).foregroundStyle(.secondary)
                Text(text("Terminal 和 iTerm2 会进入当前目录；其他软件接收当前目录。终端首次使用时可能请求自动化权限。",
                          "Terminal and iTerm2 start in the current folder; other apps receive that folder. Terminal actions may request Automation access."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editingTemplate) { entry in
            SuperRightClickTemplateEditor(
                entry: entry, chinese: service.chinese,
                isNew: !service.configuration.templates.contains { $0.id == entry.id }
            ) { saved in
                if let index = service.configuration.templates.firstIndex(where: { $0.id == saved.id }) {
                    service.configuration.templates[index] = saved
                } else if service.configuration.templates.count < 32 {
                    service.configuration.templates.append(saved)
                }
            }
        }
        .onAppear { service.refreshApplications() }
        .onChange(of: service.configuration) { _, _ in service.save() }
        .onChange(of: l10n.language) { _, _ in service.syncWithPreferences() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            extensionEnabled = FIFinderSyncController.isExtensionEnabled
        }
    }

    private func entryRow(_ entry: Binding<SuperRightClickEntry>, remove: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                TextField(text("菜单名称", "Menu Name"), text: entry.name).labelsHidden()
                    .accessibilityLabel(text("菜单名称", "Menu Name") + " " + entry.wrappedValue.name)
                Text(entry.wrappedValue.value).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2).truncationMode(.middle).textSelection(.enabled)
            }
            Spacer()
            removeButton(name: entry.wrappedValue.name, action: remove)
        }
    }
    private func removeButton(name: String, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) { Image(systemName: "minus.circle") }
            .accessibilityLabel(text("移除项目", "Remove Item") + " " + name)
    }
    private func moveGroup(_ group: SuperRightClickGroup, by offset: Int) {
        guard let index = service.configuration.order.firstIndex(of: group),
              service.configuration.order.indices.contains(index + offset) else { return }
        service.configuration.order.swapAt(index, index + offset)
    }
    private func choosePath(application: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = application
        panel.canChooseDirectories = !application
        panel.allowsMultipleSelection = true
        if application { panel.allowedContentTypes = [.applicationBundle] }
        panel.message = application ? text("选择右键打开的软件", "Choose Apps to Open Here")
                                    : text("选择常用目录", "Choose Favorite Folders")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            let entry = SuperRightClickEntry(name: FileManager.default.displayName(atPath: url.path), value: url.path)
            if application {
                if service.configuration.applications.count < 32,
                   !service.configuration.applications.contains(where: { $0.value == url.path }) {
                    service.configuration.applications.append(entry)
                }
            } else if service.configuration.directories.count < 32,
                      !service.configuration.directories.contains(where: { $0.value == url.path }) {
                service.configuration.directories.append(entry)
            }
        }
    }
}
