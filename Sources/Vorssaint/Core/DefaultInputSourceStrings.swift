// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum DefaultInputSourceStrings {
    static func text(_ key: String, language: AppLanguage = L10n.shared.language) -> String {
        let pair: (String, String)
        switch key {
        case "title": pair = ("默认输入法", "Default Input Source")
        case "description": pair = ("切入应用时使用全局默认或该应用的指定输入法，并关闭大写锁定。", "Apply a global or per-app input source and turn off Caps Lock when entering an app.")
        case "enabled": pair = ("启用默认输入法", "Enable default input sources")
        case "hint": pair = ("切入应用时应用默认输入法并关闭大写锁定，之后可自由手动切换。应用单独设置优先，其余应用使用全局默认。", "Applies the input source and turns off Caps Lock only when entering an app; you can switch manually afterwards. Per-app choices override the global default.")
        case "global": pair = ("全局默认输入法", "Global default input source")
        case "system": pair = ("跟随系统", "Follow system")
        case "globalHint": pair = ("未单独设置的应用使用此输入法。选择“跟随系统”则不主动切换这些应用。", "Apps without an override use this input source. Choose Follow system to leave those apps unchanged.")
        case "apps": pair = ("应用与默认输入法", "Apps and default input sources")
        case "add": pair = ("添加应用…", "Add App…")
        case "remove": pair = ("移除应用", "Remove app")
        case "empty": pair = ("添加需要默认英文或中文输入法的应用。", "Add apps that should default to an English or Chinese input source.")
        case "source": pair = ("默认输入法", "Default input source")
        case "automatic": pair = ("自动选择英文键盘", "Automatic English keyboard")
        case "missing": pair = ("此输入法已停用或移除，请重新选择。", "This input source is disabled or removed. Choose another one.")
        case "noEnglish": pair = ("未找到英文键盘，请先在系统设置 → 键盘 → 输入法中添加 ABC 或其他英文键盘。", "No English keyboard is enabled. Add ABC or another English keyboard in System Settings → Keyboard → Input Sources.")
        case "bilingual": pair = ("自动英文使用独立的英文键盘，不设置第三方双语输入法内部的中英文模式；手动切换遵循输入法自身的快捷键。", "Automatic English uses a separate English keyboard. Bilingual input methods manage their own language mode and shortcuts.")
        case "failed": pair = ("未能应用输入法或关闭大写锁定，请检查输入法是否仍已启用后重试。", "Could not apply the input source or turn off Caps Lock. Check that the source is still enabled and try again.")
        default: pair = (key, key)
        }
        return language.rawValue.hasPrefix("zh") ? pair.0 : pair.1
    }
}
