//
//  WeiTests.swift
//  EthereumKitTests
//

import XCTest
@testable import EthereumKit
import MultiChainCore

final class WeiTests: XCTestCase {

    // MARK: - Initialization

    func testInitFromUInt64() {
        let wei = Wei(1000)
        XCTAssertEqual(wei.description, "1000")
    }

    func testInitFromIntegerLiteral() {
        let wei: Wei = 12345
        XCTAssertEqual(wei.description, "12345")
    }

    func testInitFromHexString() {
        let wei = Wei("0x3e8") // 1000
        XCTAssertNotNil(wei)
        XCTAssertEqual(wei?.description, "1000")
    }

    func testInitFromHexStringWithoutPrefix() {
        let wei = Wei("3e8") // 1000
        XCTAssertNotNil(wei)
        XCTAssertEqual(wei?.description, "1000")
    }

    func testInitFromHexStringLargeValue() {
        // 1 Ether = 10^18 Wei = 0xde0b6b3a7640000
        let wei = Wei("0xde0b6b3a7640000")
        XCTAssertNotNil(wei)
        XCTAssertEqual(wei?.description, "1000000000000000000")
    }

    func testInitFromInvalidHexString() {
        let wei = Wei("0xGGG")
        XCTAssertNil(wei)
    }

    func testZero() {
        XCTAssertEqual(Wei.zero.description, "0")
    }

    // MARK: - Hex String Output

    func testHexString() {
        let wei = Wei(255)
        XCTAssertEqual(wei.hexString, "0xff")
    }

    func testHexStringZero() {
        XCTAssertEqual(Wei.zero.hexString, "0x0")
    }

    func testHexStringLargeValue() {
        let wei = Wei("0xde0b6b3a7640000")!
        XCTAssertEqual(wei.hexString, "0xde0b6b3a7640000")
    }

    // MARK: - Unit Conversions

    func testFromGwei() {
        let wei = Wei.fromGwei(1)
        XCTAssertEqual(wei.description, "1000000000") // 10^9
    }

    func testFromEther() {
        let wei = Wei.fromEther(1)
        XCTAssertEqual(wei.description, "1000000000000000000") // 10^18
    }

    func testToGwei() {
        let wei = Wei.fromGwei(1) // 1 Gwei = 10^9 Wei
        XCTAssertEqual(wei.toGwei(), 1)
    }

    func testToGweiWithRemainder() {
        let wei = Wei.fromGwei(1) + Wei(500_000_000) // 1.5 Gwei
        XCTAssertEqual(wei.toGwei(), 1) // Truncates
    }

    func testToEther() {
        let wei = Wei.fromEther(1) // 1 Ether
        XCTAssertEqual(wei.toEther(), 1)
    }

    func testToEtherFractional() {
        let wei = Wei.fromEther(1) / Wei(2) // 0.5 Ether
        XCTAssertEqual(wei.toEther(), 0) // Truncates to 0
    }

    func testToEtherDecimal() {
        let wei = Wei.fromEther(1) + Wei.fromEther(1) / Wei(2) // 1.5 Ether
        XCTAssertEqual(wei.toEtherDecimal(), Decimal(string: "1.5"))
    }

    func testToGweiDecimal() {
        let wei = Wei.fromGwei(1) + Wei(500_000_000) // 1.5 Gwei
        XCTAssertEqual(wei.toGweiDecimal(), Decimal(string: "1.5"))
    }

    // MARK: - Comparison

    func testEquality() {
        let a = Wei(1000)
        let b = Wei(1000)
        XCTAssertEqual(a, b)
    }

    func testInequality() {
        let a = Wei(1000)
        let b = Wei(2000)
        XCTAssertNotEqual(a, b)
    }

    func testLessThan() {
        let a = Wei(1000)
        let b = Wei(2000)
        XCTAssertTrue(a < b)
        XCTAssertFalse(b < a)
    }

    func testGreaterThan() {
        let a = Wei(2000)
        let b = Wei(1000)
        XCTAssertTrue(a > b)
    }

    func testLessThanOrEqual() {
        let a = Wei(1000)
        let b = Wei(1000)
        let c = Wei(2000)
        XCTAssertTrue(a <= b)
        XCTAssertTrue(a <= c)
    }

    // MARK: - Arithmetic

    func testAddition() {
        let a = Wei(1000)
        let b = Wei(500)
        XCTAssertEqual((a + b).description, "1500")
    }

    func testSubtraction() {
        let a = Wei(1000)
        let b = Wei(300)
        XCTAssertEqual((a - b).description, "700")
    }

    func testMultiplication() {
        let a = Wei(100)
        let b = Wei(5)
        XCTAssertEqual((a * b).description, "500")
    }

    func testDivision() {
        let a = Wei(1000)
        let b = Wei(4)
        XCTAssertEqual((a / b).description, "250")
    }

    // MARK: - Large Values (256-bit)

    func testMaxUInt256() {
        // 2^256 - 1
        let maxHex = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        let wei = Wei(maxHex)
        XCTAssertNotNil(wei)
    }

    func testLargeAddition() {
        let a = Wei("0xffffffffffffffffffffffffffffffff")! // 128-bit max
        let b = Wei(1)
        let result = a + b
        XCTAssertEqual(result.hexString, "0x100000000000000000000000000000000")
    }

    // MARK: - Hashable

    func testHashable() {
        let a = Wei(1000)
        let b = Wei(1000)
        let c = Wei(2000)

        var set = Set<Wei>()
        set.insert(a)
        set.insert(b)
        set.insert(c)

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Codable

    func testEncode() throws {
        let wei = Wei(1000)
        let encoder = JSONEncoder()
        let data = try encoder.encode(wei)
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(json, "\"0x3e8\"")
    }

    func testDecode() throws {
        let json = "\"0x3e8\""
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let wei = try decoder.decode(Wei.self, from: data)
        XCTAssertEqual(wei.description, "1000")
    }

    func testDecodeInvalid() {
        let json = "\"invalid\""
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(Wei.self, from: data))
    }

    // MARK: - ChainValue Protocol

    func testConformsToChainValue() {
        let wei: any ChainValue = Wei(1000)
        XCTAssertEqual(wei.hexString, "0x3e8")
    }
}
