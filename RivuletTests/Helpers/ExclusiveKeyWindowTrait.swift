// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import Testing

nonisolated struct ExclusiveKeyWindowTrait: TestTrait, TestScoping {
    private static let gate = Gate()

    func provideScope(for test: Test, testCase: Test.Case?,
                      performing function: @concurrent @Sendable () async throws -> Void) async throws {
        try await Self.gate.run(function)
    }

    private actor Gate {
        private var isHeld = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func run(_ function: @concurrent @Sendable () async throws -> Void) async throws {
            await acquire()
            defer { release() }
            try await function()
        }

        private func acquire() async {
            if isHeld {
                await withCheckedContinuation { waiters.append($0) }
            } else {
                isHeld = true
            }
        }

        private func release() {
            if waiters.isEmpty {
                isHeld = false
            } else {
                waiters.removeFirst().resume()
            }
        }
    }
}
