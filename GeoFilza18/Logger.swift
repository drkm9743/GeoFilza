//
//  Logger.swift
//  GeoFilza18
//
//  Console log capture and display.
//  Based on roooot's Logger from lara.
//

import Foundation
import Darwin
import Combine
import SwiftUI

let globallogger = Logger()

class Logger: ObservableObject {
    @Published var logs: [String] = []
    private var lastwasdivider = false
    private var pendingdivider = false
    private var stdoutpipe: Pipe?
    private var pending = ""
    private var ogstdout: Int32 = -1
    private var ogstderr: Int32 = -1

    private let ignoredSubstrings = [
        "Faulty glyph",
        "outline detected",
        "System gesture gate timed out",
        "tcp_output [",
        "Error Domain=",
        "NSError"
    ]

    init() {}

    func log(_ message: String) {
        DispatchQueue.main.async {
            if self.pendingdivider {
                self.divider()
                self.pendingdivider = false
            }
            if self.lastwasdivider || self.logs.isEmpty {
                self.logs.append(message)
            } else {
                self.logs[self.logs.count - 1] += "\n" + message
            }
            self.lastwasdivider = false
        }
        emit(message)
    }

    func divider() {
        DispatchQueue.main.async { self.lastwasdivider = true }
    }

    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            self.lastwasdivider = false
            self.pendingdivider = false
        }
    }

    func capture() {
        if stdoutpipe != nil { return }
        let pipe = Pipe()
        stdoutpipe = pipe
        ogstdout = dup(STDOUT_FILENO)
        ogstderr = dup(STDERR_FILENO)
        setvbuf(stdout, nil, _IOLBF, 0)
        setvbuf(stderr, nil, _IOLBF, 0)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { return }
            guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
            self?.appendRaw(chunk)
        }
    }

    private func appendRaw(_ chunk: String) {
        var text = pending + chunk
        var lines = text.components(separatedBy: "\n")
        pending = lines.removeLast()
        if !lines.isEmpty {
            let filtered = lines.filter { !shouldIgnore($0) }
            DispatchQueue.main.async { self.logs.append(contentsOf: filtered) }
            for line in filtered { emit(line) }
        }
    }

    private func emit(_ message: String) {
        if shouldIgnore(message) { return }
        guard ogstdout != -1 else { return }
        let line = message + "\n"
        line.withCString { ptr in _ = Darwin.write(ogstdout, ptr, strlen(ptr)) }
    }

    private func shouldIgnore(_ msg: String) -> Bool {
        if msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return ignoredSubstrings.contains { msg.contains($0) }
    }
}

// MARK: - LogsView

struct LogsView: View {
    @ObservedObject var logger: Logger

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(logger.logs.enumerated()), id: \.offset) { _, entry in
                    Text(entry)
                        .font(.system(size: 12, design: .monospaced))
                        .lineSpacing(1)
                        .onTapGesture {
                            UIPasteboard.general.string = entry
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                }
            }
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        UIPasteboard.general.string = logger.logs.joined(separator: "\n\n")
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    Button {
                        logger.clear()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}
