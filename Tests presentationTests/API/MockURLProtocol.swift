//
//  MockURLProtocol.swift
//  Tests presentation
//
//  Created by Igor Tokalenko on 26.05.2025.
//


import Foundation

class URLProtocolStub: URLProtocol {
    private static var requestHandler: ((URLRequest) -> (URLResponse?, Data?, Error?))?
    private static var requestsObserver: ((URLRequest) -> Void)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        if let observer = URLProtocolStub.requestsObserver {
            client?.urlProtocolDidFinishLoading(self)
            observer(request)
            URLProtocolStub.requestsObserver = nil
            return
        }

        guard let handler = URLProtocolStub.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let (response, data, error) = handler(request)

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            if let response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
        URLProtocolStub.requestHandler = nil
    }

    override func stopLoading() {}

    static func setRequestHandler(_ handler: @escaping (URLRequest) -> (URLResponse?, Data?, Error?)) {
        requestHandler = handler
    }

    static func observerRequests(observer: @escaping (URLRequest) -> Void) {
        requestsObserver = observer
    }
}
