//
//  EthereumProviderTests.swift
//  EthereumKitTests
//

import MultiChainCore
import XCTest

@testable import EthereumKit

final class EthereumProviderTests: XCTestCase {

  // MARK: - Test Data

  let testAddress = EthereumAddress("0x742d35Cc6634C0532925a3b844Bc9e7595f5bE91")!

  // MARK: - Initialization

  func testInitWithChain() {
    let provider = EthereumProvider(chain: .mainnet)

    XCTAssertEqual(provider.chain.chainId, 1)
    XCTAssertEqual(provider.chain.name, "Ethereum Mainnet")
  }

  func testInitWithURL() {
    let url = URL(string: "https://custom-rpc.example.com")!
    let provider = EthereumProvider(chainId: 1, name: "mainnet", url: url, isTestnet: false)

    XCTAssertEqual(provider.chain.chainId, 1)
  }

  func testInitSepolia() {
    let provider = EthereumProvider(chain: .sepolia)

    XCTAssertEqual(provider.chain.chainId, 11_155_111)
    XCTAssertTrue(provider.chain.isTestnet)
  }

  // MARK: - JSON-RPC Request Building

  func testBuildJsonRpcRequest() {
    let provider = EthereumProvider(chain: .mainnet)
    let request = ChainRequest(method: "eth_blockNumber", params: [])

    let jsonRpc = provider.buildJsonRpcRequest(request, id: 1)

    XCTAssertEqual(jsonRpc.method, "eth_blockNumber")
    XCTAssertEqual(jsonRpc.id, 1)
    XCTAssertEqual(jsonRpc.jsonrpc, "2.0")
  }

  func testBuildJsonRpcRequestWithParams() {
    let provider = EthereumProvider(chain: .mainnet)
    let request = ChainRequest(
      method: "eth_getBalance", params: [testAddress.checksummed, "latest"])

    let jsonRpc = provider.buildJsonRpcRequest(request, id: 42)

    XCTAssertEqual(jsonRpc.method, "eth_getBalance")
    XCTAssertEqual(jsonRpc.id, 42)
    XCTAssertEqual(jsonRpc.params.count, 2)
  }

  // MARK: - Response Parsing

  func testParseSuccessResponse() throws {
    let provider = EthereumProvider(chain: .mainnet)
    let json = """
      {"jsonrpc":"2.0","id":1,"result":"0x1234"}
      """
    let data = json.data(using: .utf8)!

    let result: String = try provider.parseResponse(data)

    XCTAssertEqual(result, "0x1234")
  }

  func testParseErrorResponse() {
    let provider = EthereumProvider(chain: .mainnet)
    let json = """
      {"jsonrpc":"2.0","id":1,"error":{"code":-32600,"message":"Invalid Request"}}
      """
    let data = json.data(using: .utf8)!

    XCTAssertThrowsError(try provider.parseResponse(data) as String) { error in
      guard case ProviderError.rpcError(let code, let message) = error else {
        XCTFail("Expected rpcError")
        return
      }
      XCTAssertEqual(code, -32600)
      XCTAssertEqual(message, "Invalid Request")
    }
  }

  func testParseInvalidJson() {
    let provider = EthereumProvider(chain: .mainnet)
    let data = "not json".data(using: .utf8)!

    XCTAssertThrowsError(try provider.parseResponse(data) as String) { error in
      XCTAssertTrue(error is ProviderError)
    }
  }

  // MARK: - Batch Request Building

  func testBuildBatchRequest() {
    let provider = EthereumProvider(chain: .mainnet)
    let requests = [
      ChainRequest(method: "eth_blockNumber", params: []),
      ChainRequest(method: "eth_chainId", params: []),
    ]

    let batch = provider.buildBatchRequest(requests)

    XCTAssertEqual(batch.count, 2)
    XCTAssertEqual(batch[0].id, 0)
    XCTAssertEqual(batch[1].id, 1)
  }

