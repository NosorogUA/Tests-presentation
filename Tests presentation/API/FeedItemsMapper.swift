//
//  FeedItemsMapper.swift
//  Tests presentation
//
//  Created by Igor Tokalenko on 13.05.2025.
//
import Foundation

final class FeedItemsMapper {
    private struct Root: Decodable {
        let items: [RemoteFeedImage]
    }
    
    static func map(_ data: Data, from response: HTTPURLResponse) throws -> [RemoteFeedImage] {
        guard response.statusCode == 200,
              let root = try? JSONDecoder().decode(Root.self, from: data)
        else {
            throw RemoteFeedLoader.Error.invalidData
        }
        
        return root.items
    }
}
