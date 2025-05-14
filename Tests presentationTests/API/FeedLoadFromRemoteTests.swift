//
//  FeedLoadFromRemoteTests.swift
//  Tests presentation
//
//  Created by Igor Tokalenko on 13.05.2025.
//

import Testing
import Tests_presentation
import Foundation

class Tests_RemoteFeedLoader {
    @Test func init_doesNotRequestDataFromURL() {
        LeakChecker { checker in
            let url = URL(string: "https://a-url.com")!
            let client = checker.checkForMemoryLeak(HTTPClientSpy())
            _ = checker.checkForMemoryLeak(RemoteFeedLoader(url: url, client: client))
            
            #expect(client.requestedURLs.isEmpty)
        }
    }
    
    @Test func load_requestsDataFromURL() {
        LeakChecker { checker in
            let url = URL(string: "https://a-given-url.com")!
            let client: HTTPClientSpy = checker.checkForMemoryLeak(HTTPClientSpy())
            let sut: RemoteFeedLoader = checker.checkForMemoryLeak(RemoteFeedLoader(url: url, client: client))
            
            sut.load { _ in }
            
            #expect(client.requestedURLs == [url])
        }
    }
    
    @Test func loadTwice_requestsDataFromURLTwice() {
        LeakChecker { checker in
            let url = URL(string: "https://a-given-url.com")!
            let client: HTTPClientSpy = checker.checkForMemoryLeak(HTTPClientSpy())
            let sut: RemoteFeedLoader = checker.checkForMemoryLeak(RemoteFeedLoader(url: url, client: client))
            
            sut.load { _ in }
            sut.load { _ in }
            
            #expect(client.requestedURLs == [url, url])
        }
    }
    
    @Test func load_deliversErrorOnClientError() async throws {
        try await LeakChecker { checker in
            let url = URL(string: "https://any-url.com")!
            let client: HTTPClientSpy = try await checker.checkForMemoryLeak(HTTPClientSpy())
            let sut: RemoteFeedLoader = try await checker.checkForMemoryLeak(RemoteFeedLoader(url: url, client: client))
            
            await Tests_RemoteFeedLoader.expect(
                sut,
                toCompleteWithResult: Tests_RemoteFeedLoader.failure(.connectivity),
                location: #_sourceLocation) {
                    
                let clientError = NSError(domain: "Test", code: 0)
                client.complete(with: clientError)
            }
        }
    }
    
    @Test(arguments: [199, 201, 300, 400, 500])
    func load_deliversErrorOnNon200HTTPResponse(statusCode: Int) async throws {
        try await LeakChecker { checker in
            let url = URL(string: "https://any-url.com")!
            let client: HTTPClientSpy = try await checker.checkForMemoryLeak(HTTPClientSpy())
            let sut: RemoteFeedLoader = try await checker.checkForMemoryLeak(RemoteFeedLoader(url: url, client: client))
            
            await Tests_RemoteFeedLoader.expect(
                sut,
                toCompleteWithResult: Tests_RemoteFeedLoader.failure(.invalidData),
                location: #_sourceLocation) {
                    
                    let json = Tests_RemoteFeedLoader.makeItemsJson([])
                    client.complete(withStatusCode: statusCode, data: json, at: 0)
                }
        }
    }
    
    @Test func load_deliversErrorOn200HTTPResponseWithInvalidJson() async throws {
        try await LeakChecker { checker in
            let url = URL(string: "https://any-url.com")!
            
            let client: HTTPClientSpy = try await checker.checkForMemoryLeak(HTTPClientSpy())
            let sut: RemoteFeedLoader = try await checker.checkForMemoryLeak(RemoteFeedLoader(url: url, client: client))
            
            await Tests_RemoteFeedLoader.expect(
                sut,
                toCompleteWithResult: Tests_RemoteFeedLoader.failure(.invalidData),
                location: #_sourceLocation) {
                    let invalidJSON = Data("invalid JSON".utf8)
                    client.complete(withStatusCode: 200, data: invalidJSON)
                }
        }
    }
    
    @Test func load_deliversNoItemsOn200HTTPResponseWithEmptyJson() async throws {
        try await LeakChecker { checker in
            
            let url = URL(string: "https://any-url.com")!
            let client: HTTPClientSpy = try await checker.checkForMemoryLeak(HTTPClientSpy())
            let sut: RemoteFeedLoader = try await checker.checkForMemoryLeak(RemoteFeedLoader(url: url, client: client))
            
            await Tests_RemoteFeedLoader.expect(sut, toCompleteWithResult: .success([]), location: #_sourceLocation) {
                let json = Tests_RemoteFeedLoader.makeItemsJson([])
                client.complete(withStatusCode: 200, data: json)
            }
        }
    }
    
