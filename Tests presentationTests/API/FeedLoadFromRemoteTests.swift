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
    /// LeakChecker to track memory leaks
    private let leakChecker = LeakChecker()

    @Test func init_doesNotRequestDataFromURL() {
        let (_, client) = makeSUT()
        
        #expect(client.requestedURLs.isEmpty)
    }
    
    @Test func load_requestsDataFromURL() {
        let url = URL(string: "https://a-given-url.com")!
        let (sut, client) = makeSUT(url: url)
        
        sut?.load { _ in }
        
        #expect(client.requestedURLs == [url])
    }
    
    @Test func loadTwice_requestsDataFromURLTwice() {
        let url = URL(string: "https://a-given-url.com")!
        let (sut, client) = makeSUT(url: url)
        
        sut?.load { _ in }
        sut?.load { _ in }
        
        #expect(client.requestedURLs == [url, url])
    }
    
    @Test func load_deliversErrorOnClientError() async {
        let (sut, client) = makeSUT()
        
        await expect(sut, toCompleteWithResult: failure(.connectivity), location: #_sourceLocation) {
                let clientError = NSError(domain: "Test", code: 0)
                client.complete(with: clientError)
        }
    }
    
    @Test func load_deliversErrorOnNon200HTTPResponse() async {
        let (sut, client) = makeSUT()
        
        let statusCodes: [Int] = [199, 201, 300, 400, 500]
        
        for (index, statusCode) in statusCodes.enumerated() {
            await expect( sut, toCompleteWithResult: failure(.invalidData), location: #_sourceLocation) {
                    let json = makeItemsJson([])
                client.complete(withStatusCode: statusCode, data: json, at: index)
            }
        }
    }
    
    @Test func load_deliversErrorOn200HTTPResponseWithInvalidJson() async {
        let (sut, client) = makeSUT()
        
        await expect( sut, toCompleteWithResult: failure(.invalidData), location: #_sourceLocation) {
                let invalidJSON = Data("invalid JSON".utf8)
                client.complete(withStatusCode: 200, data: invalidJSON)
        }
    }
    
    @Test func load_deliversNoItemsOn200HTTPResponseWithEmptyJson() async {
        let (sut, client) = makeSUT()
        
        await expect(sut, toCompleteWithResult: .success([]), location: #_sourceLocation) {
            let json = makeItemsJson([])
            client.complete(withStatusCode: 200, data: json)
        }
    }
    
    @Test func load_deliversItemsOn200HTTPResponseWithValidJson() async {
        var (sut, client) = makeSUT()
        
        let item1 = makeItem(
            id: UUID(),
            imageURL: URL(string: "https://a-given-url.com")!)
        
        let item2 = makeItem(
            id: UUID(),
            description: "some desc",
            location: "some location",
            imageURL: URL(string: "https://b-given-url.com")!)
        
        let json = makeItemsJson([item1.json, item2.json])
        
        await expect(sut, toCompleteWithResult: .success([item1.model, item2.model]), location: #_sourceLocation) {
            sut = nil
            client.complete(withStatusCode: 200, data: json)
        }
    }
    
    @Test func load_doesNotDeliverResultAfterSUTInstanceHasBeenDeallocated() {
        var (sut, client) = makeSUT()
        
        var capturedResults = [RemoteFeedLoader.Result]()
        sut?.load { capturedResults.append($0) }
        sut = nil
        
        client.complete(withStatusCode: 200, data: makeItemsJson([]))
        
        #expect(capturedResults.isEmpty)
    }
}

// MARK: Helpers
extension Tests_RemoteFeedLoader {
   
    private func makeSUT(url: URL = URL(string: "https://a-url.com")!, _ source: SourceLocation = #_sourceLocation) -> (sut: RemoteFeedLoader?, client: HTTPClientSpy) {
        
        let client = leakChecker.checkForMemoryLeak(HTTPClientSpy(), source)
        let sut = leakChecker.checkForMemoryLeak(RemoteFeedLoader(url: url, client: client), source)
        
        return (sut, client)
    }
    
    private func expect( _ sut: RemoteFeedLoader?, toCompleteWithResult expectedResult: RemoteFeedLoader.Result, location: SourceLocation, when action: () -> Void ) async {
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
    
    private func failure(_ error: RemoteFeedLoader.Error) -> RemoteFeedLoader.Result {
        return .failure(error)
    }
    
    private func makeItemsJson(_ items: [[String: Any]]) -> Data {
        let itemsJSON = ["items": items]
        return try! JSONSerialization.data(withJSONObject: itemsJSON)
    }
    
    private func makeItem( id: UUID, description: String? = nil, location: String? = nil, imageURL: URL ) -> (model: FeedImage, json: [String: Any]) {
        
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
