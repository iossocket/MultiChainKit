//
//  EthereumAddressTests.swift
//  EthereumKitTests
//

import MultiChainCore
import XCTest

@testable import EthereumKit

final class EthereumAddressTests: XCTestCase {

  // MARK: - Initialization from String

  func testInitFromChecksummedAddress() {
    let address = EthereumAddress("0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B")
    XCTAssertNotNil(address)
  }

  func testInitFromLowercaseAddress() {
    let address = EthereumAddress("0xab5801a7d398351b8be11c439e05c5b3259aec9b")
    XCTAssertNotNil(address)
  }

  func testInitFromUppercaseAddress() {
    let address = EthereumAddress("0xAB5801A7D398351B8BE11C439E05C5B3259AEC9B")
    XCTAssertNotNil(address)
  }

  func testInitFromAddressWithoutPrefix() {
    let address = EthereumAddress("Ab5801a7D398351b8bE11C439e05C5B3259aeC9B")
    XCTAssertNotNil(address)
  }

  func testInitFromInvalidLength() {
    let address = EthereumAddress("0xAb5801a7D398351b8bE11C439e05C5B3259ae")  // too short
    XCTAssertNil(address)
  }

  func testInitFromInvalidCharacters() {
    let address = EthereumAddress("0xGb5801a7D398351b8bE11C439e05C5B3259aeC9B")  // G is invalid
    XCTAssertNil(address)
  }

  func testInitFromEmptyString() {
    let address = EthereumAddress("")
    XCTAssertNil(address)
  }

  // MARK: - Initialization from Data

  func testInitFromData() {
    let data = Data(hex: "ab5801a7d398351b8be11c439e05c5b3259aec9b")!
    let address = EthereumAddress(data)
    XCTAssertEqual(address.data, data)
  }

  func testInitFromDataWrongLength() {
    let data = Data(hex: "ab5801a7d398351b8be11c439e05c5b3259aec")!  // 19 bytes
    let address = EthereumAddress(data)
    // Should still create, but data will be truncated/padded
    XCTAssertEqual(address.data.count, 20)
  }

  // MARK: - Zero Address

  func testZeroAddress() {
    let zero = EthereumAddress.zero
    XCTAssertEqual(zero.checksummed, "0x0000000000000000000000000000000000000000")
  }

  // MARK: - EIP-55 Checksum

  func testChecksummedOutput() {
    // Test vector from EIP-55
    let address = EthereumAddress("0xfb6916095ca1df60bb79ce92ce3ea74c37c5d359")!
    XCTAssertEqual(address.checksummed, "0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359")
  }

  func testChecksummedOutputAllCaps() {
    // All caps in checksum (when hash nibble >= 8)
    let address = EthereumAddress("0x52908400098527886E0F7030069857D2E4169EE7")!
    XCTAssertEqual(address.checksummed, "0x52908400098527886E0F7030069857D2E4169EE7")
  }

  func testChecksummedOutputAllLower() {
    // All lower in checksum (when hash nibble < 8)
    let address = EthereumAddress("0xde709f2102306220921060314715629080e2fb77")!
    XCTAssertEqual(address.checksummed, "0xde709f2102306220921060314715629080e2fb77")
  }

  func testChecksummedVitalikAddress() {
    // Vitalik's address
    let address = EthereumAddress("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")!
    XCTAssertEqual(address.checksummed, "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
  }

  // MARK: - Equality

  func testEqualityWithSameAddress() {
    let a = EthereumAddress("0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B")!
    let b = EthereumAddress("0xab5801a7d398351b8be11c439e05c5b3259aec9b")!
    XCTAssertEqual(a, b)
  }

  func testInequalityWithDifferentAddress() {
    let a = EthereumAddress("0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B")!
    let b = EthereumAddress("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")!
    XCTAssertNotEqual(a, b)
  }

  // MARK: - Hashable

  func testHashable() {
    let a = EthereumAddress("0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B")!
    let b = EthereumAddress("0xab5801a7d398351b8be11c439e05c5b3259aec9b")!
    let c = EthereumAddress("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")!

    var set = Set<EthereumAddress>()
    set.insert(a)
    set.insert(b)
    set.insert(c)

    XCTAssertEqual(set.count, 2)
  }

  // MARK: - CustomStringConvertible

  func testDescription() {
    let address = EthereumAddress("0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B")!
    XCTAssertEqual(address.description, "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B")
  }

  // MARK: - Codable

  func testEncode() throws {
    let address = EthereumAddress("0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B")!
    let encoder = JSONEncoder()
    let data = try encoder.encode(address)
    let json = String(data: data, encoding: .utf8)
    XCTAssertEqual(json, "\"0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B\"")
  }

  func testDecode() throws {
    let json = "\"0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B\""
    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    let address = try decoder.decode(EthereumAddress.self, from: data)
    XCTAssertEqual(address.checksummed, "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B")
  }

  func testDecodeInvalid() {
    let json = "\"0xinvalid\""
    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    XCTAssertThrowsError(try decoder.decode(EthereumAddress.self, from: data))
  }

  // MARK: - ChainAddress Protocol

  func testConformsToChainAddress() {
    let address: any ChainAddress = EthereumAddress("0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B")!
    XCTAssertEqual(address.data.count, 20)
  }
}

// MARK: - Test Helper

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
