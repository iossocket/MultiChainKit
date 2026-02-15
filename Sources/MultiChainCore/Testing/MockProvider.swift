//
//  MockProvider.swift
//  MultiChainCore
//
//  A mock provider for deterministic testing without network access.

import Foundation

// MARK: - MockProvider

/// A mock `Provider` that returns pre-configured responses.
/// Useful for unit testing without hitting real RPC endpoints.
///
/// ```swift
/// let mock = MockProvider<Ethereum>(chain: .sepolia)
/// mock.enqueue("0x1234")           // next send() returns this
/// mock.enqueueError(.timeout)      // next send() throws this
/// let result: String = try await mock.send(request: someRequest)
/// ```
public final class MockProvider<C: Chain>: Provider, @unchecked Sendable {
  public let chain: C

  private var responses: [Any] = []
  private var errors: [Error?] = []
  /// All requests that were sent through this provider, for assertions.
  public private(set) var sentRequests: [ChainRequest] = []

  public init(chain: C) {
    self.chain = chain
  }

  // MARK: - Enqueue Responses

  /// Enqueue a successful response value. Consumed FIFO by `send(request:)`.
  public func enqueue<R: Encodable>(_ value: R) {
    responses.append(value)
    errors.append(nil)
  }

  /// Enqueue an error. Consumed FIFO by `send(request:)`.
  public func enqueueError(_ error: Error) {
    responses.append(()) // placeholder
    errors.append(error)
  }

  /// Enqueue a batch response. Consumed FIFO by `send(requests:)`.
  public func enqueueBatch<R>(_ results: [Result<R, ProviderError>]) {
    responses.append(results)
    errors.append(nil)
  }

  // MARK: - Provider Protocol

  public func send<R: Decodable>(request: ChainRequest) async throws -> R {
    sentRequests.append(request)

    guard !errors.isEmpty else {
      fatalError("MockProvider: no responses enqueued for request '\(request.method)'")
    }

    let error = errors.removeFirst()
    let response = responses.removeFirst()

    if let error {
      throw error
    }

    guard let typed = response as? R else {
      fatalError(
        "MockProvider: enqueued response type \(type(of: response)) doesn't match expected \(R.self) for '\(request.method)'"
      )
    }
    return typed
  }

  public func send<R: Decodable>(requests: [ChainRequest]) async throws -> [Result<R, ProviderError>] {
    for req in requests {
      sentRequests.append(req)
    }

    guard !errors.isEmpty else {
      fatalError("MockProvider: no responses enqueued for batch request")
    }

    let error = errors.removeFirst()
    let response = responses.removeFirst()

    if let error {
      throw error
    }

    guard let typed = response as? [Result<R, ProviderError>] else {
      fatalError(
        "MockProvider: enqueued batch response type doesn't match expected [Result<\(R.self), ProviderError>]"
      )
    }
    return typed
  }

  // MARK: - Inspection

  /// The number of remaining enqueued responses.
  public var pendingResponseCount: Int { responses.count }

  /// Reset all enqueued responses and recorded requests.
  public func reset() {
    responses.removeAll()
    errors.removeAll()
    sentRequests.removeAll()
  }
}
