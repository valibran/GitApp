//
//  GitView.swift
//  GitApp
//
//  Created by Valentin Bran on 03/10/2026.
//

import SwiftUI

struct GitView: View {
    @Bindable var viewModel: GitViewModel

    private var idleView: some View {
        ContentUnavailableView(
            "Search Repositories",
            systemImage: "magnifyingglass",
            description: Text("Type a keyword to discover public GitHub repositories.")
        )
    }

    private var emptyView: some View {
        ContentUnavailableView.search(text: viewModel.query)
    }

    private func itemsView(items: [GitItem]) -> some View {
        List(items) { item in
            NavigationLink(value: item) {
                RowView(item: item)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry", action: viewModel.retry)
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var stateView: some View {
        switch viewModel.state {
        case .idle:
            idleView
        case .loading:
            ProgressView("Searching repositories...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .success(let items):
            itemsView(items: items)
        case .empty:
            emptyView
        case .error(let message):
            errorView(message: message)
        }
    }

    var body: some View {
        NavigationStack {
            stateView
                .animation(.easeInOut(duration: 0.2), value: viewModel.state)
                .navigationTitle("Repositories")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: GitItem.self) { item in
                    DetailsView(item: item)
                }
                .searchable(text: $viewModel.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find your repo")
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(of: .search) {
                    viewModel.submitSearch()
                }
                .refreshable {
                    await viewModel.refresh()
                }
        }
    }
}

struct RowView: View {
    let item: GitItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: item.ownerAvatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure, .empty:
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.secondary)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if item.description.isEmpty {
                    Text("No description provided.")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                } else {
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Label(item.formattedStars, systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)

                    if !item.language.isEmpty {
                        Label(item.language, systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let updated = item.relativeUpdatedDate {
                        Text(updated)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.stargazersCount) stars, language \(item.language)\(item.relativeUpdatedDate.map { ", \($0)" } ?? "")")
    }
}

struct DetailsView: View {
    let item: GitItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    AsyncImage(url: item.ownerAvatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure, .empty:
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.ownerName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(item.name)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }

                HStack(spacing: 16) {
                    Label("\(item.stargazersCount) Stars", systemImage: "star.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.yellow)

                    if !item.language.isEmpty {
                        Label(item.language, systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }

                    if let formattedDate = item.formattedUpdatedDate {
                        Label("Updated \(formattedDate)", systemImage: "calendar")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)

                    Text(item.description.isEmpty ? "No description provided." : item.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                if let url = item.htmlURL {
                    Link(destination: url) {
                        Label("View on GitHub", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Idle State") {
    GitView(viewModel: .preview(state: .idle))
}

#Preview("Loading State") {
    GitView(viewModel: .preview(state: .loading))
}

#Preview("Empty Results") {
    GitView(viewModel: .preview(state: .empty))
}

#Preview("Loaded Repositories") {
    GitView(viewModel: .preview(state: .success([.sample])))
}

#Preview("Error State") {
    GitView(viewModel: .preview(state: .error("Network connection appears to be offline.")))
}

#Preview("Repository Details") {
    DetailsView(item: .sample)
}

#Preview("Repository Row") {
    RowView(item: .sample)
        .padding()
}