    @Test func load_deliversItemsOn200HTTPResponseWithValidJson() async throws {
        try await LeakChecker { checker in
            let url = URL(string: "https://any-url.com")!
            let client: HTTPClientSpy = try await checker.checkForMemoryLeak(HTTPClientSpy())
            var sut: RemoteFeedLoader? = try await checker.checkForMemoryLeak(RemoteFeedLoader(url: url, client: client))
            
            let item1 = Tests_RemoteFeedLoader.makeItem(
                id: UUID(),
                imageURL: URL(string: "https://a-given-url.com")!)
            
            let item2 = Tests_RemoteFeedLoader.makeItem(
                id: UUID(),
                description: "some desc",
                location: "some location",
                imageURL: URL(string: "https://b-given-url.com")!)
            
            let json = Tests_RemoteFeedLoader.makeItemsJson([item1.json, item2.json])
            
            await Tests_RemoteFeedLoader.expect(sut, toCompleteWithResult: .success([item1.model, item2.model]), location: #_sourceLocation) {
                sut = nil
                client.complete(withStatusCode: 200, data: json)
            }
        }
    }
    
    @Test func load_doesNotDeliverResultAfterSUTInstanceHasBeenDeallocated() {
        LeakChecker { checker in
            let url = URL(string: "https://any-url.com")!
            let client: HTTPClientSpy = checker.checkForMemoryLeak(HTTPClientSpy())
            var sut: RemoteFeedLoader? = checker.checkForMemoryLeak(RemoteFeedLoader(url: url, client: client))
            
            var capturedResults = [RemoteFeedLoader.Result]()
            sut?.load { capturedResults.append($0) }
            sut = nil
            
            client.complete(withStatusCode: 200, data: Tests_RemoteFeedLoader.makeItemsJson([]))
            
            #expect(capturedResults.isEmpty)
        }
    }
}

// MARK: Helpers
extension Tests_RemoteFeedLoader {
    private func makeSUT(url: URL = URL(string: "https://a-url.com")!, source: SourceLocation) -> (sut: RemoteFeedLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        return (sut, client)
    }
    
    
    static private func expect(
        _ sut: RemoteFeedLoader?,
        toCompleteWithResult expectedResult: RemoteFeedLoader.Result,
        location: SourceLocation,
        when action: () -> Void
    ) async {
        await withCheckedContinuation { continuation in
            sut?.load { receivedResult in
                switch (receivedResult, expectedResult) {
                case let (.success(receivedItems), .success(expectedItems)):
                    #expect(receivedItems == expectedItems, sourceLocation: location)
                    
                case let (.failure(receivedError as RemoteFeedLoader.Error),
                          .failure(expectedError as RemoteFeedLoader.Error)):
                    #expect(receivedError == expectedError, sourceLocation: location)
                    
                default:
                    Issue.record("Expected result: \(expectedResult) got \(receivedResult) instead",
                                 sourceLocation: location)
                }
                continuation.resume()
            }
            action()
        }
    }
    
    static private func failure(_ error: RemoteFeedLoader.Error) -> RemoteFeedLoader.Result {
        return .failure(error)
    }
    
    static private func makeItemsJson(_ items: [[String: Any]]) -> Data {
        let itemsJSON = ["items": items]
        return try! JSONSerialization.data(withJSONObject: itemsJSON)
    }
    
    static private func makeItem(
            id: UUID,
            description: String? = nil,
            location: String? = nil,
            imageURL: URL
        ) -> (model: FeedImage, json: [String: Any]) {
            let item = FeedImage(id: id, description: description, location: location, url: imageURL)
            
            let itemJSON = [
                "id": id.uuidString,
                "description": description,
                "location": location,
                "image": imageURL.absoluteString
            ].compactMapValues { $0 }
            
            return (item, itemJSON)
        }
}

// MARK: Spy
extension Tests_RemoteFeedLoader {
    private class HTTPClientSpy: HTTPClient {
        var requestedURLs: [URL] {
            messages.map { $0.url }
        }
        
        private var messages = [(url: URL, completion: (HTTPClientResult) -> Void)]()
        
        func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void) {
            messages.append((url, completion))
        }
        
        func complete(with error: Error, at index: Int = 0) {
            messages[index].completion(.failure(error))
        }
        
        func complete(withStatusCode code: Int, data: Data, at index: Int = 0) {
            let response = HTTPURLResponse(
                url: messages[index].url,
                statusCode: code,
                httpVersion: nil,
                headerFields: nil)!
            
            messages[index].completion(.success(data, response))
        }
    }
}
