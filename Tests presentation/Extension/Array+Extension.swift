//
//  Array+Extension.swift
//  Tests presentation
//
//  Created by Igor Tokalenko on 15.05.2025.
//


extension Array where Element == RemoteFeedImage {
    func toModels() -> [FeedImage] {
        return map { FeedImage(id: $0.id, description: $0.description, location: $0.location, url: $0.image)}
    }
}
