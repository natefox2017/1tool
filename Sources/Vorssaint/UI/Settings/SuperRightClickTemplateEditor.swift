// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct SuperRightClickTemplateEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entry: SuperRightClickEntry
    @State private var preset: SuperRightClickTemplatePreset
    let chinese: Bool
    let isNew: Bool
    let save: (SuperRightClickEntry) -> Void

    init(entry: SuperRightClickEntry, chinese: Bool, isNew: Bool,
         save: @escaping (SuperRightClickEntry) -> Void) {
        _entry = State(initialValue: entry)
        _preset = State(initialValue: SuperRightClickTemplatePreset(
            rawValue: SuperRightClickTemplates.normalizedExtension(entry.value)) ?? .custom)
        self.chinese = chinese
        self.isNew = isNew
        self.save = save
    }

    private func text(_ zh: String, _ en: String) -> String { chinese ? zh : en }
    private var office: Bool { SuperRightClickTemplates.isOffice(entry.value) }
    private var valid: Bool {
        !entry.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && entry.name.utf8.count <= 255
            && SuperRightClickTemplates.validExtension(entry.value)
            && entry.content.utf8.count <= 64 * 1024
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(isNew ? text("添加模板", "Add Template") : text("编辑模板", "Edit Template"))
                .font(.headline)
            Form {
                Picker(text("文件类型", "File Type"), selection: $preset) {
                    ForEach(SuperRightClickTemplatePreset.allCases) { type in
                        Text(type == .custom ? text("自定义", "Custom") : type.title).tag(type)
                    }
                }
                .onChange(of: preset) { _, type in
                    let replacement = type.entry
                    entry.name = replacement.name
                    entry.value = replacement.value
                    entry.content = replacement.content
                }
                TextField(text("模板名称", "Template Name"), text: $entry.name)
                TextField(text("扩展名", "Extension"), text: $entry.value,
                          prompt: Text(text("例如 txt，不含句点", "e.g. txt, without a dot")))
                    .disabled(preset != .custom)
            }
            .formStyle(.columns)
            .textFieldStyle(.roundedBorder)

            if office {
                Label(text("创建可直接打开的空白 Office 文档。", "Creates a valid blank Office document."),
                      systemImage: "doc")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(text("初始内容（可留空）", "Initial Content (optional)"))
                        .font(.callout)
                    TextEditor(text: $entry.content)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(height: 120)
                        .background(.background, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                        .accessibilityLabel(text("初始内容", "Initial Content"))
                }
            }
            if !entry.value.isEmpty && !SuperRightClickTemplates.validExtension(entry.value) {
                Text(text("扩展名只能包含英文字母、数字、短横线或下划线。", "Use letters, numbers, hyphens or underscores for the extension."))
                    .font(.caption).foregroundStyle(.red)
            }
            if entry.content.utf8.count > 64 * 1024 {
                Text(text("初始内容过长，请缩短后保存。", "Initial content is too long. Shorten it to save."))
                    .font(.caption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button(text("取消", "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? text("添加", "Add") : text("保存", "Save")) {
                    var saved = entry
                    saved.name = saved.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    saved.value = SuperRightClickTemplates.normalizedExtension(saved.value)
                    if office { saved.content = "" }
                    save(saved)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!valid)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}
