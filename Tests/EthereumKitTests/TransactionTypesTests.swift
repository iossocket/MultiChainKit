//
//  TransactionTypesTests.swift
//  EthereumKitTests
//
//  Tests for Legacy (Type 0), EIP-2930 (Type 1), and EIP-1559 (Type 2) transactions
//

import XCTest

@testable import EthereumKit

final class TransactionTypesTests: XCTestCase {

  let testPrivateKey = Data(hex: "4c0883a69102937d6231471b5dbb6204fe512961708279f2e3e8a5d4b8e3e3e8")

  // MARK: - Legacy Transaction (Type 0)

  func testLegacyTransactionCreation() {
    let tx = EthereumTransaction.legacy(
      chainId: 1,
      nonce: 0,
      gasPrice: Wei.fromGwei(20),
      gasLimit: 21000,
      to: EthereumAddress("0x3535353535353535353535353535353535353535"),
      value: Wei.fromEther(1)
    )

    XCTAssertEqual(tx.type, .legacy)
    XCTAssertEqual(tx.chainId, 1)
    XCTAssertEqual(tx.nonce, 0)
    XCTAssertEqual(tx.gasPrice, Wei.fromGwei(20))
    XCTAssertNil(tx.maxPriorityFeePerGas)
    XCTAssertNil(tx.maxFeePerGas)
    XCTAssertEqual(tx.gasLimit, 21000)
    XCTAssertTrue(tx.accessList.isEmpty)
  }

  func testLegacyTransactionEncoding() throws {
    let tx = EthereumTransaction.legacy(
      chainId: 1,
      nonce: 9,
      gasPrice: Wei.fromGwei(20),
      gasLimit: 21000,
      to: EthereumAddress("0x3535353535353535353535353535353535353535"),
      value: Wei.fromEther(1)
    )

    let unsigned = tx.encodeUnsigned()
    XCTAssertFalse(unsigned.isEmpty)

    // Legacy unsigned should NOT have type prefix
    XCTAssertNotEqual(unsigned[0], 0x00)

    // Should be RLP encoded list
    XCTAssertTrue(unsigned[0] >= 0xc0)
  }

