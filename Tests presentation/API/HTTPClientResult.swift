//
//  HTTPClientResult.swift
//  Tests presentation
//
//  Created by Igor Tokalenko on 13.05.2025.
//

import Foundation

public enum HTTPClientResult {
    case success(Data, HTTPURLResponse)
    case failure(Error)
}

public protocol HTTPClient {
    func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void)
}
