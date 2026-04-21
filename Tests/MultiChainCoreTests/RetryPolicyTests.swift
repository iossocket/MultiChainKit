//
//  RetryPolicyTests.swift
//  MultiChainCoreTests
//

import XCTest

@testable import MultiChainCore

final class RetryPolicyTests: XCTestCase {

  // MARK: - Presets

  func testDefaultPresetIsSensibleForProduction() {
    let p = RetryPolicy.default

    XCTAssertGreaterThan(p.maxAttempts, 1, "default must retry at least once")
    XCTAssertLessThanOrEqual(p.maxAttempts, 5, "default should not retry aggressively")
    XCTAssertGreaterThan(p.baseDelay, 0)
    XCTAssertGreaterThanOrEqual(p.maxDelay, p.baseDelay)
    XCTAssertGreaterThanOrEqual(p.jitter, 0)
    XCTAssertLessThanOrEqual(p.jitter, 1)
    XCTAssertFalse(
      p.retryableHTTPStatusCodes.contains(429),
      "429 must NOT auto-retry by default — caller handles rate limits")
    XCTAssertTrue(p.retryableHTTPStatusCodes.contains(503), "503 must be retryable")
    XCTAssertTrue(p.retryableHTTPStatusCodes.contains(502))
    XCTAssertTrue(p.retryableHTTPStatusCodes.contains(504))
  }

  func testNonePresetDisablesRetry() {
    let p = RetryPolicy.none

    XCTAssertEqual(p.maxAttempts, 1, "none means exactly one attempt")
    XCTAssertTrue(p.retryableHTTPStatusCodes.isEmpty)
    XCTAssertTrue(p.retryableRPCErrorCodes.isEmpty)
  }

  // MARK: - delay(forAttempt:)

  func testDelayBoundsForZeroJitter() {
    let p = RetryPolicy(
      maxAttempts: 5, baseDelay: 0.1, maxDelay: 1.0, jitter: 0.0,
      retryableHTTPStatusCodes: [], retryableRPCErrorCodes: [])

    // attempt 1: baseDelay * 2^0 = 0.1
    XCTAssertEqual(p.delay(forAttempt: 1), 0.1, accuracy: 1e-6)
    // attempt 2: 0.1 * 2 = 0.2
    XCTAssertEqual(p.delay(forAttempt: 2), 0.2, accuracy: 1e-6)
    // attempt 3: 0.1 * 4 = 0.4
    XCTAssertEqual(p.delay(forAttempt: 3), 0.4, accuracy: 1e-6)
    // attempt 4: 0.1 * 8 = 0.8
    XCTAssertEqual(p.delay(forAttempt: 4), 0.8, accuracy: 1e-6)
    // attempt 5: 0.1 * 16 = 1.6 → clamped to maxDelay 1.0
    XCTAssertEqual(p.delay(forAttempt: 5), 1.0, accuracy: 1e-6)
  }

  func testDelayNeverExceedsMaxEvenAtLargeAttempts() {
    let p = RetryPolicy(
      maxAttempts: 100, baseDelay: 0.1, maxDelay: 5.0, jitter: 0.5,
      retryableHTTPStatusCodes: [], retryableRPCErrorCodes: [])

    // With 50% jitter, upper bound on clamped delay is maxDelay * 1.5.
    // Must never exceed that.
    for attempt in 1...20 {
      let d = p.delay(forAttempt: attempt)
      XCTAssertGreaterThanOrEqual(d, 0)
      XCTAssertLessThanOrEqual(d, p.maxDelay * (1 + p.jitter) + 1e-9)
    }
  }

  func testJitterProducesVariance() {
    let p = RetryPolicy(
      maxAttempts: 10, baseDelay: 1.0, maxDelay: 100.0, jitter: 0.5,
      retryableHTTPStatusCodes: [], retryableRPCErrorCodes: [])

    // With jitter 0.5 on a base of 1.0, repeated calls should produce different values.
    let samples = (0..<20).map { _ in p.delay(forAttempt: 1) }
    let unique = Set(samples.map { String(format: "%.6f", $0) })
    XCTAssertGreaterThan(unique.count, 1, "jittered delay must not be deterministic")

    // All within ±jitter of the nominal 1.0s.
    for s in samples {
      XCTAssertGreaterThanOrEqual(s, 0.5 - 1e-9)
      XCTAssertLessThanOrEqual(s, 1.5 + 1e-9)
    }
  }

