//
//  LeakChecker.swift
//  Tests presentation
//
//  Created by Igor Tokalenko on 13.05.2025.
//


import Testing

/// Checks for memory leaks when going out of scope
final class LeakChecker {
    typealias Checkable = AnyObject & Sendable

    func checkForMemoryLeak<T: Checkable>(source: SourceLocation = #_sourceLocation,
                                          _ instanceFactory: @autoclosure () async throws -> T) async throws -> T
    {
        let instance = try await instanceFactory()
        checks.append(.init(instance, sourceLocation: source))
        return instance
    }
    
    func checkForMemoryLeak<T: Checkable>(source: SourceLocation = #_sourceLocation,
                                          _ instanceFactory: @autoclosure () -> T) -> T
    {
        let instance = instanceFactory()
        checks.append(.init(instance, sourceLocation: source))
        return instance
    }

    private struct LeakCheck {
        let sourceLocation: SourceLocation
        private weak var weakReference: Checkable?
        var isLeaking: Bool { weakReference != nil }
        init(_ weakReference: Checkable, sourceLocation: SourceLocation) {
            self.weakReference = weakReference
            self.sourceLocation = sourceLocation
        }
    }

    private var checks = [LeakCheck]()

    typealias Scope = (LeakChecker) -> Void
    typealias AsyncScope = (LeakChecker) async throws -> Void

    private var asyncScope: AsyncScope?
    private var scope: Scope?

    @discardableResult
    init(scope: @escaping Scope) {
        self.scope = scope
        scope(self)
    }
    
    @discardableResult
    init(scope: @escaping AsyncScope) async throws {
        self.asyncScope = scope
        try await scope(self)
    }

    deinit {
        for check in checks {
            #expect(check.isLeaking == false, "Potential Memory Leak detected", sourceLocation: check.sourceLocation)
        }
    }
}
