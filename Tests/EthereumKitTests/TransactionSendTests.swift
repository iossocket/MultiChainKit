//
//  TransactionSendTests.swift
//  EthereumKitTests
//

import MultiChainCore
import XCTest

@testable import EthereumKit

final class TransactionSendTests: XCTestCase {

  let provider = EthereumProvider(chain: .mainnet)

  // MARK: - Request Building

  func testSendRawTransactionRequest() {
    let rawTx = "0x02f8730181..."
    let request = provider.sendRawTransactionRequest(rawTx)

    XCTAssertEqual(request.method, "eth_sendRawTransaction")
    XCTAssertEqual(request.params.count, 1)
  }

  func testTransactionReceiptRequest() {
    let txHash = "0x" + String(repeating: "ab", count: 32)
    let request = provider.transactionReceiptRequest(hash: txHash)

    XCTAssertEqual(request.method, "eth_getTransactionReceipt")
    XCTAssertEqual(request.params.count, 1)
  }

  func testGetTransactionByHashRequest() {
    let txHash = "0x" + String(repeating: "cd", count: 32)
    let request = provider.getTransactionByHashRequest(hash: txHash)

    XCTAssertEqual(request.method, "eth_getTransactionByHash")
    XCTAssertEqual(request.params.count, 1)
  }
}

// MARK: - Receipt Parsing Tests

final class EthereumReceiptTests: XCTestCase {

  func testDecodeSuccessReceipt() throws {
    let json = """
      {
        "transactionHash": "0xabcd",
        "transactionIndex": "0x1",
        "blockHash": "0x1234",
        "blockNumber": "0x100",
        "from": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "to": "0x742d35Cc6634C0532925a3b844Bc9e7595f5bE91",
        "cumulativeGasUsed": "0x5208",
        "effectiveGasPrice": "0x3b9aca00",
        "gasUsed": "0x5208",
        "contractAddress": null,
        "logs": [],
        "logsBloom": "0x00",
        "type": "0x2",
        "status": "0x1"
      }
      """
    let data = json.data(using: .utf8)!
    let receipt = try JSONDecoder().decode(EthereumReceipt.self, from: data)

    XCTAssertEqual(receipt.transactionHashHex, "0xabcd")
    XCTAssertTrue(receipt.isSuccess)
    XCTAssertEqual(receipt.blockNumber, 256)
    XCTAssertEqual(receipt.gasUsedValue, 21000)
  }

  func testDecodeFailedReceipt() throws {
    let json = """
      {
        "transactionHash": "0xfailed",
        "transactionIndex": "0x0",
        "blockHash": "0x5678",
        "blockNumber": "0x200",
        "from": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "to": "0x742d35Cc6634C0532925a3b844Bc9e7595f5bE91",
        "cumulativeGasUsed": "0x10000",
        "effectiveGasPrice": "0x3b9aca00",
        "gasUsed": "0x10000",
        "contractAddress": null,
        "logs": [],
        "logsBloom": "0x00",
        "type": "0x2",
        "status": "0x0"
      }
      """
    let data = json.data(using: .utf8)!
    let receipt = try JSONDecoder().decode(EthereumReceipt.self, from: data)

    XCTAssertFalse(receipt.isSuccess)
  }

  func testDecodeReceiptWithContractCreation() throws {
    let json = """
      {
        "transactionHash": "0xdeploy",
        "transactionIndex": "0x0",
        "blockHash": "0x9999",
        "blockNumber": "0x300",
        "from": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "to": null,
        "cumulativeGasUsed": "0x50000",
        "effectiveGasPrice": "0x3b9aca00",
        "gasUsed": "0x50000",
        "contractAddress": "0x1234567890123456789012345678901234567890",
        "logs": [],
        "logsBloom": "0x00",
        "type": "0x2",
        "status": "0x1"
      }
      """
    let data = json.data(using: .utf8)!
    let receipt = try JSONDecoder().decode(EthereumReceipt.self, from: data)

    XCTAssertNil(receipt.to)
    XCTAssertEqual(receipt.contractAddress, "0x1234567890123456789012345678901234567890")
    XCTAssertTrue(receipt.isSuccess)
  }

