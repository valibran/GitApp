//
//  ContentView.swift
//  GitApp
//
//  Created by Valentin Bran on 03/10/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = GitViewModel()

    var body: some View {
        GitView(viewModel: viewModel)
    }
}

#Preview("App Root Flow") {
    ContentView()
}