  func testLegacyTransactionSigning() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)

    var tx = EthereumTransaction.legacy(
      chainId: 1,
      nonce: 9,
      gasPrice: Wei.fromGwei(20),
      gasLimit: 21000,
      to: EthereumAddress("0x3535353535353535353535353535353535353535"),
      value: Wei.fromEther(1)
    )

    tx = try tx.signed(with: signer)

    XCTAssertNotNil(tx.signature)
    XCTAssertNotNil(tx.hash)

    let encoded = tx.encode()
    // Legacy signed should NOT have type prefix
    XCTAssertTrue(encoded[0] >= 0xc0)
  }

  func testLegacyVValue() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)

    var tx = EthereumTransaction.legacy(
      chainId: 1,
      nonce: 0,
      gasPrice: Wei.fromGwei(20),
      gasLimit: 21000,
      to: EthereumAddress("0x3535353535353535353535353535353535353535"),
      value: Wei(0)
    )

    tx = try tx.signed(with: signer)

    // Legacy v = chainId * 2 + 35 + recoveryId
    // For chainId=1: v should be 37 or 38
    let sig = tx.signature!
    let recoveryId = sig.v % 27
    let expectedV = 1 * 2 + 35 + UInt8(recoveryId)
    XCTAssertTrue(expectedV == 37 || expectedV == 38)
  }

  // MARK: - EIP-2930 Transaction (Type 1)

  func testEIP2930TransactionCreation() {
    let accessList = [
      AccessListEntry(
        address: EthereumAddress("0x1234567890123456789012345678901234567890")!,
        storageKeys: [
          Data(hex: "0000000000000000000000000000000000000000000000000000000000000001")
        ]
      )
    ]

    let tx = EthereumTransaction.eip2930(
      chainId: 1,
      nonce: 0,
      gasPrice: Wei.fromGwei(20),
      gasLimit: 21000,
      to: EthereumAddress("0x3535353535353535353535353535353535353535"),
      value: Wei.fromEther(1),
      accessList: accessList
    )

    XCTAssertEqual(tx.type, .accessList)
    XCTAssertEqual(tx.chainId, 1)
    XCTAssertEqual(tx.gasPrice, Wei.fromGwei(20))
    XCTAssertNil(tx.maxPriorityFeePerGas)
    XCTAssertNil(tx.maxFeePerGas)
    XCTAssertEqual(tx.accessList.count, 1)
  }

  func testEIP2930TransactionEncoding() throws {
    let accessList = [
      AccessListEntry(
        address: EthereumAddress("0x1234567890123456789012345678901234567890")!,
        storageKeys: [
          Data(hex: "0000000000000000000000000000000000000000000000000000000000000001")
        ]
      )
    ]

    let tx = EthereumTransaction.eip2930(
      chainId: 1,
      nonce: 0,
      gasPrice: Wei.fromGwei(20),
      gasLimit: 21000,
      to: EthereumAddress("0x3535353535353535353535353535353535353535"),
      value: Wei(0),
      accessList: accessList
    )

    let unsigned = tx.encodeUnsigned()

    // EIP-2930 should have 0x01 prefix
    XCTAssertEqual(unsigned[0], 0x01)
  }

  func testEIP2930TransactionSigning() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)

    let accessList = [
      AccessListEntry(
        address: EthereumAddress("0x1234567890123456789012345678901234567890")!,
        storageKeys: []
      )
    ]

    var tx = EthereumTransaction.eip2930(
      chainId: 1,
      nonce: 0,
      gasPrice: Wei.fromGwei(20),
      gasLimit: 21000,
      to: EthereumAddress("0x3535353535353535353535353535353535353535"),
      value: Wei(0),
      accessList: accessList
    )

    tx = try tx.signed(with: signer)

    XCTAssertNotNil(tx.signature)
    XCTAssertNotNil(tx.hash)

    let encoded = tx.encode()
    // EIP-2930 signed should have 0x01 prefix
    XCTAssertEqual(encoded[0], 0x01)
  }

  // MARK: - EIP-1559 Transaction (Type 2)

  func testEIP1559TransactionCreation() {
    let tx = EthereumTransaction.eip1559(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 21000,
      to: EthereumAddress("0x3535353535353535353535353535353535353535"),
      value: Wei.fromEther(1)
    )

    XCTAssertEqual(tx.type, .eip1559)
    XCTAssertEqual(tx.chainId, 1)
    XCTAssertNil(tx.gasPrice)
    XCTAssertEqual(tx.maxPriorityFeePerGas, Wei.fromGwei(2))
    XCTAssertEqual(tx.maxFeePerGas, Wei.fromGwei(100))
  }

  func testEIP1559TransactionEncoding() throws {
    let tx = EthereumTransaction.eip1559(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 21000,
      to: EthereumAddress("0x3535353535353535353535353535353535353535"),
      value: Wei(0)
    )

    let unsigned = tx.encodeUnsigned()

    // EIP-1559 should have 0x02 prefix
    XCTAssertEqual(unsigned[0], 0x02)
  }

  func testEIP1559TransactionSigning() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)

    var tx = EthereumTransaction.eip1559(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 21000,
      to: EthereumAddress("0x3535353535353535353535353535353535353535"),
      value: Wei(0)
    )

    tx = try tx.signed(with: signer)

    XCTAssertNotNil(tx.signature)
    XCTAssertNotNil(tx.hash)

    let encoded = tx.encode()
    // EIP-1559 signed should have 0x02 prefix
    XCTAssertEqual(encoded[0], 0x02)
  }

  func testEIP1559WithAccessList() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)

    let accessList = [
      AccessListEntry(
        address: EthereumAddress("0x1234567890123456789012345678901234567890")!,
        storageKeys: [
          Data(hex: "0000000000000000000000000000000000000000000000000000000000000000"),
          Data(hex: "0000000000000000000000000000000000000000000000000000000000000001"),
        ]
      )
    ]

    var tx = EthereumTransaction.eip1559(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 50000,
      to: EthereumAddress("0x3535353535353535353535353535353535353535"),
      value: Wei(0),
      accessList: accessList
    )

    tx = try tx.signed(with: signer)

    XCTAssertNotNil(tx.signature)
    XCTAssertEqual(tx.accessList.count, 1)
    XCTAssertEqual(tx.accessList[0].storageKeys.count, 2)
  }

  // MARK: - Contract Creation

  func testLegacyContractCreation() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)

    // Contract creation has nil `to`
    var tx = EthereumTransaction.legacy(
      chainId: 1,
      nonce: 0,
      gasPrice: Wei.fromGwei(20),
      gasLimit: 100000,
      to: nil,
      value: Wei(0),
      data: Data(hex: "6080604052")  // Simple contract bytecode
    )

    tx = try tx.signed(with: signer)

    XCTAssertNil(tx.to)
    XCTAssertNotNil(tx.signature)
    XCTAssertNotNil(tx.hash)
  }

  func testEIP1559ContractCreation() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)

    var tx = EthereumTransaction.eip1559(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 100000,
      to: nil,
      value: Wei(0),
      data: Data(hex: "6080604052")
    )

    tx = try tx.signed(with: signer)

    XCTAssertNil(tx.to)
    XCTAssertNotNil(tx.signature)
  }

  // MARK: - Hash Consistency

  func testTransactionHashConsistency() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)

    var tx = EthereumTransaction.eip1559(
      chainId: 1,
      nonce: 42,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 21000,
      to: EthereumAddress("0x3535353535353535353535353535353535353535"),
      value: Wei.fromGwei(1000)
    )

    tx = try tx.signed(with: signer)

    let hash1 = tx.hash
    let hash2 = tx.hash

    XCTAssertEqual(hash1, hash2)
    XCTAssertEqual(hash1?.count, 32)
  }

  // MARK: - Different Chain IDs

  func testLegacyDifferentChainIds() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)

    // Mainnet (chainId = 1)
    var txMainnet = EthereumTransaction.legacy(
      chainId: 1,
      nonce: 0,
      gasPrice: Wei.fromGwei(20),
      gasLimit: 21000,
      to: EthereumAddress("0x3535353535353535353535353535353535353535"),
      value: Wei(0)
    )
    txMainnet = try txMainnet.signed(with: signer)

    // Sepolia (chainId = 11155111)
    var txSepolia = EthereumTransaction.legacy(
      chainId: 11155111,
      nonce: 0,
      gasPrice: Wei.fromGwei(20),
      gasLimit: 21000,
      to: EthereumAddress("0x3535353535353535353535353535353535353535"),
      value: Wei(0)
    )
    txSepolia = try txSepolia.signed(with: signer)

    // Different chain IDs should produce different hashes
    XCTAssertNotEqual(txMainnet.hash, txSepolia.hash)
  }
}
