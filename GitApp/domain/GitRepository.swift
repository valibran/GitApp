//
//  GitRepository.swift
//  GitApp
//
//  Created by Valentin Bran on 03/10/2026.
//

import Foundation

enum GitRepositoryError: LocalizedError, Equatable {
    case rateLimited
    case fetchFailed(statusCode: Int)
    case decodingFailed
    case unknownUrl
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let code):
            return "Request failed with status code \(code)."
        case .decodingFailed:
            return "Unable to parse data from GitHub."
        case .unknownUrl:
            return "Invalid search URL."
        case .rateLimited:
            return "GitHub rate limit reached (10 requests/min). Please wait a moment."
        case .networkUnavailable:
            return "Network connection appears to be offline. Please check your connection."
        }
    }
}

protocol GitRepository: Sendable {
    
    /// Fetch the git data
    /// - Parameter query: The search query
    /// - Returns: The domain response
    func fetch(query: String) async throws -> Git
}
