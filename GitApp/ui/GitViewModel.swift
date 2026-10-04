//
//  GitViewModel.swift
//  GitApp
//
//  Created by Valentin Bran on 03/10/2026.
//

import Foundation

@MainActor
@Observable
final class GitViewModel {
    var state: GitUiState = .idle

    var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            load()
        }
    }
    private(set) var task: Task<Void, Never>?
    private let repository: GitRepository
    private let debounce: Duration

    init(repository: GitRepository, debounce: Duration = .milliseconds(300)) {
        self.repository = repository
        self.debounce = debounce
    }

    convenience init(debounce: Duration = .milliseconds(300)) {
        self.init(repository: DefaultGitRepository(), debounce: debounce)
    }

    /// Triggered as user types; debounced to prevent excessive API requests.
    func load() {
        executeFetch(immediate: false)
    }

    /// Explicit user action to retry a failed search without debouncing.
    func retry() {
        executeFetch(immediate: true)
    }

    /// Triggered when the user presses Return/Search on the keyboard.
    func submitSearch() {
        executeFetch(immediate: true)
    }

    /// Pull-to-refresh: awaits fetch completion so the native refresh spinner stays active.
    func refresh() async {
        executeFetch(immediate: true)
        await task?.value
    }

    private func executeFetch(immediate: Bool) {
        task?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .idle
            task = nil
            return
        }

        if immediate {
            state = .loading
        }

        task = Task {
            do {
                if !immediate && debounce > .zero {
                    try await Task.sleep(for: debounce)
                }
                state = .loading
                let items = try await repository.fetch(query: trimmed).items
                state = items.isEmpty ? .empty : .success(items)
            } catch {
                if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                    return
                }
                state = .error(error.localizedDescription)
            }
        }
    }
}

enum GitUiState: Equatable {
    case idle
    case loading
    case success([GitItem])
    case empty
    case error(String)
}

extension GitViewModel {
    static func preview(state: GitUiState = .idle) -> GitViewModel {
        struct PreviewRepository: GitRepository {
            func fetch(query: String) async throws -> Git {
                Git(total: 1, items: [.sample])
            }
        }
        let vm = GitViewModel(repository: PreviewRepository(), debounce: .zero)
        vm.state = state
        return vm
    }
}
