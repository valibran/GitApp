//
//  Git.swift
//  GitApp
//
//  Created by Valentin Bran on 03/10/2026.
//

import Foundation

struct Git {
    let total: Int
    let items: [GitItem]
}

struct GitItem: Identifiable, Equatable, Hashable, Sendable {
    let id: Int
    let name: String
    let description: String
    let stargazersCount: Int
    let htmlURL: URL?
    let language: String
    let ownerName: String
    let ownerAvatarURL: URL?
    let updatedAt: Date?

    var formattedStars: String {
        stargazersCount.formatted(.number.notation(.compactName))
    }

    /// Formatted calendar date, e.g. "Oct 4, 2026"
    var formattedUpdatedDate: String? {
        guard let updatedAt else { return nil }
        return updatedAt.formatted(date: .abbreviated, time: .omitted)
    }

    /// Relative timestamp, e.g. "Updated yesterday" or "Updated 2 hours ago"
    var relativeUpdatedDate: String? {
        guard let updatedAt else { return nil }
        return "Updated \(updatedAt.formatted(.relative(presentation: .named)))"
    }
}

extension GitItem {
    static let sample = GitItem(
        id: 1,
        name: "swift",
        description: "The Swift Programming Language",
        stargazersCount: 65000,
        htmlURL: URL(string: "https://github.com/apple/swift"),
        language: "Swift",
        ownerName: "apple",
        ownerAvatarURL: URL(string: "https://avatars.githubusercontent.com/u/10639145?v=4"),
        updatedAt: Date(timeIntervalSince1970: 1700000000)
    )
}
