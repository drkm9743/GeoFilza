//
//  HomeView.swift
//  GeoFilza18
//
//  Exploit initialization: download kernelcache, run exploit, init KFS.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject private var mgr = ExploitManager.shared
    @State private var hasoffsets = haskernproc()

    var body: some View {
        NavigationStack {
            List {
                // ── Header ──
                Section {
                    VStack(spacing: 4) {
                        Text("GeoFilza18")
                            .font(.title.bold())
                        Text("Read-only File Manager — iOS 18")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                // ── Kernelcache ──
                if !hasoffsets {
                    Section("Kernelcache") {
                        Button("Download Kernelcache") {
                            DispatchQueue.global(qos: .userInitiated).async {
                                let ok = dlkerncache()
                                DispatchQueue.main.async { hasoffsets = ok }
                            }
                        }
                        Text("Required before running the exploit. Downloads the kernelcache for your device and resolves offsets via XPF.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // ── Exploit ──
                if hasoffsets {
                    if !hasrootvnodeoffset() {
                        Section("Rootvnode Offset Missing") {
                            Text("Your cached offsets don't include rootvnode. Clear and re-download the kernelcache to resolve it.")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Button("Clear & Re-download Kernelcache") {
                                clearkerncachedata()
                                hasoffsets = false
                                DispatchQueue.global(qos: .userInitiated).async {
                                    let ok = dlkerncache()
                                    DispatchQueue.main.async { hasoffsets = ok }
                                }
                            }
                        }
                    }

                    Section("Kernel Read/Write") {
                        Button(mgr.dsrunning ? "Running..." : "Run Exploit") {
                            mgr.run()
                        }
                        .disabled(mgr.dsrunning || mgr.dsready)

                        StatusRow(label: "krw ready", ok: mgr.dsready)

                        if mgr.dsready {
                            HexRow(label: "kernel_base", value: mgr.kernbase)
                            HexRow(label: "kernel_slide", value: mgr.kernslide)
                        }
                    }

                    // ── KFS ──
                    Section("Kernel File System") {
                        Button("Initialize KFS") {
                            mgr.kfsinit()
                        }
                        .disabled(!mgr.dsready || mgr.kfsready)

                        StatusRow(label: "kfs ready", ok: mgr.kfsready)

                        if mgr.kfsready {
                            Label("Switch to Browser tab to explore the filesystem", systemImage: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    // ── System Info ──
                    Section("System") {
                        HStack {
                            Text("PID")
                            Spacer()
                            Text("\(getpid())")
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                        HStack {
                            Text("UID")
                            Spacer()
                            Text("\(getuid())")
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }

                // ── Credits ──
                Section("Credits") {
                    Text("darksword exploit — opa334")
                    Text("KFS / lara — roooot")
                    Text("GeoFilza concept — GeoSn0w")
                    Text("libgrabkernel2 — AlfieCG")
                    Text("XPF — opa334")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            .navigationTitle("GeoFilza18")
        }
    }
}

// MARK: - Helper views

struct StatusRow: View {
    let label: String
    let ok: Bool
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(ok ? "Yes" : "No")
                .foregroundColor(ok ? .green : .red)
        }
    }
}

struct HexRow: View {
    let label: String
    let value: UInt64
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "0x%llx", value))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}
