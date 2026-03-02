//
//  ABIValueAsTests.swift
//  EthereumKitTests
//
//  Tests for ABIValue.as(_:) type conversion
//

import BigInt
import XCTest
@testable import EthereumKit

final class ABIValueAsTests: XCTestCase {
  
  func testAsWei() {
    let wei = Wei(27000000)
    let value = ABIValue.uint(bits: 256, value: wei)
    
    let result: Wei? = value.as(Wei.self)
    XCTAssertEqual(result, wei)
  }
  
  func testAsUInt64() {
    let wei = Wei(27000000)
    let value = ABIValue.uint(bits: 256, value: wei)
    
    let result: UInt64? = value.as(UInt64.self)
    XCTAssertEqual(result, 27000000)
  }
  
  func testAsInt() {
    let wei = Wei(27000000)
    let value = ABIValue.uint(bits: 256, value: wei)
    
    let result: Int? = value.as(Int.self)
    XCTAssertEqual(result, 27000000)
  }
  
  func testAsUInt() {
    let wei = Wei(27000000)
    let value = ABIValue.uint(bits: 256, value: wei)
    
    let result: UInt? = value.as(UInt.self)
    XCTAssertEqual(result, 27000000)
  }
  
  func testAsUInt32() {
    let wei = Wei(27000000)
    let value = ABIValue.uint(bits: 32, value: wei)
    
    let result: UInt32? = value.as(UInt32.self)
    XCTAssertEqual(result, 27000000)
  }
  
  func testAsUInt8() {
    let wei = Wei(255)
    let value = ABIValue.uint(bits: 8, value: wei)
    
    let result: UInt8? = value.as(UInt8.self)
    XCTAssertEqual(result, 255)
  }
  
  func testAsIntFromSignedValue() {
    let wei = Wei(42)
    let value = ABIValue.int(bits: 256, value: wei)

    let result: Int? = value.as(Int.self)
    XCTAssertEqual(result, 42)
  }

  func testAsBigUInt() {
    // Test with a value larger than UInt64.max
    let largeValue = BigUInt(stringLiteral: "18446744073709551616") // UInt64.max + 1
    let wei = Wei(largeValue)
    let value = ABIValue.uint(bits: 256, value: wei)

    let result: BigUInt? = value.as(BigUInt.self)
    XCTAssertNotNil(result)
    XCTAssertEqual(result, largeValue)
  }

  func testAsBigUIntFromInt() {
    let wei = Wei(42)
    let value = ABIValue.int(bits: 256, value: wei)

    let result: BigUInt? = value.as(BigUInt.self)
    XCTAssertNotNil(result)
    XCTAssertEqual(result, BigUInt(42))
  }

  func testLargeValueFailsForUInt64() {
    // Value larger than UInt64.max should fail for UInt64 conversion
    let largeValue = BigUInt(stringLiteral: "18446744073709551616") // UInt64.max + 1
    let wei = Wei(largeValue)
    let value = ABIValue.uint(bits: 256, value: wei)

    let result: UInt64? = value.as(UInt64.self)
    XCTAssertNil(result)
  }
}
