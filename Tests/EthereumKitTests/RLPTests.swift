//
//  RLPTests.swift
//  EthereumKitTests
//

import XCTest

@testable import EthereumKit

final class RLPTests: XCTestCase {

  // MARK: - Encode Single Byte

  func testEncodeSingleByteLow() {
    // Single byte in [0x00, 0x7f] is its own RLP encoding
    let encoded = RLP.encode(Data([0x00]))
    XCTAssertEqual(encoded, Data([0x00]))
  }

  func testEncodeSingleByte0x7f() {
    let encoded = RLP.encode(Data([0x7f]))
    XCTAssertEqual(encoded, Data([0x7f]))
  }

  func testEncodeSingleByte0x80() {
    // 0x80 needs prefix
    let encoded = RLP.encode(Data([0x80]))
    XCTAssertEqual(encoded, Data([0x81, 0x80]))
  }

  // MARK: - Encode Empty

  func testEncodeEmptyData() {
    let encoded = RLP.encode(Data())
    XCTAssertEqual(encoded, Data([0x80]))
  }

  func testEncodeEmptyString() {
    let encoded = RLP.encode("")
    XCTAssertEqual(encoded, Data([0x80]))
  }

  // MARK: - Encode Short String (0-55 bytes)

  func testEncodeShortString() {
    // "dog" = [0x64, 0x6f, 0x67]
    let encoded = RLP.encode("dog")
    XCTAssertEqual(encoded, Data([0x83, 0x64, 0x6f, 0x67]))
  }

  func testEncodeShortData() {
    let data = Data([0x01, 0x02, 0x03])
    let encoded = RLP.encode(data)
    XCTAssertEqual(encoded, Data([0x83, 0x01, 0x02, 0x03]))
  }

  func testEncode55ByteString() {
    let data = Data(repeating: 0x01, count: 55)
    let encoded = RLP.encode(data)
    XCTAssertEqual(encoded.count, 56)
    XCTAssertEqual(encoded[0], 0xb7)  // 0x80 + 55
  }

  // MARK: - Encode Long String (>55 bytes)

  func testEncode56ByteString() {
    let data = Data(repeating: 0x01, count: 56)
    let encoded = RLP.encode(data)
    XCTAssertEqual(encoded.count, 58)  // 1 prefix + 1 length byte + 56 data
    XCTAssertEqual(encoded[0], 0xb8)  // 0xb7 + 1
    XCTAssertEqual(encoded[1], 56)
  }

  func testEncode256ByteString() {
    let data = Data(repeating: 0xaa, count: 256)
    let encoded = RLP.encode(data)
    XCTAssertEqual(encoded.count, 259)  // 1 prefix + 2 length bytes + 256 data
    XCTAssertEqual(encoded[0], 0xb9)  // 0xb7 + 2
    XCTAssertEqual(encoded[1], 0x01)
    XCTAssertEqual(encoded[2], 0x00)
  }

  // MARK: - Encode Integer

  func testEncodeZero() {
    let encoded = RLP.encode(0 as UInt64)
    XCTAssertEqual(encoded, Data([0x80]))
  }

  func testEncodeSmallInt() {
    let encoded = RLP.encode(127 as UInt64)
    XCTAssertEqual(encoded, Data([0x7f]))
  }

  func testEncodeInt128() {
    let encoded = RLP.encode(128 as UInt64)
    XCTAssertEqual(encoded, Data([0x81, 0x80]))
  }

  func testEncodeInt256() {
    let encoded = RLP.encode(256 as UInt64)
    XCTAssertEqual(encoded, Data([0x82, 0x01, 0x00]))
  }

  func testEncodeLargeInt() {
    let encoded = RLP.encode(0x0400 as UInt64)
    XCTAssertEqual(encoded, Data([0x82, 0x04, 0x00]))
  }

  func testEncodeMaxUInt64() {
    let encoded = RLP.encode(UInt64.max)
    XCTAssertEqual(encoded.count, 9)  // 1 prefix + 8 bytes
    XCTAssertEqual(encoded[0], 0x88)
  }

  // MARK: - Encode BigInt

  func testEncodeBigIntZero() {
    let encoded = RLP.encode(bigInt: Data())
    XCTAssertEqual(encoded, Data([0x80]))
  }

  func testEncodeBigIntWithLeadingZeros() {
    // Leading zeros should be stripped
    let data = Data([0x00, 0x00, 0x01, 0x02])
    let encoded = RLP.encode(bigInt: data)
    XCTAssertEqual(encoded, Data([0x82, 0x01, 0x02]))
  }

  // MARK: - Encode List

  func testEncodeEmptyList() {
    let encoded = RLP.encode(list: [])
    XCTAssertEqual(encoded, Data([0xc0]))
  }

  func testEncodeShortList() {
    // ["cat", "dog"]
    let encoded = RLP.encode(list: [
      RLP.encode("cat"),
      RLP.encode("dog"),
    ])
    // 0xc8 = 0xc0 + 8, then "cat" (4 bytes) + "dog" (4 bytes)
    XCTAssertEqual(encoded, Data([0xc8, 0x83, 0x63, 0x61, 0x74, 0x83, 0x64, 0x6f, 0x67]))
  }

  func testEncodeNestedList() {
    // [ [], [[]], [ [], [[]] ] ]
    let empty = RLP.encode(list: [])
    let nested1 = RLP.encode(list: [empty])
    let nested2 = RLP.encode(list: [empty, nested1])
    let encoded = RLP.encode(list: [empty, nested1, nested2])

    XCTAssertEqual(encoded, Data([0xc7, 0xc0, 0xc1, 0xc0, 0xc3, 0xc0, 0xc1, 0xc0]))
  }

