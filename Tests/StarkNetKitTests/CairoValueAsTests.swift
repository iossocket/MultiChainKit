//
//  CairoValueAsTests.swift
//  StarknetKitTests
//

import BigInt
import Foundation
import Testing

@testable import StarknetKit

@Suite("CairoValue+As")
struct CairoValueAsTests {

  // MARK: - felt252

  @Test("felt252 as Felt")
  func felt252AsFelt() {
    let felt = Felt(42)
    let value = CairoValue.felt252(felt)
    #expect(value.as(Felt.self) == felt)
  }

  @Test("felt252 as BigUInt")
  func felt252AsBigUInt() {
    let value = CairoValue.felt252(Felt(255))
    #expect(value.as(BigUInt.self) == BigUInt(255))
  }

  @Test("felt252 as String returns hex")
  func felt252AsString() {
    let value = CairoValue.felt252(Felt(0xff))
    let str = value.as(String.self)
    #expect(str != nil)
    #expect(str!.contains("ff"))
  }

  @Test("felt252 as Bool returns nil")
  func felt252AsBoolNil() {
    let value = CairoValue.felt252(Felt(1))
    #expect(value.as(Bool.self) == nil)
  }

  // MARK: - bool

  @Test("bool as Bool")
  func boolAsBool() {
    #expect(CairoValue.bool(true).as(Bool.self) == true)
    #expect(CairoValue.bool(false).as(Bool.self) == false)
  }

  @Test("bool as Int returns nil")
  func boolAsIntNil() {
    #expect(CairoValue.bool(true).as(Int.self) == nil)
  }

  // MARK: - u8

  @Test("u8 conversions")
  func u8Conversions() {
    let value = CairoValue.u8(200)
    #expect(value.as(UInt8.self) == 200)
    #expect(value.as(UInt16.self) == 200)
    #expect(value.as(UInt32.self) == 200)
    #expect(value.as(UInt64.self) == 200)
    #expect(value.as(Int.self) == 200)
    #expect(value.as(BigUInt.self) == BigUInt(200))
  }

  // MARK: - u16

  @Test("u16 conversions")
  func u16Conversions() {
    let value = CairoValue.u16(1000)
    #expect(value.as(UInt16.self) == 1000)
    #expect(value.as(UInt32.self) == 1000)
    #expect(value.as(UInt64.self) == 1000)
    #expect(value.as(Int.self) == 1000)
    #expect(value.as(BigUInt.self) == BigUInt(1000))
    #expect(value.as(UInt8.self) == nil)  // no downcast
  }

  // MARK: - u32

  @Test("u32 conversions")
  func u32Conversions() {
    let value = CairoValue.u32(70000)
    #expect(value.as(UInt32.self) == 70000)
    #expect(value.as(UInt64.self) == 70000)
    #expect(value.as(Int.self) == 70000)
    #expect(value.as(BigUInt.self) == BigUInt(70000))
  }

  // MARK: - u64

  @Test("u64 conversions")
  func u64Conversions() {
    let value = CairoValue.u64(UInt64.max)
    #expect(value.as(UInt64.self) == UInt64.max)
    #expect(value.as(BigUInt.self) == BigUInt(UInt64.max))
    // Int overflow on 64-bit
    #expect(value.as(Int.self) == nil)
  }

  @Test("u64 small value as Int")
  func u64SmallAsInt() {
    let value = CairoValue.u64(42)
    #expect(value.as(Int.self) == 42)
  }

  // MARK: - u128

  @Test("u128 as BigUInt")
  func u128AsBigUInt() {
    let big = BigUInt(1) << 100
    let value = CairoValue.u128(big)
    #expect(value.as(BigUInt.self) == big)
  }

  @Test("u128 small as UInt64")
  func u128SmallAsUInt64() {
    let value = CairoValue.u128(BigUInt(999))
    #expect(value.as(UInt64.self) == 999)
  }

  @Test("u128 large as UInt64 returns nil")
  func u128LargeAsUInt64Nil() {
    let big = BigUInt(1) << 100
    let value = CairoValue.u128(big)
    #expect(value.as(UInt64.self) == nil)
  }

  // MARK: - u256

  @Test("u256 as BigUInt")
  func u256AsBigUInt() {
    let low = BigUInt(1)
    let high = BigUInt(2)
    let value = CairoValue.u256(low: low, high: high)
    let expected = (high << 128) + low
    #expect(value.as(BigUInt.self) == expected)
  }

  @Test("u256 as String returns nil")
  func u256AsStringNil() {
    let value = CairoValue.u256(low: BigUInt(1), high: BigUInt(0))
    #expect(value.as(String.self) == nil)
  }

  // MARK: - contractAddress

  @Test("contractAddress as Felt")
  func contractAddressAsFelt() {
    let felt = Felt(0xabc)
    let value = CairoValue.contractAddress(felt)
    #expect(value.as(Felt.self) == felt)
  }

  @Test("contractAddress as StarknetAddress")
  func contractAddressAsStarknetAddress() {
    let felt = Felt(0xabc)
    let value = CairoValue.contractAddress(felt)
    let addr = value.as(StarknetAddress.self)
    #expect(addr != nil)
  }

  @Test("contractAddress as String")
  func contractAddressAsString() {
    let felt = Felt(0xabc)
    let value = CairoValue.contractAddress(felt)
    #expect(value.as(String.self) != nil)
  }

  // MARK: - byteArray

  @Test("byteArray as String")
  func byteArrayAsString() {
    let ba = CairoByteArray(string: "hello")
    let value = CairoValue.byteArray(ba)
    #expect(value.as(String.self) == "hello")
  }

  @Test("byteArray as CairoByteArray")
  func byteArrayAsCairoByteArray() {
    let ba = CairoByteArray(string: "test")
    let value = CairoValue.byteArray(ba)
    #expect(value.as(CairoByteArray.self) == ba)
  }

  // MARK: - array

  @Test("array as [CairoValue]")
  func arrayAsCairoValues() {
    let values: [CairoValue] = [.u8(1), .u8(2), .u8(3)]
    let value = CairoValue.array(values)
    #expect(value.as([CairoValue].self) == values)
  }

  // MARK: - option

  @Test("some unwraps inner value")
  func someUnwraps() {
    let value = CairoValue.some(.u64(42))
    #expect(value.as(UInt64.self) == 42)
  }

  @Test("none returns nil")
  func noneReturnsNil() {
    let value = CairoValue.none
    #expect(value.as(UInt64.self) == nil)
  }

  // MARK: - tuple

  @Test("tuple as [CairoValue]")
  func tupleAsCairoValues() {
    let fields: [CairoValue] = [.felt252(Felt(1)), .bool(true)]
    let value = CairoValue.tuple(fields)
    #expect(value.as([CairoValue].self) == fields)
  }

  // MARK: - enum

  @Test("enum as [CairoValue]")
  func enumAsCairoValues() {
    let data: [CairoValue] = [.u32(10)]
    let value = CairoValue.enum(variant: 1, data: data)
    #expect(value.as([CairoValue].self) == data)
  }
}
