//
//  GeoFilza18App.swift
//  GeoFilza18
//
//  Read-only file manager for iOS 18.6.2
//  Based on darksword kexploit + lara KFS
//

import SwiftUI

@main
struct GeoFilza18App: App {
    init() {
        globallogger.capture()
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Exploit", systemImage: "cpu")
                    }

                FileBrowserView()
                    .tabItem {
                        Label("Browser", systemImage: "folder")
                    }

                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }

                LogsView(logger: globallogger)
                    .tabItem {
                        Label("Logs", systemImage: "text.document.fill")
                    }
            }
            .onAppear {
                init_offsets()
            }
        }
    }
}