  func testEncodeLongList() {
    // List with total payload > 55 bytes
    var items: [Data] = []
    for i in 0..<20 {
      items.append(RLP.encode("item\(i)"))
    }
    let encoded = RLP.encode(list: items)

    XCTAssertEqual(encoded[0], 0xf8)  // 0xf7 + 1 length byte
    XCTAssertTrue(encoded.count > 57)
  }

  // MARK: - Decode Single Byte

  func testDecodeSingleByte() throws {
    let decoded = try RLP.decode(Data([0x7f]))
    XCTAssertEqual(decoded.data, Data([0x7f]))
  }

  func testDecodeEmptyString() throws {
    let decoded = try RLP.decode(Data([0x80]))
    XCTAssertEqual(decoded.data, Data())
  }

  // MARK: - Decode Short String

  func testDecodeShortString() throws {
    let decoded = try RLP.decode(Data([0x83, 0x64, 0x6f, 0x67]))
    XCTAssertEqual(decoded.data, Data([0x64, 0x6f, 0x67]))  // "dog"
  }

  // MARK: - Decode Long String

  func testDecodeLongString() throws {
    var input = Data([0xb8, 56])
    input.append(Data(repeating: 0x01, count: 56))

    let decoded = try RLP.decode(input)
    XCTAssertEqual(decoded.data?.count, 56)
  }

  // MARK: - Decode List

  func testDecodeEmptyList() throws {
    let decoded = try RLP.decode(Data([0xc0]))
    XCTAssertNotNil(decoded.list)
    XCTAssertEqual(decoded.list?.count, 0)
  }

  func testDecodeShortList() throws {
    // ["cat", "dog"]
    let input = Data([0xc8, 0x83, 0x63, 0x61, 0x74, 0x83, 0x64, 0x6f, 0x67])
    let decoded = try RLP.decode(input)

    XCTAssertNotNil(decoded.list)
    XCTAssertEqual(decoded.list?.count, 2)
    XCTAssertEqual(decoded.list?[0].data, Data([0x63, 0x61, 0x74]))  // "cat"
    XCTAssertEqual(decoded.list?[1].data, Data([0x64, 0x6f, 0x67]))  // "dog"
  }

  func testDecodeNestedList() throws {
    let input = Data([0xc7, 0xc0, 0xc1, 0xc0, 0xc3, 0xc0, 0xc1, 0xc0])
    let decoded = try RLP.decode(input)

    XCTAssertNotNil(decoded.list)
    XCTAssertEqual(decoded.list?.count, 3)
    XCTAssertEqual(decoded.list?[0].list?.count, 0)  // []
    XCTAssertEqual(decoded.list?[1].list?.count, 1)  // [[]]
  }

  // MARK: - Decode Errors

  func testDecodeEmptyInput() {
    XCTAssertThrowsError(try RLP.decode(Data())) { error in
      XCTAssertTrue(error is RLPError)
    }
  }

  func testDecodeTruncatedData() {
    // Says 3 bytes but only has 2
    XCTAssertThrowsError(try RLP.decode(Data([0x83, 0x64, 0x6f]))) { error in
      XCTAssertTrue(error is RLPError)
    }
  }

  // MARK: - Round Trip

  func testRoundTripString() throws {
    let original = "Hello, Ethereum!"
    let encoded = RLP.encode(original)
    let decoded = try RLP.decode(encoded)

    XCTAssertEqual(String(data: decoded.data!, encoding: .utf8), original)
  }

  func testRoundTripList() throws {
    let items = [
      RLP.encode("one"),
      RLP.encode("two"),
      RLP.encode("three"),
    ]
    let encoded = RLP.encode(list: items)
    let decoded = try RLP.decode(encoded)

    XCTAssertEqual(decoded.list?.count, 3)
  }

  func testRoundTripInteger() throws {
    let original: UInt64 = 12_345_678
    let encoded = RLP.encode(original)
    let decoded = try RLP.decode(encoded)

    var value: UInt64 = 0
    for byte in decoded.data! {
      value = value << 8 | UInt64(byte)
    }
    XCTAssertEqual(value, original)
  }

  // MARK: - Ethereum Specific

  func testEncodeAddress() {
    let address = Data(repeating: 0xab, count: 20)
    let encoded = RLP.encode(address)

    XCTAssertEqual(encoded.count, 21)  // 1 prefix + 20 bytes
    XCTAssertEqual(encoded[0], 0x94)  // 0x80 + 20
  }

  func testEncodeTransactionLikeStructure() {
    // Simplified transaction: [nonce, gasPrice, gasLimit, to, value, data]
    let nonce = RLP.encode(9 as UInt64)
    let gasPrice = RLP.encode(20_000_000_000 as UInt64)
    let gasLimit = RLP.encode(21000 as UInt64)
    let to = RLP.encode(Data(repeating: 0xab, count: 20))
    let value = RLP.encode(1_000_000_000_000_000_000 as UInt64)
    let data = RLP.encode(Data())

    let encoded = RLP.encode(list: [nonce, gasPrice, gasLimit, to, value, data])

    XCTAssertTrue(encoded.count > 0)
    XCTAssertTrue(encoded[0] >= 0xc0)  // It's a list
  }
}
