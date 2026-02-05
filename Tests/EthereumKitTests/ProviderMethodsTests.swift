//
//  ProviderMethodsTests.swift
//  EthereumKitTests
//

import XCTest

@testable import EthereumKit

final class ProviderMethodsTests: XCTestCase {

  let provider = EthereumProvider(chain: .mainnet)
  let testAddress = EthereumAddress("0x742d35Cc6634C0532925a3b844Bc9e7595f5bE91")!

  // MARK: - eth_getBalance

  func testGetBalanceRequest() {
    let request = provider.getBalanceRequest(address: testAddress, block: .latest)

    XCTAssertEqual(request.method, "eth_getBalance")
    XCTAssertEqual(request.params.count, 2)
  }

  func testGetBalanceRequestWithPendingBlock() {
    let request = provider.getBalanceRequest(address: testAddress, block: .pending)

    XCTAssertEqual(request.method, "eth_getBalance")
  }

  func testGetBalanceRequestWithBlockNumber() {
    let request = provider.getBalanceRequest(address: testAddress, block: .number(12_345_678))

    XCTAssertEqual(request.method, "eth_getBalance")
  }

  // MARK: - eth_getTransactionCount (nonce)

  func testGetTransactionCountRequest() {
    let request = provider.getTransactionCountRequest(address: testAddress, block: .latest)

    XCTAssertEqual(request.method, "eth_getTransactionCount")
    XCTAssertEqual(request.params.count, 2)
  }

  func testGetTransactionCountRequestWithPendingBlock() {
    let request = provider.getTransactionCountRequest(address: testAddress, block: .pending)

    XCTAssertEqual(request.method, "eth_getTransactionCount")
  }

  // MARK: - eth_getCode

  func testGetCodeRequest() {
    let request = provider.getCodeRequest(address: testAddress, block: .latest)

    XCTAssertEqual(request.method, "eth_getCode")
    XCTAssertEqual(request.params.count, 2)
  }

  // MARK: - eth_getStorageAt

  func testGetStorageAtRequest() {
    let position = "0x0"
    let request = provider.getStorageAtRequest(
      address: testAddress, position: position, block: .latest)

    XCTAssertEqual(request.method, "eth_getStorageAt")
    XCTAssertEqual(request.params.count, 3)
  }

  // MARK: - eth_getBlockByNumber

  func testGetBlockByNumberRequest() {
    let request = provider.getBlockByNumberRequest(block: .latest, fullTransactions: false)

    XCTAssertEqual(request.method, "eth_getBlockByNumber")
    XCTAssertEqual(request.params.count, 2)
  }

  func testGetBlockByNumberRequestWithFullTransactions() {
    let request = provider.getBlockByNumberRequest(
      block: .number(12_345_678), fullTransactions: true)

    XCTAssertEqual(request.method, "eth_getBlockByNumber")
  }

  // MARK: - eth_getTransactionByHash

  func testGetTransactionByHashRequest() {
    let txHash = "0x" + String(repeating: "ab", count: 32)
    let request = provider.getTransactionByHashRequest(hash: txHash)

    XCTAssertEqual(request.method, "eth_getTransactionByHash")
    XCTAssertEqual(request.params.count, 1)
  }

  // MARK: - eth_feeHistory (EIP-1559)

  func testFeeHistoryRequest() {
    let request = provider.feeHistoryRequest(
      blockCount: 4, newestBlock: .latest, rewardPercentiles: [25, 50, 75])

    XCTAssertEqual(request.method, "eth_feeHistory")
    XCTAssertEqual(request.params.count, 3)
  }

  // MARK: - eth_maxPriorityFeePerGas (EIP-1559)

  func testMaxPriorityFeePerGasRequest() {
    let request = provider.maxPriorityFeePerGasRequest()

    XCTAssertEqual(request.method, "eth_maxPriorityFeePerGas")
    XCTAssertEqual(request.params.count, 0)
  }
}

// MARK: - Mock Network Tests

final class ProviderMethodsMockTests: XCTestCase {

  override func tearDown() {
    MockURLProtocol.reset()
  }

  func testSendGetBalance() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    // 1 ETH = 1000000000000000000 wei = 0xde0b6b3a7640000
    MockURLProtocol.setJsonResponse(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"0xde0b6b3a7640000\"}")

    let provider = EthereumProvider(chain: .mainnet, session: session)
    let address = EthereumAddress("0x742d35Cc6634C0532925a3b844Bc9e7595f5bE91")!
    let result: String = try await provider.send(
      request: provider.getBalanceRequest(address: address, block: .latest))

    XCTAssertEqual(result, "0xde0b6b3a7640000")
  }

  func testSendGetTransactionCount() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    MockURLProtocol.setJsonResponse("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"0x5\"}")

    let provider = EthereumProvider(chain: .mainnet, session: session)
    let address = EthereumAddress("0x742d35Cc6634C0532925a3b844Bc9e7595f5bE91")!
    let result: String = try await provider.send(
      request: provider.getTransactionCountRequest(address: address, block: .latest))

    XCTAssertEqual(result, "0x5")
  }

  func testSendFeeHistory() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    let json = """
      {"jsonrpc":"2.0","id":1,"result":{"oldestBlock":"0x1234","baseFeePerGas":["0x1","0x2"],"gasUsedRatio":[0.5],"reward":[["0x1"]]}}
      """
    MockURLProtocol.setJsonResponse(json)

    let provider = EthereumProvider(chain: .mainnet, session: session)
    let result: FeeHistory = try await provider.send(
      request: provider.feeHistoryRequest(
        blockCount: 1, newestBlock: .latest, rewardPercentiles: [50]))

    XCTAssertEqual(result.oldestBlock, "0x1234")
  }
}

// MARK: - Anvil Integration Tests

final class ProviderMethodsAnvilTests: XCTestCase {

  lazy var provider = EthereumProvider(
    chainId: 31337,
    name: "Anvil",
    url: URL(string: "http://127.0.0.1:8545")!,
    isTestnet: true
  )

  // Anvil default account
  let anvilAddress = EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!

  override func setUpWithError() throws {
    try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil, "Skip on CI")
  }

  func testGetBalance() async throws {
    let result: String = try await provider.send(
      request: provider.getBalanceRequest(address: anvilAddress, block: .latest))

    // Anvil default accounts have 10000 ETH
    XCTAssertTrue(result.hasPrefix("0x"))
  }

  func testGetTransactionCount() async throws {
    let result: String = try await provider.send(
      request: provider.getTransactionCountRequest(address: anvilAddress, block: .latest))

    XCTAssertNotNil(result)
  }

  func testGetCode() async throws {
    // EOA has no code
    let result: String = try await provider.send(
      request: provider.getCodeRequest(address: anvilAddress, block: .latest))

    XCTAssertEqual(result, "0x")
  }

  func testGetBlockByNumber() async throws {
    let result: EthereumBlock = try await provider.send(
      request: provider.getBlockByNumberRequest(block: .latest, fullTransactions: false))

    XCTAssertNotNil(result.number)
  }

  func testMaxPriorityFeePerGas() async throws {
    let result: String = try await provider.send(request: provider.maxPriorityFeePerGasRequest())

    XCTAssertTrue(result.hasPrefix("0x"))
  }
}
