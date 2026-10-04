//
//  DefaultGitRepository.swift
//  GitApp
//
//  Created by Valentin Bran on 03/10/2026.
//

import Foundation

nonisolated struct DefaultGitRepository: GitRepository {
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(query: String) async throws -> Git {
        guard var components = URLComponents(string: "https://api.github.com/search/repositories") else {
            throw GitRepositoryError.unknownUrl
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sort", value: "stars"),
            URLQueryItem(name: "order", value: "desc")
        ]

        guard let url = components.url else {
            throw GitRepositoryError.unknownUrl
        }

        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitRepositoryError.unknownUrl
            }

            if httpResponse.statusCode == 403 || httpResponse.statusCode == 429 {
                throw GitRepositoryError.rateLimited
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                throw GitRepositoryError.fetchFailed(statusCode: httpResponse.statusCode)
            }

            do {
                let dto = try Self.decoder.decode(GitResponseDTO.self, from: data)
                return dto.toDomain
            } catch {
                throw GitRepositoryError.decodingFailed
            }
        } catch let error as GitRepositoryError {
            throw error
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet || urlError.code == .timedOut {
            throw GitRepositoryError.networkUnavailable
        } catch {
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw error
        }
    }
}
