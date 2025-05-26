//
//  URLSessionHTTPClientTests.swift
//  Tests presentation
//
//  Created by Igor Tokalenko on 15.05.2025.
//

import Testing
import Tests_presentation
import Foundation

@Suite(.serialized) class URLSessionHTTPClientTests {
    /// LeakChecker to track memory leaks
    private let leakChecker = LeakChecker()

    @Test func test_getFromURL_performsRequestWithURL() async {
        let url = anyURL()
        var receivedRequest: URLRequest?
        await withCheckedContinuation { continuation in
            URLProtocolStub.observeRequests { request in
                receivedRequest = request
            }
           
            makeSUT().get(from: url) { _ in
                continuation.resume()
            }
        }
        #expect(receivedRequest?.url == url)
        #expect(receivedRequest?.httpMethod == "GET")
    }
    
    @Test func test_getFromURL_failsOnRequestError() async {
        let requestError = anyNSError()
        let receivedError = await resultsErrorFor(data: nil, response: nil, error: requestError) as? NSError
        
        #expect(receivedError?.domain == requestError.domain)
    }
    
    @Test func test_getFromURL_failsOnAllNilValues() async {
        await #expect(resultsErrorFor(data: nil, response: nil, error: nil) != nil)
        await #expect(resultsErrorFor(data: nil, response: nonURLResponse(), error: nil) != nil)
        await #expect(resultsErrorFor(data: anyData(), response: nil, error: nil) != nil)
        await #expect(resultsErrorFor(data: anyData(), response: nil, error: anyNSError()) != nil)
        await #expect(resultsErrorFor(data: nil, response: nonURLResponse(), error: anyNSError()) != nil)
        await #expect(resultsErrorFor(data: nil, response: anyHTTPURLResponse(), error: anyNSError()) != nil)
        await #expect(resultsErrorFor(data: anyData(), response: nonURLResponse(), error: anyNSError()) != nil)
        await #expect(resultsErrorFor(data: anyData(), response: anyHTTPURLResponse(), error: anyNSError()) != nil)
        await #expect(resultsErrorFor(data: anyData(), response: nonURLResponse(), error: nil) != nil)
    }
    
    @Test func test_getFromURL_successOnHTTPURLResponseWithData() async {
        let data = anyData()
        let response = anyHTTPURLResponse()
        let receivedValues = await resultsValueFor(data: data, response: response, error: nil)
        
        #expect(receivedValues?.data == data)
        #expect(receivedValues?.response.url == response.url)
        #expect(receivedValues?.response.statusCode == response.statusCode)
    }
    
    @Test func test_getFromURL_successWithEmptyDataOnHTTPURLResponseWithNilData() async {
        let response = anyHTTPURLResponse()
        let receivedValues = await resultsValueFor(data: nil, response: response, error: nil)
        
        let emptyData = Data()
        #expect(receivedValues?.data == emptyData)
        #expect(receivedValues?.response.url == response.url)
        #expect(receivedValues?.response.statusCode == response.statusCode)
    }
}

extension URLSessionHTTPClientTests {
    // MARK: - Helpers
    func makeSUT(location: SourceLocation = #_sourceLocation) -> HTTPClient {
        let sut = leakChecker.checkForMemoryLeak(URLSessionHTTPClient(session: .mockSession()))
        return sut
    }
    
    private func anyData() -> Data {
        Data("any data".utf8)
    }
    
    private func anyNSError() -> NSError {
        NSError(domain: "any domain", code: 0)
    }
    
    private func nonURLResponse() -> URLResponse {
        URLResponse(url: anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    }
    
    private func anyHTTPURLResponse() -> HTTPURLResponse {
        HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
    }
    
    private func anyURL() -> URL {
        URL(string: "http://any-url.com")!
    }
    
    private func resultsValueFor(data: Data? = nil, response: URLResponse? = nil, error: Error? = nil, location: SourceLocation = #_sourceLocation) async -> (data: Data, response: HTTPURLResponse)? {
        let result = await resultFor(data: data, response: response, error: error)
        
        switch result {
        case let .success(data, response):
            return (data, response)
        default:
            Issue.record("expected success, got \(result) instead", sourceLocation: location)
            return nil
        }
    }
    
    private func resultsErrorFor(data: Data? = nil, response: URLResponse? = nil, error: Error?, location: SourceLocation = #_sourceLocation) async -> Error? {
        let result = await resultFor(data: data, response: response, error: error)
        
        switch result {
        case let .failure(error as NSError):
            return error
        default:
            Issue.record("expected error, got \(result) instead", sourceLocation: location)
            return nil
        }
    }
   
    private func resultFor(data: Data? = nil, response: URLResponse? = nil, error: Error? = nil, location: SourceLocation = #_sourceLocation) async -> HTTPClientResult {
        
        URLProtocolStub.setRequestHandler { _ in
            (response, data, error)
        }
        let sut = makeSUT()
        return await withCheckedContinuation { continuation in
           
            sut.get(from: anyURL()) { result in
                continuation.resume(returning: result)
            }
        }
    }
}

extension URLSession {
    static func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }
}
