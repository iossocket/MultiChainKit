//
//  EthereumTransactionTests.swift
//  EthereumKitTests
//

import BigInt
import XCTest

@testable import EthereumKit

final class EthereumTransactionTests: XCTestCase {

  // MARK: - Test Data

  let testAddress = EthereumAddress("0x3535353535353535353535353535353535353535")!
  let zeroAddress = EthereumAddress.zero

  // MARK: - EIP-1559 Transaction Creation

  func testCreateEIP1559Transaction() {
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

    XCTAssertEqual(tx.chainId, 1)
    XCTAssertEqual(tx.nonce, 0)
    XCTAssertEqual(tx.gasLimit, 21000)
    XCTAssertEqual(tx.to, testAddress)
  }

  func testTransactionWithData() {
    let calldata = Data([0xa9, 0x05, 0x9c, 0xbb])  // transfer selector
    let tx = EthereumTransaction(
      chainId: 1,
      nonce: 5,
      maxPriorityFeePerGas: Wei.fromGwei(1),
      maxFeePerGas: Wei.fromGwei(50),
      gasLimit: 100000,
      to: testAddress,
      value: .zero,
      data: calldata
    )

    XCTAssertEqual(tx.data, calldata)
    XCTAssertEqual(tx.nonce, 5)
  }

  func testContractDeployment() {
    // Contract deployment has nil `to`
    let bytecode = Data(repeating: 0x60, count: 100)
    let tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 1000000,
      to: nil,
      value: .zero,
      data: bytecode
    )

    XCTAssertNil(tx.to)
    XCTAssertEqual(tx.data.count, 100)
  }

  // MARK: - Access List

  func testTransactionWithAccessList() {
    let accessList: [AccessListEntry] = [
      AccessListEntry(
        address: testAddress,
        storageKeys: [
          Data(repeating: 0x01, count: 32),
          Data(repeating: 0x02, count: 32),
        ]
      )
    ]

    let tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 21000,
      to: testAddress,
      value: .zero,
      data: Data(),
      accessList: accessList
    )

    XCTAssertEqual(tx.accessList.count, 1)
    XCTAssertEqual(tx.accessList[0].storageKeys.count, 2)
  }

  // MARK: - RLP Encoding (Unsigned)

  func testEncodeUnsignedTransaction() {
    let tx = EthereumTransaction(
      chainId: 1,
      nonce: 9,
      maxPriorityFeePerGas: Wei(2_000_000_000),
      maxFeePerGas: Wei(100_000_000_000),
      gasLimit: 21000,
      to: testAddress,
      value: Wei(1_000_000_000_000_000_000),
      data: Data()
    )

    let encoded = tx.encodeUnsigned()

    // EIP-1559 transactions start with 0x02
    XCTAssertEqual(encoded[0], 0x02)
    XCTAssertTrue(encoded.count > 1)
  }

  func testEncodeForSigning() {
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

    let hashForSigning = tx.hashForSigning()

    XCTAssertEqual(hashForSigning.count, 32)
  }

  // MARK: - Signed Transaction

  func testSignedTransactionEncode() {
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

    // Mock signature
    tx.signature = EthereumSignature(
      r: Data(repeating: 0xaa, count: 32),
      s: Data(repeating: 0xbb, count: 32),
      v: 1
    )

    let encoded = tx.encode()

    XCTAssertEqual(encoded[0], 0x02)
    XCTAssertTrue(encoded.count > tx.encodeUnsigned().count)
  }

  // MARK: - Transaction Hash

  func testTransactionHash() {
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

    tx.signature = EthereumSignature(
      r: Data(repeating: 0xaa, count: 32),
      s: Data(repeating: 0xbb, count: 32),
      v: 0
    )

    XCTAssertNotNil(tx.hash)
    XCTAssertEqual(tx.hash?.count, 32)
  }

  func testUnsignedTransactionHashIsNil() {
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

    XCTAssertNil(tx.hash)
  }

  // MARK: - Different Chain IDs

  func testMainnetChainId() {
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

    XCTAssertEqual(tx.chainId, 1)
  }

  func testSepoliaChainId() {
    let tx = EthereumTransaction(
      chainId: 11155111,
      nonce: 0,
      maxPriorityFeePerGas: .zero,
      maxFeePerGas: .zero,
      gasLimit: 21000,
      to: testAddress,
      value: .zero,
      data: Data()
    )

    XCTAssertEqual(tx.chainId, 11155111)
  }

  // MARK: - Edge Cases

  func testZeroValueTransaction() {
    let tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(100),
      gasLimit: 21000,
      to: testAddress,
      value: .zero,
      data: Data()
    )

    XCTAssertEqual(tx.value, .zero)
  }

  func testHighNonce() {
    let tx = EthereumTransaction(
      chainId: 1,
      nonce: UInt64.max,
      maxPriorityFeePerGas: .zero,
      maxFeePerGas: .zero,
      gasLimit: 21000,
      to: testAddress,
      value: .zero,
      data: Data()
    )

    XCTAssertEqual(tx.nonce, UInt64.max)
  }

  func testLargeData() {
    let largeData = Data(repeating: 0xff, count: 10000)
    let tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: .zero,
      maxFeePerGas: .zero,
      gasLimit: 1000000,
      to: testAddress,
      value: .zero,
      data: largeData
    )

    XCTAssertEqual(tx.data.count, 10000)
  }
}

// MARK: - AccessListEntry Tests

final class AccessListEntryTests: XCTestCase {

  func testAccessListEntryCreation() {
    let address = EthereumAddress("0x3535353535353535353535353535353535353535")!
    let keys = [
      Data(repeating: 0x01, count: 32),
      Data(repeating: 0x02, count: 32),
    ]

    let entry = AccessListEntry(address: address, storageKeys: keys)

    XCTAssertEqual(entry.address, address)
    XCTAssertEqual(entry.storageKeys.count, 2)
  }

  func testAccessListEntryEmptyKeys() {
    let address = EthereumAddress("0x3535353535353535353535353535353535353535")!
    let entry = AccessListEntry(address: address, storageKeys: [])

    XCTAssertEqual(entry.storageKeys.count, 0)
  }
}
