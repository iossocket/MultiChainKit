//
//  ContractReadSingleTests.swift
//  EthereumKitTests
//
//  Tests for EthereumContract.readSingle with various integer types
//

import XCTest
@testable import EthereumKit

final class ContractReadSingleTests: XCTestCase {
  
  func testReadSingleAsInt() throws {
    // Simulate decoding a uint256 result and converting to Int
    let hexString = "0x00000000000000000000000000000000000000000000000000000000019bfcc0"
    let data = Data(hex: String(hexString.dropFirst(2)))
    
    let result = try ABIValue.decode(types: [.uint(256)], data: data)
    
    XCTAssertEqual(result.count, 1)
    
    // Test conversion to Int
    let intValue: Int? = result[0].as(Int.self)
    XCTAssertNotNil(intValue)
    XCTAssertEqual(intValue, 27000000)
  }
  
  func testReadSingleAsUInt() throws {
    let hexString = "0x00000000000000000000000000000000000000000000000000000000019bfcc0"
    let data = Data(hex: String(hexString.dropFirst(2)))
    
    let result = try ABIValue.decode(types: [.uint(256)], data: data)
    
    let uintValue: UInt? = result[0].as(UInt.self)
    XCTAssertNotNil(uintValue)
    XCTAssertEqual(uintValue, 27000000)
  }
  
  func testReadSingleAsUInt32() throws {
    let hexString = "0x00000000000000000000000000000000000000000000000000000000019bfcc0"
    let data = Data(hex: String(hexString.dropFirst(2)))
    
    let result = try ABIValue.decode(types: [.uint(32)], data: data)
    
    let uint32Value: UInt32? = result[0].as(UInt32.self)
    XCTAssertNotNil(uint32Value)
    XCTAssertEqual(uint32Value, 27000000)
  }
  
  func testReadSingleAsUInt8() throws {
    // Test with uint8 value (e.g., decimals())
    let hexString = "0x0000000000000000000000000000000000000000000000000000000000000012"
    let data = Data(hex: String(hexString.dropFirst(2)))
    
    let result = try ABIValue.decode(types: [.uint(8)], data: data)
    
    let uint8Value: UInt8? = result[0].as(UInt8.self)
    XCTAssertNotNil(uint8Value)
    XCTAssertEqual(uint8Value, 18)
  }
  
  func testReadSingleAsWei() throws {
    // Test that Wei conversion still works
    let hexString = "0x00000000000000000000000000000000000000000000000000000000019bfcc0"
    let data = Data(hex: String(hexString.dropFirst(2)))
    
    let result = try ABIValue.decode(types: [.uint(256)], data: data)
    
    let weiValue: Wei? = result[0].as(Wei.self)
    XCTAssertNotNil(weiValue)
    XCTAssertEqual(weiValue, Wei(27000000))
  }
  
  func testReadSingleTypeMismatch() throws {
    // Test that type mismatch returns nil
    let data = Data(hex: "0000000000000000000000000000000000000000000000000000000000000001")
    let result = try ABIValue.decode(types: [.bool], data: data)
    
    // Trying to convert bool to Int should return nil
    let intValue: Int? = result[0].as(Int.self)
    XCTAssertNil(intValue)
  }
  
  func testReadSingleOverflow() throws {
    // Test value that's too large for UInt8
    let hexString = "0x0000000000000000000000000000000000000000000000000000000000000100" // 256
    let data = Data(hex: String(hexString.dropFirst(2)))
    
    let result = try ABIValue.decode(types: [.uint(256)], data: data)
    
    // Should return nil because 256 doesn't fit in UInt8
    let uint8Value: UInt8? = result[0].as(UInt8.self)
    XCTAssertNil(uint8Value)
  }
}
