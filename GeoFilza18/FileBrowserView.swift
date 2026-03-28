//
//  FileBrowserView.swift
//  GeoFilza18
//
//  Read-only kernel filesystem browser.
//  Uses kfs_listdir to navigate the full iOS directory tree.
//

import SwiftUI

struct FileBrowserView: View {
    @ObservedObject private var mgr = ExploitManager.shared

    var body: some View {
        NavigationStack {
            if !mgr.kfsready {
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("KFS not initialized")
                        .font(.headline)
                    Text("Go to the Exploit tab, run the exploit, then initialize KFS.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .navigationTitle("Browser")
            } else {
                DirectoryListView(path: "/", title: "/")
            }
        }
    }
}

// MARK: - Directory listing

struct DirectoryListView: View {
    let path: String
    let title: String

    @ObservedObject private var mgr = ExploitManager.shared
    @State private var entries: [(name: String, isDir: Bool)] = []
    @State private var loading = true
    @State private var errorMsg: String?
    @State private var searchText = ""

    private var filtered: [(name: String, isDir: Bool)] {
        if searchText.isEmpty { return entries }
        return entries.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if loading {
                ProgressView("Reading directory...")
            } else if let err = errorMsg {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { load() }
                }
                .padding()
            } else if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Empty directory")
                        .foregroundColor(.secondary)
                    Text(path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    Section {
                        Text(path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .listRowBackground(Color.clear)
                    }

                    Section("\(filtered.count) items") {
                        ForEach(filtered, id: \.name) { entry in
                            if entry.isDir {
                                NavigationLink {
                                    let child = path == "/" ? "/\(entry.name)" : "\(path)/\(entry.name)"
                                    DirectoryListView(path: child, title: entry.name)
                                } label: {
                                    DirectoryRow(name: entry.name, isDir: true, fullPath: childPath(entry.name))
                                }
                            } else {
                                FileRow(name: entry.name, fullPath: childPath(entry.name))
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Filter")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    UIPasteboard.general.string = path
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
            }
        }
        .onAppear { load() }
    }

    private func childPath(_ name: String) -> String {
        path == "/" ? "/\(name)" : "\(path)/\(name)"
    }

    private func load() {
        loading = true
        errorMsg = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = mgr.listdir(path: path)
            DispatchQueue.main.async {
                if let result {
                    entries = result
                } else {
                    errorMsg = "Failed to list \(path)\n\nThe directory may not be in the kernel name cache. Try accessing a parent directory first, or stat the path from another app."
                }
                loading = false
            }
        }
    }
}

// MARK: - Row views

struct DirectoryRow: View {
    let name: String
    let isDir: Bool
    let fullPath: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                Text(fullPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = fullPath
            } label: {
                Label("Copy Path", systemImage: "doc.on.clipboard")
            }
        }
    }
}

struct FileRow: View {
    let name: String
    let fullPath: String
    @ObservedObject private var mgr = ExploitManager.shared
    @State private var showInfo = false
    @State private var fileSize: Int64 = -1

    var body: some View {
        Button {
            showInfo = true
            DispatchQueue.global(qos: .userInitiated).async {
                let sz = mgr.fileSize(path: fullPath)
                DispatchQueue.main.async { fileSize = sz }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: iconForFile(name))
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(fullPath)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = fullPath
            } label: {
                Label("Copy Path", systemImage: "doc.on.clipboard")
            }
        }
        .sheet(isPresented: $showInfo) {
            FileInfoSheet(name: name, path: fullPath, size: fileSize)
        }
    }

    private func iconForFile(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "plist": return "doc.text"
        case "png", "jpg", "jpeg", "heic", "gif", "webp", "tiff": return "photo"
        case "pdf": return "doc.richtext"
        case "db", "sqlite", "sqlitedb": return "cylinder"
        case "dylib", "framework": return "shippingbox"
        case "car": return "paintbrush"
        case "mobileprovision": return "checkmark.seal"
        default: return "doc"
        }
    }
}

struct FileInfoSheet: View {
    let name: String
    let path: String
    let size: Int64
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("File Info") {
                    InfoRow(label: "Name", value: name)
                    InfoRow(label: "Path", value: path)
                    InfoRow(label: "Size", value: size >= 0 ? formatSize(size) : "Unknown")
                    InfoRow(label: "Extension", value: (name as NSString).pathExtension)
                }

                Section {
                    Button {
                        UIPasteboard.general.string = path
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label("Copy Full Path", systemImage: "doc.on.clipboard")
                    }
                }
            }
            .navigationTitle("File Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024*1024)) }
        return String(format: "%.2f GB", Double(bytes) / (1024*1024*1024))
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
