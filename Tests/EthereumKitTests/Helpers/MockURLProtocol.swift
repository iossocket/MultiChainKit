//
//  MockURLProtocol.swift
//  EthereumKitTests
//

import Foundation

class MockURLProtocol: URLProtocol {
  static var mockResponse: (Data, HTTPURLResponse)?
  static var mockError: Error?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    if let error = Self.mockError {
      client?.urlProtocol(self, didFailWithError: error)
      return
    }

    if let (data, response) = Self.mockResponse {
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
    }
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}

  static func reset() {
    mockResponse = nil
    mockError = nil
  }

  static func setJsonResponse(_ json: String, statusCode: Int = 200) {
    mockResponse = (
      json.data(using: .utf8)!,
      HTTPURLResponse(
        url: URL(string: "https://mock.test")!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
      )!
    )
  }
}
