//
//  RemoteItem.swift
//  Tests presentation
//
//  Created by Igor Tokalenko on 13.05.2025.
//
import Foundation

struct RemoteFeedImage: Decodable {
    let id: UUID
    let description: String?
    let location: String?
    let image: URL
    
    var item: FeedImage {
        FeedImage(id: id, description: description, location: location, url: image)
    }
}
