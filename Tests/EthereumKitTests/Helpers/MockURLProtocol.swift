//
//  MockURLProtocol.swift
//  EthereumKitTests
//

import Foundation

class MockURLProtocol: URLProtocol {
  /// One step in a scripted sequence: either a response or an error.
  enum Step {
    case response(Data, HTTPURLResponse)
    case error(Error)
  }

  static var mockResponse: (Data, HTTPURLResponse)?
  static var mockError: Error?

  /// FIFO queue consumed per request. Overrides `mockResponse` / `mockError` when non-empty.
  /// Thread-safety: tests are single-threaded; URLSession will serialize callbacks.
  static var responseQueue: [Step] = []

  /// Incremented on every startLoading call. Lets tests assert how many attempts were made.
  static var requestCount: Int = 0

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.requestCount += 1

    if !Self.responseQueue.isEmpty {
      let step = Self.responseQueue.removeFirst()
      switch step {
      case .error(let e):
        client?.urlProtocol(self, didFailWithError: e)
        return
      case .response(let data, let response):
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
        return
      }
    }

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
    responseQueue = []
    requestCount = 0
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

  /// Queue a scripted response (one entry per HTTP attempt).
  static func enqueueJsonResponse(_ json: String, statusCode: Int = 200) {
    let resp = HTTPURLResponse(
      url: URL(string: "https://mock.test")!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    )!
    responseQueue.append(.response(json.data(using: .utf8)!, resp))
  }

  static func enqueueError(_ error: Error) {
    responseQueue.append(.error(error))
  }
}
