//
//  SearchView.swift
//  GeoFilza18
//
//  Automated scanner for Apple Pay / Wallet image directories.
//  Scans known and suspected paths where iOS 18 stores card imagery.
//

import SwiftUI

struct SearchView: View {
    @ObservedObject private var mgr = ExploitManager.shared
    @State private var results: [SearchResult] = []
    @State private var scanning = false
    @State private var scanLog: [String] = []
    @State private var customPath = ""
    @State private var customResults: [(name: String, isDir: Bool)] = []
    @State private var customError: String?

    var body: some View {
        NavigationStack {
            List {
                if !mgr.kfsready {
                    Section {
                        Text("Initialize KFS first from the Exploit tab.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    // ── Quick scan ──
                    Section("Apple Pay / Wallet Scanner") {
                        Button(scanning ? "Scanning..." : "Scan Known Paths") {
                            runScan()
                        }
                        .disabled(scanning)

                        Text("Scans all known and suspected directories where iOS stores Apple Pay card images, pass thumbnails, and wallet assets.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // ── Manual path probe ──
                    Section("Manual Path Probe") {
                        HStack {
                            TextField("/var/...", text: $customPath)
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            Button("List") {
                                probeCustomPath()
                            }
                            .disabled(customPath.isEmpty)
                        }

                        if let err = customError {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        ForEach(customResults, id: \.name) { item in
                            if item.isDir {
                                NavigationLink {
                                    DirectoryListView(path: appendPath(customPath, item.name), title: item.name)
                                } label: {
                                    Label(item.name, systemImage: "folder.fill")
                                }
                            } else {
                                Label(item.name, systemImage: "doc")
                            }
                        }
                    }

                    // ── Results ──
                    if !results.isEmpty {
                        Section("Found Directories (\(results.count))") {
                            ForEach(results) { r in
                                NavigationLink {
                                    DirectoryListView(path: r.path, title: r.label)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(r.label)
                                            .font(.body.bold())
                                        Text(r.path)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.secondary)
                                        if !r.children.isEmpty {
                                            Text("\(r.children.count) items: \(r.children.prefix(5).joined(separator: ", "))\(r.children.count > 5 ? "..." : "")")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .contextMenu {
                                        Button {
                                            UIPasteboard.general.string = r.path
                                        } label: {
                                            Label("Copy Path", systemImage: "doc.on.clipboard")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Scan log ──
                    if !scanLog.isEmpty {
                        Section("Scan Log") {
                            ForEach(Array(scanLog.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
        }
    }

    // MARK: - Scan logic

    private func runScan() {
        scanning = true
        results = []
        scanLog = []

        DispatchQueue.global(qos: .userInitiated).async {
            var found: [SearchResult] = []
            var log: [String] = []

            for candidate in Self.walletPaths {
                log.append("Checking: \(candidate.path)")

                guard let items = ExploitManager.shared.listdir(path: candidate.path) else {
                    log.append("  ✗ not accessible")
                    continue
                }

                log.append("  ✓ \(items.count) items")
                let names = items.map { $0.name }
                found.append(SearchResult(
                    label: candidate.label,
                    path: candidate.path,
                    children: names
                ))

                // Recurse one level into subdirectories for wallet-related content
                for item in items where item.isDir {
                    let sub = appendPath(candidate.path, item.name)
                    if let subItems = ExploitManager.shared.listdir(path: sub) {
                        let hasImages = subItems.contains { isImageFile($0.name) }
                        let hasPlist = subItems.contains { $0.name.hasSuffix(".plist") }
                        let hasCar = subItems.contains { $0.name.hasSuffix(".car") }

                        if hasImages || hasPlist || hasCar {
                            log.append("  → \(sub): \(subItems.count) items (images:\(hasImages) plist:\(hasPlist) car:\(hasCar))")
                            found.append(SearchResult(
                                label: "\(candidate.label) / \(item.name)",
                                path: sub,
                                children: subItems.map { $0.name }
                            ))
                        }
                    }
                }
            }

            // Also scan /var/containers/Shared/SystemGroup for wallet groups
            log.append("\nScanning SystemGroup containers...")
            if let groups = ExploitManager.shared.listdir(path: "/var/containers/Shared/SystemGroup") {
                for g in groups where g.isDir {
                    let gpath = "/var/containers/Shared/SystemGroup/\(g.name)"
                    if g.name.lowercased().contains("wallet") ||
                       g.name.lowercased().contains("pass") ||
                       g.name.lowercased().contains("apple.pay") ||
                       g.name.lowercased().contains("npay") ||
                       g.name.lowercased().contains("nfc") ||
                       g.name.lowercased().contains("secureenclavetoken") ||
                       g.name.lowercased().contains("passkit") {
                        log.append("  ★ \(g.name)")
                        if let items = ExploitManager.shared.listdir(path: gpath) {
                            found.append(SearchResult(
                                label: "SystemGroup: \(g.name)",
                                path: gpath,
                                children: items.map { $0.name }
                            ))
                        }
                    }

                    // Check ALL group containers for wallet keywords
                    if let items = ExploitManager.shared.listdir(path: gpath) {
                        for item in items where item.isDir {
                            let itemLower = item.name.lowercased()
                            if itemLower.contains("pass") || itemLower.contains("wallet") || itemLower.contains("pay") {
                                let subpath = "\(gpath)/\(item.name)"
                                log.append("  → \(subpath)")
                                if let subs = ExploitManager.shared.listdir(path: subpath) {
                                    found.append(SearchResult(
                                        label: "Group/\(g.name)/\(item.name)",
                                        path: subpath,
                                        children: subs.map { $0.name }
                                    ))
                                }
                            }
                        }
                    }
                }
            }

            // Scan /var/mobile/Library for wallet dirs
            log.append("\nScanning /var/mobile/Library...")
            if let mobileLib = ExploitManager.shared.listdir(path: "/var/mobile/Library") {
                for d in mobileLib where d.isDir {
                    let dl = d.name.lowercased()
                    if dl.contains("pass") || dl.contains("wallet") || dl.contains("pay") || dl == "nfc" {
                        let dp = "/var/mobile/Library/\(d.name)"
                        log.append("  ★ \(d.name)")
                        if let items = ExploitManager.shared.listdir(path: dp) {
                            found.append(SearchResult(
                                label: "mobile/Library/\(d.name)",
                                path: dp,
                                children: items.map { $0.name }
                            ))
                        }
                    }
                }
            }

            log.append("\nScan complete: \(found.count) locations found")

            DispatchQueue.main.async {
                results = found
                scanLog = log
                scanning = false
            }
        }
    }

    private func probeCustomPath() {
        customError = nil
        customResults = []
        if let items = mgr.listdir(path: customPath) {
            customResults = items
        } else {
            customError = "Could not list \(customPath) — not in name cache or not a directory."
        }
    }

    // MARK: - Candidate paths

    /// All known and suspected paths where Apple Pay / Wallet stores card images on iOS 18
    static let walletPaths: [(label: String, path: String)] = [
        // Passbook / Wallet data
        ("Passes (mobile)", "/var/mobile/Library/Passes"),
        ("Passes/Cards", "/var/mobile/Library/Passes/Cards"),
        ("Passes/library", "/var/mobile/Library/Passes/library"),
        ("Wallet data", "/var/mobile/Library/Wallet"),

        // PassKit framework caches
        ("PassKit caches", "/var/mobile/Library/Caches/com.apple.PassKit"),
        ("Passbook caches", "/var/mobile/Library/Caches/com.apple.Passbook"),

        // NFC / SE related
        ("NFC", "/var/mobile/Library/NFC"),

        // Secure element / payments
        ("com.apple.nfcd", "/var/mobile/Library/com.apple.nfcd"),
        ("Sharing", "/var/mobile/Library/Sharing"),

        // System-level wallet data
        ("passd container", "/var/containers/Data/System/com.apple.passd"),
        ("Wallet app data", "/private/var/mobile/Containers/Data/Application"),

        // System shared groups
        ("SG: PassKit", "/var/containers/Shared/SystemGroup/systemgroup.com.apple.PassKit"),
        ("SG: walletd", "/var/containers/Shared/SystemGroup/systemgroup.com.apple.walletd"),
        ("SG: nfc", "/var/containers/Shared/SystemGroup/systemgroup.com.apple.nfc"),
        ("SG: payments", "/var/containers/Shared/SystemGroup/systemgroup.com.apple.payments"),
        ("SG: apple.pay", "/var/containers/Shared/SystemGroup/systemgroup.com.apple.pay"),

        // Daemon data
        ("passd data", "/var/db/passd"),
        ("nfcd data", "/var/db/nfcd"),

        // Card images known locations
        ("CardImages (Library)", "/var/mobile/Library/Passes/CardImages"),
        ("Thumbnails (Passes)", "/var/mobile/Library/Passes/Thumbnails"),
        ("Cards data", "/var/mobile/Library/Passes/Cards"),

        // Possible iOS 18 new paths
        ("FinanceKit", "/var/mobile/Library/FinanceKit"),
        ("Apple Pay data", "/var/mobile/Library/ApplePay"),

        // walletd user container
        ("walletd lib", "/var/mobile/Library/walletd"),

        // System caches shared with Wallet
        ("DaemonCaches", "/var/root/Library/Caches"),

        // /System paths (readonly, but images could be there as assets)
        ("PassKitCore fw", "/System/Library/PrivateFrameworks/PassKitCore.framework"),
        ("PassKitUI fw", "/System/Library/PrivateFrameworks/PassKitUI.framework"),
        ("NanoPassKit fw", "/System/Library/PrivateFrameworks/NanoPassKit.framework"),
        ("FinanceKit fw", "/System/Library/PrivateFrameworks/FinanceKit.framework"),

        // Cardio-specific: known places to look for card art
        ("Cardio known: cardimagesd", "/var/mobile/Library/Caches/com.apple.cardimagesd"),
        ("Cardio known: TSS", "/var/mobile/Library/TSS"),
        ("Cardio known: KeychainCircle", "/var/mobile/Library/KeychainCircle"),
    ]

    private func isImageFile(_ name: String) -> Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "heic", "gif", "webp", "tiff", "pdf", "car"].contains(ext)
    }
}

private func appendPath(_ base: String, _ child: String) -> String {
    base == "/" ? "/\(child)" : "\(base)/\(child)"
}

// MARK: - Model

struct SearchResult: Identifiable {
    let id = UUID()
    let label: String
    let path: String
    let children: [String]
}
