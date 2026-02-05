//
//  TransactionSigningTests.swift
//  EthereumKitTests
//

import XCTest

@testable import EthereumKit

final class TransactionSigningTests: XCTestCase {

  // MARK: - Test Data

  let testPrivateKey = Data(
    hex: "4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318")!
  let testAddress = EthereumAddress("0x3535353535353535353535353535353535353535")!

  // MARK: - Sign Transaction

  func testSignTransaction() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    var tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 21000,
      to: testAddress,
      value: Wei.fromEther(1),
      data: Data()
    )

    try tx.sign(with: signer)

    XCTAssertNotNil(tx.signature)
    XCTAssertEqual(tx.signature?.r.count, 32)
    XCTAssertEqual(tx.signature?.s.count, 32)
  }

  func testSignedTransactionHash() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    var tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 21000,
      to: testAddress,
      value: Wei.fromEther(1),
      data: Data()
    )

    try tx.sign(with: signer)

    XCTAssertNotNil(tx.hash)
    XCTAssertEqual(tx.hash?.count, 32)
  }

  func testSignTransactionDeterministic() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)

    var tx1 = EthereumTransaction(
      chainId: 1,
      nonce: 5,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 21000,
      to: testAddress,
      value: Wei.fromEther(1),
      data: Data()
    )

    var tx2 = EthereumTransaction(
      chainId: 1,
      nonce: 5,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 21000,
      to: testAddress,
      value: Wei.fromEther(1),
      data: Data()
    )

    try tx1.sign(with: signer)
    try tx2.sign(with: signer)

    XCTAssertEqual(tx1.signature?.r, tx2.signature?.r)
    XCTAssertEqual(tx1.signature?.s, tx2.signature?.s)
    XCTAssertEqual(tx1.hash, tx2.hash)
  }

  // MARK: - Signature Recovery

  func testRecoverSigner() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    var tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 21000,
      to: testAddress,
      value: Wei.fromEther(1),
      data: Data()
    )

    try tx.sign(with: signer)

    let recoveredAddress = try tx.recoverSender()
    XCTAssertEqual(recoveredAddress, signer.address)
  }

  func testRecoverSignerFromContractDeploy() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    var tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 1_000_000,
      to: nil,
      value: .zero,
      data: Data(repeating: 0x60, count: 100)
    )

    try tx.sign(with: signer)

    let recoveredAddress = try tx.recoverSender()
    XCTAssertEqual(recoveredAddress, signer.address)
  }

  // MARK: - Signed Transaction Encoding

  func testSignedTransactionRawData() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    var tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 21000,
      to: testAddress,
      value: Wei.fromEther(1),
      data: Data()
    )

    try tx.sign(with: signer)

    let rawTx = tx.rawTransaction
    XCTAssertNotNil(rawTx)
    XCTAssertEqual(rawTx?.prefix(2), "0x")
    XCTAssertTrue(rawTx!.count > 4)
  }

  func testUnsignedTransactionRawDataIsNil() {
    let tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 21000,
      to: testAddress,
      value: Wei.fromEther(1),
      data: Data()
    )

    XCTAssertNil(tx.rawTransaction)
  }

  // MARK: - Different Chain IDs

  func testSignTransactionMainnet() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    var tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: .zero,
      maxFeePerGas: .zero,
      gasLimit: 21000,
      to: testAddress,
      value: .zero,
      data: Data()
    )

    try tx.sign(with: signer)

    XCTAssertNotNil(tx.signature)
  }

  func testSignTransactionSepolia() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    var tx = EthereumTransaction(
      chainId: 11_155_111,
      nonce: 0,
      maxPriorityFeePerGas: .zero,
      maxFeePerGas: .zero,
      gasLimit: 21000,
      to: testAddress,
      value: .zero,
      data: Data()
    )

    try tx.sign(with: signer)

    XCTAssertNotNil(tx.signature)
  }

  // MARK: - Verify Signature

  func testVerifySignature() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    var tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 21000,
      to: testAddress,
      value: Wei.fromEther(1),
      data: Data()
    )

    try tx.sign(with: signer)

    let isValid = try tx.verifySignature()
    XCTAssertTrue(isValid)
  }

  func testVerifySignatureUnsignedReturnsFalse() {
    let tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 21000,
      to: testAddress,
      value: Wei.fromEther(1),
      data: Data()
    )

    XCTAssertFalse((try? tx.verifySignature()) ?? false)
  }

  // MARK: - Edge Cases

  func testSignTransactionWithAccessList() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    let accessList = [
      AccessListEntry(
        address: testAddress,
        storageKeys: [Data(repeating: 0x01, count: 32)]
      )
    ]

    var tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 50000,
      to: testAddress,
      value: .zero,
      data: Data(),
      accessList: accessList
    )

    try tx.sign(with: signer)

    XCTAssertNotNil(tx.signature)
    let recoveredAddress = try tx.recoverSender()
    XCTAssertEqual(recoveredAddress, signer.address)
  }

  func testSignTransactionWithLargeData() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    let largeData = Data(repeating: 0xab, count: 10000)

    var tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 1_000_000,
      to: testAddress,
      value: .zero,
      data: largeData
    )

    try tx.sign(with: signer)

    XCTAssertNotNil(tx.signature)
    let recoveredAddress = try tx.recoverSender()
    XCTAssertEqual(recoveredAddress, signer.address)
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
