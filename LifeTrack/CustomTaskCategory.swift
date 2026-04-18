//
//  CustomTaskCategory.swift
//  LifeTrack
//
//  Created by Halalisani Mbanjwa on 2026/04/18.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class CustomTaskCategory {
    @Attribute(.unique) var id: UUID
    var title: String
    var symbolName: String
    var colorHex: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        symbolName: String,
        colorHex: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    var rawValue: String {
        "custom:\(id.uuidString)"
    }
}

@MainActor
struct TaskCategoryOption: Identifiable {
    let id: String
    let title: String
    let symbolName: String
    let tint: Color

    var background: Color {
        tint.opacity(0.12)
    }

    var border: Color {
        tint.opacity(0.24)
    }

    static func builtIn(_ category: TaskCategory) -> TaskCategoryOption {
        TaskCategoryOption(
            id: category.rawValue,
            title: category.title,
            symbolName: category.symbolName,
            tint: category.style.tint
        )
    }

    static func custom(_ category: CustomTaskCategory) -> TaskCategoryOption {
        let baseColor = Color(hex: UInt(category.colorHex))
        return TaskCategoryOption(
            id: category.rawValue,
            title: category.title,
            symbolName: category.symbolName,
            tint: baseColor.mixed(with: LifeTrackTheme.ColorPalette.accent, amount: 0.10)
        )
    }

    static func all(customCategories: [CustomTaskCategory]) -> [TaskCategoryOption] {
        TaskCategory.allCases.map(TaskCategoryOption.builtIn)
            + customCategories
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                .map(TaskCategoryOption.custom)
    }

    static func resolved(rawValue: String, customCategories: [CustomTaskCategory]) -> TaskCategoryOption {
        if let builtIn = TaskCategory(rawValue: rawValue) {
            return .builtIn(builtIn)
        }

        if let custom = customCategories.first(where: { $0.rawValue == rawValue }) {
            return .custom(custom)
        }

        return .builtIn(.other)
    }
}

extension LifeTask {
    @MainActor
    func categoryOption(customCategories: [CustomTaskCategory]) -> TaskCategoryOption {
        TaskCategoryOption.resolved(rawValue: categoryRawValue, customCategories: customCategories)
    }
}