  // MARK: - Convenience Methods

  func testGetBlockNumberRequest() {
    let provider = EthereumProvider(chain: .mainnet)
    let request = provider.blockNumberRequest()

    XCTAssertEqual(request.method, "eth_blockNumber")
    XCTAssertEqual(request.params.count, 0)
  }

  func testGetChainIdRequest() {
    let provider = EthereumProvider(chain: .mainnet)
    let request = provider.chainIdRequest()

    XCTAssertEqual(request.method, "eth_chainId")
    XCTAssertEqual(request.params.count, 0)
  }

  func testGetGasPriceRequest() {
    let provider = EthereumProvider(chain: .mainnet)
    let request = provider.gasPriceRequest()

    XCTAssertEqual(request.method, "eth_gasPrice")
    XCTAssertEqual(request.params.count, 0)
  }

  func testSendRawTransactionRequest() {
    let provider = EthereumProvider(chain: .mainnet)
    let rawTx = "0x02f8..."
    let request = provider.sendRawTransactionRequest(rawTx)

    XCTAssertEqual(request.method, "eth_sendRawTransaction")
    XCTAssertEqual(request.params.count, 1)
  }

  func testGetTransactionReceiptRequest() {
    let provider = EthereumProvider(chain: .mainnet)
    let txHash = "0x" + String(repeating: "ab", count: 32)
    let request = provider.transactionReceiptRequest(hash: txHash)

    XCTAssertEqual(request.method, "eth_getTransactionReceipt")
    XCTAssertEqual(request.params.count, 1)
  }

  func testEstimateGasRequest() {
    let provider = EthereumProvider(chain: .mainnet)
    let tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: .zero,
      maxFeePerGas: .zero,
      gasLimit: 21000,
      to: testAddress,
      value: .zero,
      data: Data()
    )
    let request = provider.estimateGasRequest(transaction: tx)

    XCTAssertEqual(request.method, "eth_estimateGas")
  }

  func testCallRequest() {
    let provider = EthereumProvider(chain: .mainnet)
    let tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: .zero,
      maxFeePerGas: .zero,
      gasLimit: 100000,
      to: testAddress,
      value: .zero,
      data: Data([0xa9, 0x05, 0x9c, 0xbb])
    )
    let request = provider.callRequest(transaction: tx, block: .latest)

    XCTAssertEqual(request.method, "eth_call")
  }

  // MARK: - URLSession Configuration

  func testCustomURLSession() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 60
    let session = URLSession(configuration: config)

    let provider = EthereumProvider(chain: .mainnet, session: session)

    XCTAssertNotNil(provider)
  }
}

// MARK: - Mock Tests (No Network)

final class EthereumProviderMockTests: XCTestCase {

  override func tearDown() {
    MockURLProtocol.reset()
  }

  func testProviderProtocolConformance() {
    let provider = EthereumProvider(chain: .mainnet)

    // Provider protocol
    let _: Ethereum = provider.chain
  }

  func testSendBlockNumber() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    MockURLProtocol.setJsonResponse("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"0x1234\"}")

    let provider = EthereumProvider(chain: .mainnet, session: session)
    let result: String = try await provider.send(request: provider.blockNumberRequest())

    XCTAssertEqual(result, "0x1234")
  }
}

final class EthereumProviderAnvilTests: XCTestCase {
  lazy var provider = EthereumProvider(
    chainId: 31337,
    name: "Anvil",
    url: URL(string: "http://127.0.0.1:8545")!,
    isTestnet: true
  )

  override func setUpWithError() throws {
    try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil, "Skip on CI")
  }

  func testChainIdRequest() async throws {
    let result: String = try await provider.send(request: provider.chainIdRequest())
    XCTAssertEqual(result, "0x7a69")  // 31337
  }

  func testBlockNumberRequest() async throws {
    let result: String = try await provider.send(request: provider.blockNumberRequest())
    XCTAssertNotNil(result)
  }
}
