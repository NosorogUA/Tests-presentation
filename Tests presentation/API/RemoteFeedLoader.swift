//
//  RemoteFeedLoader.swift
//  Tests presentation
//
//  Created by Igor Tokalenko on 13.05.2025.
//

import Foundation

public final class RemoteFeedLoader: FeedLoader {
    // MARK: Private Properties
    private let url: URL
    private let client: HTTPClient
    
    public enum Error: Swift.Error {
        case connectivity
        case invalidData
    }
    
    public typealias Result = LoadFeedResult
    
    // MARK: Constructor
    public init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }
    
    // MARK: Public functions
    public func load(completion: @escaping (Result) -> Void) {
        client.get(from: url) { [weak self] result in
            guard self != nil else { return }
            switch result {
            case let .success(data, response):
                completion(RemoteFeedLoader.map(data, from: response))
            case .failure:
                completion(.failure(Error.connectivity))
            }
        }
    }
    
    private static func map(_ data: Data, from response: HTTPURLResponse) -> Result {
        do {
            let feed = try FeedItemsMapper.map(data, from: response)
            return .success(feed.toModels())
        } catch {
            return .failure(error)
        }
    }
    
//        public func load(completion: @escaping (Result) -> Void) {
//            client.get(from: url) { result in
//                switch result {
//                case let .success(data, response):
//                    completion(self.map(data, from: response))
//                case .failure:
//                    completion(.failure(Error.connectivity))
//                }
//            }
//        }
//    
//        private func map(_ data: Data, from response: HTTPURLResponse) -> Result {
//            do {
//                let feed = try FeedItemsMapper.map(data, from: response)
//                return .success(feed.toModels())
//            } catch {
//                return .failure(error)
//            }
//        }

}

private extension Array where Element == RemoteFeedImage {
    func toModels() -> [FeedImage] {
        return map { FeedImage(id: $0.id, description: $0.description, location: $0.location, url: $0.image)}
    }
}
