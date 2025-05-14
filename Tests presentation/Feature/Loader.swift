//
//  Loader.swift
//  Tests presentation
//
//  Created by Igor Tokalenko on 13.05.2025.
//

import Foundation

public enum LoadFeedResult {
    case success([FeedImage])
    case failure(Error)
}

public protocol FeedLoader {
    func load(completion: @escaping (LoadFeedResult) -> Void)
}