  func testDelayIsMonotonicBeforeClamping() {
    let p = RetryPolicy(
      maxAttempts: 10, baseDelay: 0.1, maxDelay: 1000.0, jitter: 0.0,
      retryableHTTPStatusCodes: [], retryableRPCErrorCodes: [])

    var prev: TimeInterval = 0
    for attempt in 1...8 {
      let d = p.delay(forAttempt: attempt)
      XCTAssertGreaterThan(d, prev, "delay must strictly grow before hitting maxDelay")
      prev = d
    }
  }

  // MARK: - shouldRetry(_:)

  func testShouldRetryHTTPStatusWhitelist() {
    let p = RetryPolicy.default

    XCTAssertFalse(
      p.shouldRetry(.http(status: 429, body: nil)),
      "429 must fail fast — caller decides how to react to rate limits")
    XCTAssertTrue(p.shouldRetry(.http(status: 502, body: nil)))
    XCTAssertTrue(p.shouldRetry(.http(status: 503, body: nil)))
    XCTAssertFalse(p.shouldRetry(.http(status: 400, body: nil)), "4xx client errors must NOT retry")
    XCTAssertFalse(p.shouldRetry(.http(status: 401, body: nil)))
    XCTAssertFalse(p.shouldRetry(.http(status: 404, body: nil)))
  }

  func testShouldRetryRPCErrorWhitelist() {
    let p = RetryPolicy.default

    // -32603 is in the default whitelist (internal error)
    XCTAssertTrue(p.shouldRetry(.rpcError(code: -32603, message: "internal")))
    // -32602 (invalid params) is a permanent client error — never retry
    XCTAssertFalse(p.shouldRetry(.rpcError(code: -32602, message: "invalid params")))
    // -32601 (method not found) — never retry
    XCTAssertFalse(p.shouldRetry(.rpcError(code: -32601, message: "method not found")))
  }

  func testShouldRetryNetworkError() {
    let p = RetryPolicy.default
    // Generic transport failures are retryable under default policy
    XCTAssertTrue(p.shouldRetry(.networkError("connection reset")))
    XCTAssertTrue(p.shouldRetry(.timeout))
  }

  func testShouldNeverRetryCancellation() {
    let p = RetryPolicy.default
    XCTAssertFalse(p.shouldRetry(.cancelled), ".cancelled must never retry")
  }

  func testShouldNeverRetryDecodingError() {
    let p = RetryPolicy.default
    // A decoding error is deterministic — retrying won't help
    XCTAssertFalse(p.shouldRetry(.decodingError("bad json")))
  }

  func testNonePolicyRefusesAllRetries() {
    let p = RetryPolicy.none

    XCTAssertFalse(p.shouldRetry(.http(status: 503, body: nil)))
    XCTAssertFalse(p.shouldRetry(.rpcError(code: -32603, message: "x")))
    XCTAssertFalse(p.shouldRetry(.networkError("any")))
    XCTAssertFalse(p.shouldRetry(.timeout))
  }
}

// MARK: - ChainRequest.isIdempotent

final class ChainRequestIdempotencyTests: XCTestCase {

  func testDefaultIsIdempotent() {
    let req = ChainRequest(method: "eth_getBalance", params: [])
    XCTAssertTrue(req.isIdempotent, "reads default to idempotent")
  }

  func testExplicitNonIdempotent() {
    let req = ChainRequest(method: "eth_sendRawTransaction", params: [], isIdempotent: false)
    XCTAssertFalse(req.isIdempotent)
  }
}

// MARK: - ProviderError.cancelled

final class ProviderErrorCancelledTests: XCTestCase {

  func testCancelledEquality() {
    XCTAssertEqual(ProviderError.cancelled, ProviderError.cancelled)
    XCTAssertNotEqual(ProviderError.cancelled, ProviderError.timeout)
  }

  func testCancelledDescription() {
    XCTAssertEqual(ProviderError.cancelled.description, "Cancelled")
  }

  func testHTTPErrorCarriesBody() {
    let body = Data("rate limited".utf8)
    let err = ProviderError.http(status: 429, body: body)
    if case .http(let status, let b) = err {
      XCTAssertEqual(status, 429)
      XCTAssertEqual(b, body)
    } else {
      XCTFail("expected .http case")
    }
  }
}
