//
//  LeakChecker.swift
//  Tests presentation
//
//  Created by Igor Tokalenko on 13.05.2025.
//

import Testing

final class LeakChecker {
    private var checks = [LeakCheck]()

    /// Registers an object for memory leak checking and returns it
    func checkForMemoryLeak<T: AnyObject & Sendable>(_ instance: T, _ source: SourceLocation = #_sourceLocation) -> T {
        checks.append(LeakCheck(instance, sourceLocation: source))
        return instance
    }

    /// Checks for memory leaks when destroying an instance
    deinit {
        for check in checks {
            #expect(check.isLeaking == false, "Potential Memory Leak detected", sourceLocation: check.sourceLocation)
        }
    }

    private struct LeakCheck {
        private weak var weakReference: (AnyObject & Sendable)?
        let sourceLocation: SourceLocation
       
        var isLeaking: Bool { weakReference != nil }
        
        init(_ weakReference: AnyObject & Sendable, sourceLocation: SourceLocation) {
            self.weakReference = weakReference
            self.sourceLocation = sourceLocation
        }
    }
}