  func testDecodeReceiptWithLogs() throws {
    let json = """
      {
        "transactionHash": "0xwithlogs",
        "transactionIndex": "0x0",
        "blockHash": "0xaaaa",
        "blockNumber": "0x400",
        "from": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "to": "0x742d35Cc6634C0532925a3b844Bc9e7595f5bE91",
        "cumulativeGasUsed": "0x8000",
        "effectiveGasPrice": "0x3b9aca00",
        "gasUsed": "0x8000",
        "contractAddress": null,
        "logs": [
          {
            "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f5bE91",
            "topics": ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"],
            "data": "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
            "blockNumber": "0x400",
            "transactionHash": "0xwithlogs",
            "transactionIndex": "0x0",
            "blockHash": "0xaaaa",
            "logIndex": "0x0",
            "removed": false
          }
        ],
        "logsBloom": "0x00",
        "type": "0x2",
        "status": "0x1"
      }
      """
    let data = json.data(using: .utf8)!
    let receipt = try JSONDecoder().decode(EthereumReceipt.self, from: data)

    XCTAssertEqual(receipt.logs.count, 1)
    XCTAssertEqual(receipt.logs[0].topics.count, 1)
    XCTAssertFalse(receipt.logs[0].removed)
  }
}

// MARK: - TransactionResponse Tests

final class EthereumTransactionResponseTests: XCTestCase {

  func testDecodePendingTransaction() throws {
    let json = """
      {
        "hash": "0xpending",
        "nonce": "0x5",
        "blockHash": null,
        "blockNumber": null,
        "transactionIndex": null,
        "from": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "to": "0x742d35Cc6634C0532925a3b844Bc9e7595f5bE91",
        "value": "0xde0b6b3a7640000",
        "gas": "0x5208",
        "input": "0x",
        "type": "0x2",
        "maxFeePerGas": "0x3b9aca00",
        "maxPriorityFeePerGas": "0x3b9aca00"
      }
      """
    let data = json.data(using: .utf8)!
    let tx = try JSONDecoder().decode(EthereumTransactionResponse.self, from: data)

    XCTAssertTrue(tx.isPending)
    XCTAssertNil(tx.blockHash)
    XCTAssertEqual(tx.maxFeePerGas, "0x3b9aca00")
  }

  func testDecodeConfirmedTransaction() throws {
    let json = """
      {
        "hash": "0xconfirmed",
        "nonce": "0x10",
        "blockHash": "0xblockhash",
        "blockNumber": "0x500",
        "transactionIndex": "0x0",
        "from": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "to": "0x742d35Cc6634C0532925a3b844Bc9e7595f5bE91",
        "value": "0x0",
        "gas": "0x10000",
        "input": "0xa9059cbb",
        "type": "0x2",
        "maxFeePerGas": "0x3b9aca00",
        "maxPriorityFeePerGas": "0x3b9aca00"
      }
      """
    let data = json.data(using: .utf8)!
    let tx = try JSONDecoder().decode(EthereumTransactionResponse.self, from: data)

    XCTAssertFalse(tx.isPending)
    XCTAssertEqual(tx.blockNumber, "0x500")
  }

  func testDecodeLegacyTransaction() throws {
    let json = """
      {
        "hash": "0xlegacy",
        "nonce": "0x1",
        "blockHash": "0xblockhash",
        "blockNumber": "0x100",
        "transactionIndex": "0x0",
        "from": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "to": "0x742d35Cc6634C0532925a3b844Bc9e7595f5bE91",
        "value": "0x1",
        "gasPrice": "0x3b9aca00",
        "gas": "0x5208",
        "input": "0x",
        "type": "0x0"
      }
      """
    let data = json.data(using: .utf8)!
    let tx = try JSONDecoder().decode(EthereumTransactionResponse.self, from: data)

    XCTAssertEqual(tx.gasPrice, "0x3b9aca00")
    XCTAssertNil(tx.maxFeePerGas)
  }
}

// MARK: - Mock Network Tests

final class TransactionSendMockTests: XCTestCase {

  override func tearDown() {
    MockURLProtocol.reset()
  }

  func testSendRawTransaction() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    let txHash = "0x" + String(repeating: "ab", count: 32)
    MockURLProtocol.setJsonResponse("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":\"\(txHash)\"}")

    let provider = EthereumProvider(chain: .mainnet, session: session)
    let result: String = try await provider.send(
      request: provider.sendRawTransactionRequest("0x02f8..."))

