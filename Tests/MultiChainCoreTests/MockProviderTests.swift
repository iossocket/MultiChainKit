//
//  MockProviderTests.swift
//  MultiChainCoreTests
//

import XCTest
@testable import MultiChainCore

// MARK: - Test Chain

/// Minimal Chain conformance for testing MockProvider.
private struct TestChain: Chain {
  typealias Value = TestValue
  typealias Address = TestAddress
  typealias Transaction = TestTransaction
  typealias Signature = TestSignature
  typealias Receipt = TestReceipt

  var id: String { "test-1" }
  var name: String { "TestChain" }
  var isTestnet: Bool { true }
  var rpcURL: URL { URL(string: "https://test.rpc")! }
}

private struct TestValue: ChainValue, ExpressibleByIntegerLiteral {
  let raw: Int
  var hexString: String { "0x\(String(raw, radix: 16))" }
  var description: String { hexString }
  init(integerLiteral value: Int) { self.raw = value }
  init(_ int: UInt64) { self.raw = Int(int) }
  init?(_ hex: String) { self.raw = Int(hex.dropFirst(2), radix: 16) ?? 0 }
  static var zero: TestValue { 0 }
  static func < (lhs: TestValue, rhs: TestValue) -> Bool { lhs.raw < rhs.raw }
}

private struct TestAddress: ChainAddress {
  var checksummed: String { "0xtest" }
  var description: String { checksummed }
  var data: Data { Data() }
  init?(_ string: String) {}
  init(_ data: Data) {}
  static var zero: TestAddress { TestAddress("0x")! }
}

private struct TestTransaction: ChainTransaction {
  typealias C = TestChain
  var hash: Data? { nil }
  var chainId: String { "test-1" }
  func hashForSigning() -> Data { Data() }
  func encode() -> Data { Data() }
}

private struct TestSignature: ChainSignature {
  var rawData: Data { Data() }
}

private struct TestReceipt: ChainReceipt {
  var transactionHash: Data { Data() }
  var isSuccess: Bool { true }
  var blockNumber: UInt64? { nil }
}

// MARK: - Tests

final class MockProviderTests: XCTestCase {

  func testEnqueueAndSend() async throws {
    let mock = MockProvider<TestChain>(chain: TestChain())
    mock.enqueue("0x1234")

    let result: String = try await mock.send(
      request: ChainRequest(method: "test_method"))

    XCTAssertEqual(result, "0x1234")
    XCTAssertEqual(mock.sentRequests.count, 1)
    XCTAssertEqual(mock.sentRequests[0].method, "test_method")
  }

  func testEnqueueError() async {
    let mock = MockProvider<TestChain>(chain: TestChain())
    mock.enqueueError(ProviderError.timeout)

    do {
      let _: String = try await mock.send(
        request: ChainRequest(method: "test_method"))
      XCTFail("Expected error")
    } catch {
      XCTAssertTrue(error is ProviderError)
      if case ProviderError.timeout = error {} else {
        XCTFail("Expected timeout, got \(error)")
      }
    }
  }

  func testFIFOOrdering() async throws {
    let mock = MockProvider<TestChain>(chain: TestChain())
    mock.enqueue("first")
    mock.enqueue("second")
    mock.enqueue("third")

    let r1: String = try await mock.send(request: ChainRequest(method: "a"))
    let r2: String = try await mock.send(request: ChainRequest(method: "b"))
    let r3: String = try await mock.send(request: ChainRequest(method: "c"))

    XCTAssertEqual(r1, "first")
    XCTAssertEqual(r2, "second")
    XCTAssertEqual(r3, "third")
    XCTAssertEqual(mock.pendingResponseCount, 0)
  }

  func testBatchSend() async throws {
    let mock = MockProvider<TestChain>(chain: TestChain())
    let batchResults: [Result<String, ProviderError>] = [
      .success("0xaaa"),
      .failure(.rpcError(code: -1, message: "fail")),
    ]
    mock.enqueueBatch(batchResults)

    let results: [Result<String, ProviderError>] = try await mock.send(requests: [
      ChainRequest(method: "a"),
      ChainRequest(method: "b"),
    ])

    XCTAssertEqual(results.count, 2)
    if case .success(let v) = results[0] {
      XCTAssertEqual(v, "0xaaa")
    } else { XCTFail("Expected success") }
    if case .failure(let e) = results[1] {
      XCTAssertEqual(e.description, "RPC error -1: fail")
    } else { XCTFail("Expected failure") }
  }

  func testReset() async throws {
    let mock = MockProvider<TestChain>(chain: TestChain())
    mock.enqueue("value")
    let _: String = try await mock.send(request: ChainRequest(method: "x"))

    XCTAssertEqual(mock.sentRequests.count, 1)
    XCTAssertEqual(mock.pendingResponseCount, 0)

    mock.enqueue("another")
    mock.reset()

    XCTAssertEqual(mock.sentRequests.count, 0)
    XCTAssertEqual(mock.pendingResponseCount, 0)
  }

  func testMixedSuccessAndError() async throws {
    let mock = MockProvider<TestChain>(chain: TestChain())
    mock.enqueue("ok")
    mock.enqueueError(ProviderError.invalidResponse)
    mock.enqueue("recovered")

    let r1: String = try await mock.send(request: ChainRequest(method: "a"))
    XCTAssertEqual(r1, "ok")

    do {
      let _: String = try await mock.send(request: ChainRequest(method: "b"))
      XCTFail("Expected error")
    } catch {
      XCTAssertTrue(error is ProviderError)
    }

    let r3: String = try await mock.send(request: ChainRequest(method: "c"))
    XCTAssertEqual(r3, "recovered")
    XCTAssertEqual(mock.sentRequests.count, 3)
  }
}
