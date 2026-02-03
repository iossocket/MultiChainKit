//
//  EthereumAccountTests.swift
//  EthereumKitTests
//

import MultiChainCore
import XCTest

@testable import EthereumKit

final class EthereumAccountTests: XCTestCase {

  // MARK: - Test Data

  let testPrivateKey = Data(hex: "4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318")!
  let testAddress = EthereumAddress("0x2c7536E3605D9C16a7a3D7b1898e529396a65c23")!

  let testMnemonic =
    "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

  // MARK: - Init from Address

  func testInitFromAddress() {
    let account = EthereumAccount(address: testAddress)
    XCTAssertEqual(account.address, testAddress)
  }

  func testInitFromAddressString() {
    let account = EthereumAccount(address: "0x2c7536E3605D9C16a7a3D7b1898e529396a65c23")
    XCTAssertNotNil(account)
    XCTAssertEqual(account?.address, testAddress)
  }

  func testInitFromInvalidAddressString() {
    let account = EthereumAccount(address: "invalid")
    XCTAssertNil(account)
  }

  // MARK: - Init from Signer

  func testInitFromSigner() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    let account = EthereumAccount(signer: signer)

    XCTAssertEqual(account!.address.checksummed.lowercased(), testAddress.checksummed.lowercased())
  }

  func testInitFromMnemonic() throws {
    let account = try EthereumAccount(mnemonic: testMnemonic, path: .ethereum)

    XCTAssertEqual(
      account.address.checksummed.lowercased(), "0x9858effd232b4033e47d90003d41ec34ecaeda94")
  }

  func testInitFromPrivateKey() throws {
    let account = try EthereumAccount(privateKey: testPrivateKey)

    XCTAssertEqual(account.address.checksummed.lowercased(), testAddress.checksummed.lowercased())
  }

  // MARK: - Balance Request

  func testBalanceRequest() {
    let account = EthereumAccount(address: testAddress)
    let request = account.balanceRequest()

    XCTAssertEqual(request.method, "eth_getBalance")
    XCTAssertEqual(request.params.count, 2)
  }

  func testBalanceRequestAtBlock() {
    let account = EthereumAccount(address: testAddress)
    let request = account.balanceRequest(at: .number(12345))

    XCTAssertEqual(request.method, "eth_getBalance")
  }

  // MARK: - Nonce Request

  func testNonceRequest() {
    let account = EthereumAccount(address: testAddress)
    let request = account.nonceRequest()

    XCTAssertEqual(request.method, "eth_getTransactionCount")
    XCTAssertEqual(request.params.count, 2)
  }

  func testNonceRequestPending() {
    let account = EthereumAccount(address: testAddress)
    let request = account.nonceRequest(at: .pending)

    XCTAssertEqual(request.method, "eth_getTransactionCount")
  }

  // MARK: - Code Request

  func testCodeRequest() {
    let account = EthereumAccount(address: testAddress)
    let request = account.codeRequest()

    XCTAssertEqual(request.method, "eth_getCode")
    XCTAssertEqual(request.params.count, 2)
  }

  // MARK: - Account Protocol Conformance

  func testAccountProtocolConformance() {
    let account = EthereumAccount(address: testAddress)

    let _: EthereumAddress = account.address
    let _: ChainRequest = account.balanceRequest()
    let _: ChainRequest = account.nonceRequest()
  }

  // MARK: - Equality

  func testEquality() {
    let account1 = EthereumAccount(address: testAddress)
    let account2 = EthereumAccount(address: testAddress)

    XCTAssertEqual(account1, account2)
  }

  func testInequalityDifferentAddress() {
    let account1 = EthereumAccount(address: testAddress)
    let account2 = EthereumAccount(address: EthereumAddress.zero)

    XCTAssertNotEqual(account1, account2)
  }

  // MARK: - Hashable

  func testHashable() {
    let account1 = EthereumAccount(address: testAddress)
    let account2 = EthereumAccount(address: testAddress)
    let account3 = EthereumAccount(address: EthereumAddress.zero)

    var set = Set<EthereumAccount>()
    set.insert(account1)
    set.insert(account2)
    set.insert(account3)

    XCTAssertEqual(set.count, 2)
  }
}

// MARK: - BlockTag Tests

final class BlockTagTests: XCTestCase {

  func testLatest() {
    XCTAssertEqual(BlockTag.latest.rawValue, "latest")
  }

  func testPending() {
    XCTAssertEqual(BlockTag.pending.rawValue, "pending")
  }

  func testEarliest() {
    XCTAssertEqual(BlockTag.earliest.rawValue, "earliest")
  }

  func testBlockNumber() {
    let tag = BlockTag.number(12345)
    XCTAssertEqual(tag.rawValue, "0x3039")
  }

  func testBlockNumberZero() {
    let tag = BlockTag.number(0)
    XCTAssertEqual(tag.rawValue, "0x0")
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