    XCTAssertEqual(result, txHash)
  }

  func testGetTransactionReceipt() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    let json = """
      {"jsonrpc":"2.0","id":1,"result":{"transactionHash":"0xabc","transactionIndex":"0x0","blockHash":"0x123","blockNumber":"0x100","from":"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","to":"0x742d35Cc6634C0532925a3b844Bc9e7595f5bE91","cumulativeGasUsed":"0x5208","effectiveGasPrice":"0x3b9aca00","gasUsed":"0x5208","contractAddress":null,"logs":[],"logsBloom":"0x00","type":"0x2","status":"0x1"}}
      """
    MockURLProtocol.setJsonResponse(json)

    let provider = EthereumProvider(chain: .mainnet, session: session)
    let txHash = "0x" + String(repeating: "ab", count: 32)
    let receipt: EthereumReceipt = try await provider.send(
      request: provider.transactionReceiptRequest(hash: txHash))

    XCTAssertTrue(receipt.isSuccess)
    XCTAssertEqual(receipt.blockNumber, 256)
  }

  func testGetTransactionReceiptNotFound() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    // Pending transaction returns null
    MockURLProtocol.setJsonResponse("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}")

    let provider = EthereumProvider(chain: .mainnet, session: session)
    let txHash = "0x" + String(repeating: "ab", count: 32)

    do {
      let _: EthereumReceipt = try await provider.send(
        request: provider.transactionReceiptRequest(hash: txHash))
      XCTFail("Should throw error for null result")
    } catch {
      // Expected: ProviderError.invalidResponse
      XCTAssertTrue(error is ProviderError)
    }
  }

  func testGetTransactionByHash() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    let json = """
      {"jsonrpc":"2.0","id":1,"result":{"hash":"0xtx","nonce":"0x5","blockHash":"0xblock","blockNumber":"0x100","transactionIndex":"0x0","from":"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","to":"0x742d35Cc6634C0532925a3b844Bc9e7595f5bE91","value":"0x0","gas":"0x5208","input":"0x","type":"0x2","maxFeePerGas":"0x3b9aca00","maxPriorityFeePerGas":"0x3b9aca00"}}
      """
    MockURLProtocol.setJsonResponse(json)

    let provider = EthereumProvider(chain: .mainnet, session: session)
    let tx: EthereumTransactionResponse = try await provider.send(
      request: provider.getTransactionByHashRequest(hash: "0xtx"))

    XCTAssertFalse(tx.isPending)
    XCTAssertEqual(tx.nonce, "0x5")
  }
}

// MARK: - Anvil Integration Tests

final class TransactionSendAnvilTests: XCTestCase {

  lazy var provider = EthereumProvider(
    chainId: 31337,
    name: "Anvil",
    url: URL(string: "http://127.0.0.1:8545")!,
    isTestnet: true
  )

  // Anvil default accounts
  let fromAddress = EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!
  let toAddress = EthereumAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")!
  // Anvil default private key for account 0
  let privateKey = Data(hex: "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")

  override func setUpWithError() throws {
    try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil, "Skip on CI")
  }

  func testSendTransaction() async throws {
    // 1. Get nonce
    let nonceHex: String = try await provider.send(
      request: provider.getTransactionCountRequest(address: fromAddress, block: .pending)
    )
    let nonce = UInt64(nonceHex.dropFirst(2), radix: 16) ?? 0
    print("nonce: \(nonce)")

    // 2. Get gas price
    let gasPriceHex: String = try await provider.send(request: provider.gasPriceRequest())
    let gasPrice = Wei(gasPriceHex) ?? .zero
    print("gasPrice: \(gasPrice)")

    // 3. Build transaction
    var tx = EthereumTransaction(
      chainId: 31337,
      nonce: nonce,
      maxPriorityFeePerGas: gasPrice,
      maxFeePerGas: gasPrice * 2,
      gasLimit: 21000,
      to: toAddress,
      value: Wei.fromEther(1),
      data: Data()
    )

    // 4. Sign
    let signer = try EthereumSigner(privateKey: privateKey)
    try tx.sign(with: signer)

    // 5. Send
    guard let rawTx = tx.rawTransaction else {
      XCTFail("Failed to encode transaction")
      return
    }

    let txHash: String = try await provider.send(request: provider.sendRawTransactionRequest(rawTx))
    print("txHash: \(txHash)")
    XCTAssertTrue(txHash.hasPrefix("0x"))
    XCTAssertEqual(txHash.count, 66)  // 0x + 64 hex chars

    // 6. Get receipt (may need to wait)
    try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

    let receipt: EthereumReceipt = try await provider.send(
      request: provider.transactionReceiptRequest(hash: txHash)
    )
    print("receipt: \(receipt)")
    XCTAssertTrue(receipt.isSuccess)
    XCTAssertEqual(receipt.gasUsedValue, 21000)
  }
}
