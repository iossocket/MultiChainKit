//
//  WaitAndSendTests.swift
//  EthereumKitTests
//
//  Tests for waitForTransaction, prepareTransaction, sendTransaction, and Contract.write.
//

import Foundation
import MultiChainCore
import XCTest

@testable import EthereumKit

// MARK: - PollingConfig Tests

final class PollingConfigTests: XCTestCase {

  func testDefaultValues() {
    let config = PollingConfig.default
    XCTAssertEqual(config.intervalSeconds, 3.0)
    XCTAssertEqual(config.timeoutSeconds, 60.0)
  }

  func testCustomValues() {
    let config = PollingConfig(intervalSeconds: 1.0, timeoutSeconds: 30.0)
    XCTAssertEqual(config.intervalSeconds, 1.0)
    XCTAssertEqual(config.timeoutSeconds, 30.0)
  }
}

// MARK: - OptionalResult Tests

final class OptionalResultTests: XCTestCase {

  func testDecodeNullResult() throws {
    let json = """
      {"jsonrpc":"2.0","id":1,"result":null}
      """
    let data = json.data(using: .utf8)!
    let response = try JSONDecoder().decode(
      JsonRpcResponse<OptionalResult<EthereumReceipt>>.self, from: data)
    XCTAssertNil(response.result?.value)
  }

  func testDecodePresent() throws {
    let json = """
      {"jsonrpc":"2.0","id":1,"result":"0xabc"}
      """
    let data = json.data(using: .utf8)!
    let response = try JSONDecoder().decode(
      JsonRpcResponse<OptionalResult<String>>.self, from: data)
    XCTAssertEqual(response.result?.value, "0xabc")
  }
}

// MARK: - EthereumAccountError Tests

final class EthereumAccountErrorTests: XCTestCase {

  func testNoProviderError() {
    let error = EthereumAccountError.noProvider
    XCTAssertEqual(error, EthereumAccountError.noProvider)
  }
}

// MARK: - waitForTransaction Signature Tests

final class EthereumWaitForTransactionTests: XCTestCase {

  func testWaitForTransactionMethodExists() {
    let provider = EthereumProvider(chain: .mainnet)
    // Verify the method signature compiles — actual logic is fatalError stub
    _ = type(of: provider).waitForTransaction
  }

  func testWaitForTransactionRequestExists() {
    let provider = EthereumProvider(chain: .mainnet)
    let req = provider.transactionReceiptRequest(hash: "0x" + String(repeating: "ab", count: 32))
    XCTAssertEqual(req.method, "eth_getTransactionReceipt")
  }
}

// MARK: - EthereumSignableAccount Provider Tests

final class EthereumSignableAccountProviderTests: XCTestCase {

  let testPrivateKey = Data(
    hex: "4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318")!

  func testInitWithoutProvider() throws {
    let account = try EthereumSignableAccount(privateKey: testPrivateKey)
    XCTAssertNil(account.provider)
  }

  func testInitWithProvider() throws {
    let provider = EthereumProvider(chain: .mainnet)
    let account = try EthereumSignableAccount(privateKey: testPrivateKey, provider: provider)
    XCTAssertNotNil(account.provider)
  }

  func testInitFromSignerWithProvider() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    let provider = EthereumProvider(chain: .mainnet)
    let account = try EthereumSignableAccount(signer, provider: provider)
    XCTAssertNotNil(account.provider)
  }

  func testPrepareTransactionSignatureCompiles() {
    // Verify the method signature exists
    let account = try! EthereumSignableAccount(privateKey: testPrivateKey)
    _ = type(of: account).prepareTransaction
  }

  func testSendTransactionSignatureCompiles() {
    let account = try! EthereumSignableAccount(privateKey: testPrivateKey)
    _ = type(of: account).sendTransaction
  }
}

// MARK: - Contract.write Signature Tests

final class EthereumContractWriteTests: XCTestCase {

  func testWriteMethodSignatureCompiles() {
    let provider = EthereumProvider(chain: .mainnet)
    let contract = EthereumContract(
      address: EthereumAddress("0x" + String(repeating: "ab", count: 20))!,
      abi: [
        ABIItem(
          type: .function,
          name: "transfer",
          inputs: [
            ABIParameter(name: "to", type: "address"),
            ABIParameter(name: "amount", type: "uint256"),
          ],
          outputs: [ABIParameter(name: "", type: "bool")],
          stateMutability: .nonpayable
        )
      ],
      provider: provider
    )
    // Verify the method signature exists
    _ = type(of: contract).write
  }
}

// MARK: - Test Helpers

extension Data {
  fileprivate init?(hex: String) {
    var hexStr = hex
    if hexStr.hasPrefix("0x") { hexStr = String(hexStr.dropFirst(2)) }
    guard hexStr.count % 2 == 0 else { return nil }

    var data = Data()
    var index = hexStr.startIndex
    while index < hexStr.endIndex {
      let nextIndex = hexStr.index(index, offsetBy: 2)
      guard let byte = UInt8(hexStr[index..<nextIndex], radix: 16) else { return nil }
      data.append(byte)
      index = nextIndex
    }
    self = data
  }
}
