//
//  ProviderRetryTests.swift
//  EthereumKitTests
//

import Foundation
import MultiChainCore
import XCTest

@testable import EthereumKit

/// End-to-end tests for the retry + cancellation behavior of `JsonRpcProvider`.
/// These exercise `send(request:retryPolicy:)` and the `URLError.cancelled` mapping
/// on the base `send(request:)` path.
final class ProviderRetryTests: XCTestCase {

  // MARK: - Fixtures

  private func makeProvider() -> EthereumProvider {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)
    return EthereumProvider(chain: .mainnet, session: session)
  }

  private let successJson = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"0xdead\"}"

  override func tearDown() {
    MockURLProtocol.reset()
  }

  // MARK: - Retry on transient failure

  /// The first 2 attempts return 503, the 3rd succeeds. Under a 3-attempt policy
  /// on an idempotent request, we expect success and exactly 3 HTTP calls.
  func testRetrySucceedsAfterTransientFailures() async throws {
    MockURLProtocol.enqueueJsonResponse("{}", statusCode: 503)
    MockURLProtocol.enqueueJsonResponse("{}", statusCode: 503)
    MockURLProtocol.enqueueJsonResponse(successJson, statusCode: 200)

    let policy = RetryPolicy(
      maxAttempts: 3, baseDelay: 0.001, maxDelay: 0.01, jitter: 0,
      retryableHTTPStatusCodes: [503], retryableRPCErrorCodes: [])

    let provider = makeProvider()
    let result: String = try await provider.send(
      request: EthereumRequestBuilder.blockNumberRequest(),
      retryPolicy: policy)

    XCTAssertEqual(result, "0xdead")
    XCTAssertEqual(MockURLProtocol.requestCount, 3, "should have retried twice and succeeded on 3rd")
  }

  /// After all attempts fail with a retryable error, the final error surfaces.
  func testRetryExhaustsAndRethrowsLastError() async {
    MockURLProtocol.enqueueJsonResponse("{}", statusCode: 503)
    MockURLProtocol.enqueueJsonResponse("{}", statusCode: 503)
    MockURLProtocol.enqueueJsonResponse("{}", statusCode: 503)

    let policy = RetryPolicy(
      maxAttempts: 3, baseDelay: 0.001, maxDelay: 0.01, jitter: 0,
      retryableHTTPStatusCodes: [503], retryableRPCErrorCodes: [])

    let provider = makeProvider()
    do {
      let _: String = try await provider.send(
        request: EthereumRequestBuilder.blockNumberRequest(),
        retryPolicy: policy)
      XCTFail("expected error after retries exhausted")
    } catch let error as ProviderError {
      if case .http(let status, _) = error {
        XCTAssertEqual(status, 503)
      } else {
        XCTFail("expected .http(503), got \(error)")
      }
    } catch {
      XCTFail("unexpected non-ProviderError: \(error)")
    }

    XCTAssertEqual(MockURLProtocol.requestCount, 3)
  }

  /// A non-retryable error (HTTP 400) must fail on the first attempt, no retries.
  func testNonRetryableErrorDoesNotRetry() async {
    MockURLProtocol.enqueueJsonResponse("{}", statusCode: 400)

    let policy = RetryPolicy.default
    let provider = makeProvider()

    do {
      let _: String = try await provider.send(
        request: EthereumRequestBuilder.blockNumberRequest(),
        retryPolicy: policy)
      XCTFail("expected error")
    } catch let error as ProviderError {
      if case .http(let status, _) = error {
        XCTAssertEqual(status, 400)
      } else {
        XCTFail("expected .http(400), got \(error)")
      }
    } catch {
      XCTFail("unexpected: \(error)")
    }

    XCTAssertEqual(MockURLProtocol.requestCount, 1, "4xx must not be retried")
  }

  // MARK: - Idempotency gate

  /// A non-idempotent request (e.g. eth_sendRawTransaction) must NEVER retry
  /// even when the policy would otherwise allow it.
  /// Reason: the node may have accepted the first submission and a retry would
  /// collide on nonce or risk double-submission.
  func testNonIdempotentRequestIsNotRetried() async {
    MockURLProtocol.enqueueJsonResponse("{}", statusCode: 503)
    MockURLProtocol.enqueueJsonResponse("{}", statusCode: 503)
    MockURLProtocol.enqueueJsonResponse(successJson, statusCode: 200)

    let policy = RetryPolicy(
      maxAttempts: 5, baseDelay: 0.001, maxDelay: 0.01, jitter: 0,
      retryableHTTPStatusCodes: [503], retryableRPCErrorCodes: [])

    let provider = makeProvider()
    let req = EthereumRequestBuilder.sendRawTransactionRequest("0xdeadbeef")
    XCTAssertFalse(req.isIdempotent, "precondition: write must be marked non-idempotent")

    do {
      let _: String = try await provider.send(request: req, retryPolicy: policy)
      XCTFail("expected error — no retry means the 503 surfaces")
    } catch let error as ProviderError {
      if case .http(let status, _) = error {
        XCTAssertEqual(status, 503)
      } else {
        XCTFail("expected .http(503), got \(error)")
      }
    } catch {
      XCTFail("unexpected: \(error)")
    }

    XCTAssertEqual(MockURLProtocol.requestCount, 1, "non-idempotent must not retry")
  }

  // MARK: - Cancellation

  /// URLError.cancelled (from Task.cancel or session invalidation) must map to
  /// ProviderError.cancelled, not leak through as a URLError or generic networkError.
  func testURLCancelMapsToProviderCancelled() async {
    MockURLProtocol.enqueueError(URLError(.cancelled))

    let provider = makeProvider()

    do {
      let _: String = try await provider.send(
        request: EthereumRequestBuilder.blockNumberRequest())
      XCTFail("expected cancellation error")
    } catch let error as ProviderError {
      XCTAssertEqual(error, .cancelled, "URLError.cancelled must map to ProviderError.cancelled")
    } catch {
      XCTFail("expected ProviderError, got \(error)")
    }
  }

  /// Cancelling the outer Task before send runs must surface as ProviderError.cancelled,
  /// not leak CancellationError. The base send wraps Task.checkCancellation() and maps
  /// the thrown error to our typed case.
  func testTaskCancellationBeforeSendThrowsCancelled() async {
    MockURLProtocol.setJsonResponse(successJson)
    let provider = makeProvider()

    let task = Task { () -> String in
      try await provider.send(request: EthereumRequestBuilder.blockNumberRequest())
    }
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("expected cancellation")
    } catch let error as ProviderError {
      XCTAssertEqual(error, .cancelled)
    } catch {
      XCTFail("expected ProviderError.cancelled, got \(error)")
    }
  }

  /// Cancellation while retrying must short-circuit the retry loop. The total
  /// number of attempts must be less than the policy's maxAttempts.
  func testCancellationInterruptsRetryLoop() async {
    // Queue enough 503s that, without cancellation, the loop would exhaust all attempts.
    for _ in 0..<5 {
      MockURLProtocol.enqueueJsonResponse("{}", statusCode: 503)
    }

    // Long inter-attempt delay so the cancel has time to land between attempts.
    let policy = RetryPolicy(
      maxAttempts: 5, baseDelay: 0.5, maxDelay: 1.0, jitter: 0,
      retryableHTTPStatusCodes: [503], retryableRPCErrorCodes: [])

    let provider = makeProvider()

    let task = Task { () -> String in
      try await provider.send(
        request: EthereumRequestBuilder.blockNumberRequest(),
        retryPolicy: policy)
    }

    // Let one attempt fire, then cancel mid-backoff.
    try? await Task.sleep(nanoseconds: 100_000_000)
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("expected cancellation")
    } catch let error as ProviderError {
      XCTAssertEqual(error, .cancelled)
    } catch {
      XCTFail("expected ProviderError.cancelled, got \(error)")
    }

    XCTAssertLessThan(
      MockURLProtocol.requestCount, 5,
      "retry loop must be interrupted by cancellation; observed \(MockURLProtocol.requestCount)")
  }
}
