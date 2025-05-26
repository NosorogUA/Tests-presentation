//
//  URLSessionHTTPClientTests.swift
//  Tests presentation
//
//  Created by Igor Tokalenko on 15.05.2025.
//

import Testing
import Tests_presentation
import Foundation

class URLSessionHTTPClientTests {
    /// LeakChecker to track memory leaks
    private let leakChecker = LeakChecker()
    
    init() {
        URLProtocolStub.startInterceptingRequests()
    }
    
    deinit {
        URLProtocolStub.stopInterceptingRequests()
    }
    
    @Test func test_getFromURL_performsRequestWithURL() async {
        let url = anyURL()
        var receivedRequest: URLRequest?
        await withCheckedContinuation { continuation in
            URLProtocolStub.observerRequests { request in
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
        let sut = leakChecker.checkForMemoryLeak(URLSessionHTTPClient())
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
            Issue.record("expected success, got \(result) instead", sourceLocation: location)
            return nil
        }
    }
    
    private func resultFor(data: Data? = nil, response: URLResponse? = nil, error: Error? = nil, location: SourceLocation = #_sourceLocation) async -> HTTPClientResult {
        
        return await withCheckedContinuation { continuation in
            URLProtocolStub.stub(data: data, response: response, error: error)
            let sut = makeSUT()
            sut.get(from: anyURL()) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    fileprivate class URLProtocolStub: URLProtocol {
        private static var stub: Stub?
        private static var requestsObserver: ((URLRequest) -> Void)?
        private struct Stub {
            let data: Data?
            let response: URLResponse?
            let error: Error?
        }
        
        static func startInterceptingRequests() {
            URLProtocol.registerClass(URLProtocolStub.self)
        }
        
        static func stopInterceptingRequests() {
            URLProtocol.unregisterClass(URLProtocolStub.self)
            stub = nil
            requestsObserver = nil
        }
        
        static func observerRequests(observer: @escaping (URLRequest) -> Void) {
            requestsObserver = observer
        }
        
        static func stub(data: Data?, response: URLResponse?, error: Error? = nil) {
            stub = Stub(data: data, response: response, error: error)
        }
        
        override class func canInit(with request: URLRequest) -> Bool {
            return true
        }
        
        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }
        
        override func startLoading() {
            if let requestsObserver = URLProtocolStub.requestsObserver {
                client?.urlProtocolDidFinishLoading(self)
                requestsObserver(request)
                URLProtocolStub.requestsObserver = nil
                return
            }
            
            if let error = URLProtocolStub.stub?.error {
                client?.urlProtocol(self, didFailWithError: error)
            } else {
                
                if let response = URLProtocolStub.stub?.response {
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                }
                
                if let data = URLProtocolStub.stub?.data {
                    client?.urlProtocol(self, didLoad: data)
                }
                client?.urlProtocolDidFinishLoading(self)
            }
        }
        
        override func stopLoading() {}
    }
}
