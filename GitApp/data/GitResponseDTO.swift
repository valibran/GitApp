//
//  GitResponseDTO.swift
//  GitApp
//
//  Created by Valentin Bran on 03/10/2026.
//
import Foundation

struct GitResponseDTO: Codable, Equatable {
    let totalCount: Int
    let items: [GitItemDTO]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }
}

struct GitItemDTO: Codable, Equatable {
    let id: Int
    let name: String
    let description: String?
    let stargazersCount: Int
    let htmlUrl: String
    let language: String?
    let owner: GitUserDTO
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case stargazersCount = "stargazers_count"
        case htmlUrl = "html_url"
        case language
        case owner
        case updatedAt = "updated_at"
    }
}

struct GitUserDTO: Codable, Equatable {
    let login: String
    let avatarUrl: String

    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

extension GitResponseDTO {
    var toDomain: Git {
        Git(
            total: totalCount,
            items: items.map { $0.toDomain }
        )
    }
}

extension GitItemDTO {
    var toDomain: GitItem {
        GitItem(
            id: id,
            name: name,
            description: description ?? "",
            stargazersCount: stargazersCount,
            htmlURL: URL(string: htmlUrl),
            language: language ?? "",
            ownerName: owner.login,
            ownerAvatarURL: URL(string: owner.avatarUrl),
            updatedAt: updatedAt
        )
    }
}
