//
//  GitAppTests.swift
//  GitAppTests
//
//  Created by Valentin Bran on 03/10/2026.
//

import Foundation
import Observation
import Testing
@testable import GitApp

@Suite("GitViewModel Presentation Tests")
@MainActor
struct GitViewModelTests {

    private let sampleItem = GitItem.sample

    @Test func viewModelSuccess() async throws {
        // Given
        let repo = MockRepo(delay: .zero)
        let sut = GitViewModel(repository: repo, debounce: .zero)

        // When
        sut.query = "swift"
        _ = await sut.task?.value

        // Then
        #expect(sut.state == .success([sampleItem]))
    }

    @Test func viewModelEmpty() async throws {
        // Given
        let repo = MockRepo(delay: .zero)
        let sut = GitViewModel(repository: repo, debounce: .zero)

        // When
        sut.query = "nothing"
        _ = await sut.task?.value

        // Then
        #expect(sut.state == .empty)
    }

    @Test func viewModelClearingQueryResetsToIdle() async throws {
        // Given: SUT starts with search results
        let repo = MockRepo(delay: .zero)
        let sut = GitViewModel(repository: repo, debounce: .zero)
        sut.query = "swift"
        _ = await sut.task?.value
        #expect(sut.state == .success([sampleItem]))

        // When: User clears search field or types whitespace
        sut.query = "   "

        // Then: State resets immediately to idle without network call
        #expect(sut.state == .idle)
        #expect(sut.task == nil)
    }

    @Test func viewModelSubmitSearchBypassesDebounce() async throws {
        // Given: SUT configured with a 10-second debounce
        let repo = MockRepo(delay: .zero)
        let sut = GitViewModel(repository: repo, debounce: .seconds(10))
        sut.query = "swift"

        // When: User explicitly presses Search on keyboard
        sut.submitSearch()
        _ = await sut.task?.value

        // Then: Immediately resolves to success without waiting 10s
        #expect(sut.state == .success([sampleItem]))
    }

    @Test func viewModelPullToRefreshAwaitsCompletion() async throws {
        // Given
        let repo = MockRepo(delay: .zero)
        let sut = GitViewModel(repository: repo, debounce: .seconds(5))
        sut.query = "swift"

        // When: Pull to refresh is invoked
        await sut.refresh()

        // Then: Fetched data is ready when refresh() returns
        #expect(sut.state == .success([sampleItem]))
    }

    @Test(.timeLimit(.minutes(1)))
    func viewModelErrorUsingObservations() async throws {
        // Given
        let repo = MockRepo(delay: .zero, isError: true)
        let sut = GitViewModel(repository: repo, debounce: .zero)

        // When
        sut.query = "swift"

        // Then: Verify reactive observation via Swift 6 Observations AsyncSequence
        await confirmation("Transition to error state", expectedCount: 1) { confirm in
            for await state in Observations({ sut.state }) {
                switch state {
                case .idle, .loading:
                    continue
                case .error(let message):
                    #expect(!message.isEmpty)
                    confirm()
                    return
                case .success, .empty:
                    Issue.record("Unexpected terminal state: \(state)")
                    return
                }
            }
        }
    }

    @Test func viewModelRetryRecoversImmediately() async throws {
        // Given: Repo starts in error state
        let repo = MockRepo(delay: .zero, isError: true)
        let sut = GitViewModel(repository: repo, debounce: .zero)
        sut.query = "swift"
        _ = await sut.task?.value
        #expect(sut.state != .idle)

        // When: Repo becomes healthy and retry is tapped
        repo.isError = false
        sut.retry()
        _ = await sut.task?.value

        // Then: State recovers to success without debouncing
        #expect(sut.state == .success([sampleItem]))
    }
}

@Suite("DefaultGitRepository Network & Parsing Tests", .serialized)
struct DefaultGitRepositoryTests {

    private func makeSUT(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> (sut: DefaultGitRepository, session: URLSession) {
        MockURLProtocol.requestHandler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return (DefaultGitRepository(session: session), session)
    }

    @Test func fetchSuccessConstructsURLAndHeaders() async throws {
        var capturedRequest: URLRequest?

        let (sut, _) = makeSUT { request in
            capturedRequest = request
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = """
            {
                "total_count": 1,
                "items": [
                    {
                        "id": 42,
                        "name": "Antigravity",
                        "description": "Smart Assistant",
                        "stargazers_count": 1500,
                        "html_url": "https://github.com/google/antigravity",
                        "language": "Swift",
                        "owner": {
                            "login": "google",
                            "avatar_url": "https://github.com/google.png"
                        },
                        "updated_at": "2026-10-04T10:36:31Z"
                    }
                ]
            }
            """
            return (response, Data(json.utf8))
        }

        let result = try await sut.fetch(query: "swift ai")

        #expect(result.total == 1)
        #expect(result.items.count == 1)
        let item = try #require(result.items.first)
        #expect(item.id == 42)
        #expect(item.name == "Antigravity")
        #expect(item.stargazersCount == 1500)
        #expect(!item.formattedStars.isEmpty)
        #expect(item.ownerAvatarURL?.absoluteString == "https://github.com/google.png")
        #expect(item.updatedAt != nil)
        #expect(item.formattedUpdatedDate != nil)
        #expect(item.relativeUpdatedDate != nil)

        // Verify HTTP Headers and Query Items
        let req = try #require(capturedRequest)
        #expect(req.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
        #expect(req.value(forHTTPHeaderField: "X-GitHub-Api-Version") == "2022-11-28")
        let urlString = try #require(req.url?.absoluteString)
        #expect(urlString.contains("q=swift%20ai"))
        #expect(urlString.contains("sort=stars"))
        #expect(urlString.contains("order=desc"))
    }

    @Test func fetchRateLimitedThrowsRateLimitedError() async throws {
        let (sut, _) = makeSUT { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        await #expect(throws: GitRepositoryError.rateLimited) {
            try await sut.fetch(query: "test")
        }
    }

    @Test func fetchCorruptedJSONThrowsDecodingFailed() async throws {
        let (sut, _) = makeSUT { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("invalid json".utf8))
        }

        await #expect(throws: GitRepositoryError.decodingFailed) {
            try await sut.fetch(query: "test")
        }
    }

    @Test func fetchOfflineThrowsNetworkUnavailable() async throws {
        let (sut, _) = makeSUT { _ in
            throw URLError(.notConnectedToInternet)
        }

        await #expect(throws: GitRepositoryError.networkUnavailable) {
            try await sut.fetch(query: "test")
        }
    }
}

// MARK: - Test Doubles

private final class MockRepo: GitRepository, @unchecked Sendable {
    var delay: Duration
    var isError: Bool

    init(delay: Duration = .zero, query: String = "", isError: Bool = false) {
        self.delay = delay
        self.isError = isError
    }

    func fetch(query: String) async throws -> Git {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        if isError {
            throw GitRepositoryError.rateLimited
        }
        guard query == "swift" else { return Git(total: 0, items: []) }

        return Git(total: 1, items: [.sample])
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            fatalError("requestHandler not set")
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
