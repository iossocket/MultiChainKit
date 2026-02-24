//
//  CairoABITests.swift
//  StarknetKitTests
//
//  TDD tests for Cairo ABI encoding/decoding (enum-based CairoType/CairoValue).
//

import BigInt
import Foundation
import Testing

@testable import StarknetKit

// MARK: - CairoType

@Suite("CairoType")
struct CairoTypeTests {

  @Test("CairoType equality")
  func equality() {
    #expect(CairoType.felt252 == .felt252)
    #expect(CairoType.u256 == .u256)
    #expect(CairoType.array(.felt252) == .array(.felt252))
    #expect(CairoType.array(.felt252) != .array(.u256))
    #expect(CairoType.option(.u256) == .option(.u256))
    #expect(CairoType.tuple([.felt252, .u256]) == .tuple([.felt252, .u256]))
  }
}

// MARK: - Felt252 Encoding

@Suite("CairoValue felt252")
struct CairoValueFelt252Tests {

  @Test("felt252 encodes as single element")
  func encode() {
    let v = CairoValue.felt252(Felt(42))
    #expect(v.encode() == [Felt(42)])
  }

  @Test("felt252 zero encodes as [0]")
  func encodeZero() {
    #expect(CairoValue.felt252(.zero).encode() == [.zero])
  }

  @Test("felt252 decodes from calldata")
  func decode() throws {
    let calldata: [Felt] = [Felt(100), Felt(200)]
    let (value, consumed) = try CairoValue.decode(type: .felt252, from: calldata, at: 0)
    #expect(value == .felt252(Felt(100)))
    #expect(consumed == 1)
  }

  @Test("felt252 decodes at offset")
  func decodeOffset() throws {
    let calldata: [Felt] = [Felt(100), Felt(200), Felt(300)]
    let (value, consumed) = try CairoValue.decode(type: .felt252, from: calldata, at: 2)
    #expect(value == .felt252(Felt(300)))
    #expect(consumed == 1)
  }

  @Test("felt252 decode out of bounds throws")
  func decodeOutOfBounds() {
    let calldata: [Felt] = [Felt(1)]
    #expect(throws: CairoABIError.self) {
      try CairoValue.decode(type: .felt252, from: calldata, at: 1)
    }
  }
}

// MARK: - Bool Encoding

@Suite("CairoValue bool")
struct CairoValueBoolTests {

  @Test("true encodes as [1]")
  func trueEncode() {
    #expect(CairoValue.bool(true).encode() == [Felt(1)])
  }

  @Test("false encodes as [0]")
  func falseEncode() {
    #expect(CairoValue.bool(false).encode() == [.zero])
  }

  @Test("Decode 1 as true")
  func decodeTrue() throws {
    let (value, consumed) = try CairoValue.decode(type: .bool, from: [Felt(1)], at: 0)
    #expect(value == .bool(true))
    #expect(consumed == 1)
  }

  @Test("Decode 0 as false")
  func decodeFalse() throws {
    let (value, consumed) = try CairoValue.decode(type: .bool, from: [.zero], at: 0)
    #expect(value == .bool(false))
    #expect(consumed == 1)
  }

  @Test("Decode invalid bool throws")
  func decodeInvalid() {
    #expect(throws: CairoABIError.self) {
      try CairoValue.decode(type: .bool, from: [Felt(2)], at: 0)
    }
  }
}

// MARK: - Integer Encoding

@Suite("CairoValue integers")
struct CairoValueIntegerTests {

  @Test("u8 encodes as single felt")
  func u8Encode() {
    #expect(CairoValue.u8(255).encode() == [Felt(255)])
  }

  @Test("u8 decodes")
  func u8Decode() throws {
    let (value, consumed) = try CairoValue.decode(type: .u8, from: [Felt(42)], at: 0)
    #expect(value == .u8(42))
    #expect(consumed == 1)
  }

  @Test("u16 encodes as single felt")
  func u16Encode() {
    #expect(CairoValue.u16(65535).encode() == [Felt(65535)])
  }

  @Test("u16 decodes")
  func u16Decode() throws {
    let (value, consumed) = try CairoValue.decode(type: .u16, from: [Felt(1000)], at: 0)
    #expect(value == .u16(1000))
    #expect(consumed == 1)
  }

  @Test("u32 encodes as single felt")
  func u32Encode() {
    #expect(CairoValue.u32(0xDEAD_BEEF).encode() == [Felt(UInt64(0xDEAD_BEEF))])
  }

  @Test("u32 decodes")
  func u32Decode() throws {
    let (value, consumed) = try CairoValue.decode(type: .u32, from: [Felt(123456)], at: 0)
    #expect(value == .u32(123456))
    #expect(consumed == 1)
  }

  @Test("u64 encodes as single felt")
  func u64Encode() {
    #expect(CairoValue.u64(1_000_000_000_000).encode() == [Felt(1_000_000_000_000)])
  }

  @Test("u64 decodes")
  func u64Decode() throws {
    let (value, consumed) = try CairoValue.decode(type: .u64, from: [Felt(999)], at: 0)
    #expect(value == .u64(999))
    #expect(consumed == 1)
  }
}

// MARK: - u128

@Suite("CairoValue u128")
struct CairoValueU128Tests {

  @Test("u128 encodes as single felt")
  func encode() {
    let big = BigUInt("340282366920938463463374607431768211455")  // 2^128 - 1
    let encoded = CairoValue.u128(big).encode()
    #expect(encoded.count == 1)
    #expect(encoded[0].bigUIntValue == big)
  }

  @Test("u128 decodes")
  func decode() throws {
    let big = BigUInt("123456789012345678901234567890")
    let (value, consumed) = try CairoValue.decode(type: .u128, from: [Felt(big)], at: 0)
    #expect(value == .u128(big))
    #expect(consumed == 1)
  }

  @Test("u128 roundtrip")
  func roundtrip() throws {
    let big = BigUInt(42)
    let encoded = CairoValue.u128(big).encode()
    let (decoded, _) = try CairoValue.decode(type: .u128, from: encoded, at: 0)
    #expect(decoded == .u128(big))
  }
}

// MARK: - u256

@Suite("CairoValue u256")
struct CairoValueU256Tests {

  @Test("u256 encodes as [low, high]")
  func encode() {
    let v = CairoValue.u256(low: BigUInt(100), high: .zero)
    let encoded = v.encode()
    #expect(encoded.count == 2)
    #expect(encoded[0] == Felt(100))  // low
    #expect(encoded[1] == .zero)  // high
  }

  @Test("u256 large value splits correctly")
  func encodeLarge() {
    // 2^128 + 1 => low = 1, high = 1
    let v = CairoValue.u256(BigUInt(1) << 128 + BigUInt(1))
    let encoded = v.encode()
    #expect(encoded.count == 2)
    #expect(encoded[0] == Felt(1))  // low
    #expect(encoded[1] == Felt(1))  // high
  }

  @Test("u256 decodes from [low, high]")
  func decode() throws {
    let calldata = [Felt(500), Felt(0)]
    let (value, consumed) = try CairoValue.decode(type: .u256, from: calldata, at: 0)
    #expect(value == .u256(low: BigUInt(500), high: .zero))
    #expect(consumed == 2)
  }

  @Test("u256 roundtrip with large value")
  func roundtrip() throws {
    let big = BigUInt(
      "115792089237316195423570985008687907853269984665640564039457584007913129639935")  // 2^256 - 1
    let original = CairoValue.u256(big)
    let encoded = original.encode()
    let (decoded, _) = try CairoValue.decode(type: .u256, from: encoded, at: 0)
    #expect(decoded.u256Value == big)
  }

  @Test("u256Value property reconstructs correctly")
  func valueProperty() {
    let v = CairoValue.u256(low: BigUInt(0xFF), high: BigUInt(1))
    #expect(v.u256Value == (BigUInt(1) << 128) + BigUInt(0xFF))
  }

  @Test("u256 from 1 ETH (10^18)")
  func oneEth() throws {
    let oneEth = BigUInt("1000000000000000000")
    let v = CairoValue.u256(oneEth)
    let encoded = v.encode()
    #expect(encoded.count == 2)
    #expect(encoded[1] == .zero)  // fits in low 128 bits
    let (decoded, _) = try CairoValue.decode(type: .u256, from: encoded, at: 0)
    #expect(decoded.u256Value == oneEth)
  }
}

// MARK: - ContractAddress

@Suite("CairoValue contractAddress")
struct CairoValueContractAddressTests {

  @Test("contractAddress encodes as single felt")
  func encode() {
    let addr = Felt(0xABC)
    #expect(CairoValue.contractAddress(addr).encode() == [addr])
  }

  @Test("contractAddress decodes")
  func decode() throws {
    let (value, consumed) = try CairoValue.decode(
      type: .contractAddress, from: [Felt(0x123)], at: 0)
    #expect(value == .contractAddress(Felt(0x123)))
    #expect(consumed == 1)
  }
}

// MARK: - ByteArray

@Suite("CairoValue byteArray")
struct CairoValueByteArrayTests {

  @Test("Short string (< 31 bytes) encodes correctly")
  func shortString() {
    let ba = CairoByteArray(string: "hello")
    let encoded = CairoValue.byteArray(ba).encode()
    // [0 full words, pending_word, 5]
    #expect(encoded.count == 3)
    #expect(encoded[0] == .zero)  // num_full_words = 0
    #expect(encoded[2] == Felt(5))  // pending_word_len = 5
  }

  @Test("Empty string encodes as [0, 0, 0]")
  func emptyString() {
    let ba = CairoByteArray(string: "")
    let encoded = CairoValue.byteArray(ba).encode()
    #expect(encoded == [.zero, .zero, .zero])
  }

  @Test("Exactly 31 bytes = 1 full word, 0 pending")
  func exactly31Bytes() {
    let ba = CairoByteArray(string: String(repeating: "a", count: 31))
    let encoded = CairoValue.byteArray(ba).encode()
    // [1, word0, pending_word=0, pending_len=0]
    #expect(encoded.count == 4)
    #expect(encoded[0] == Felt(1))  // 1 full word
    #expect(encoded[3] == .zero)  // pending_word_len = 0
  }

  @Test("32 bytes = 1 full word + 1 pending byte")
  func thirtyTwoBytes() {
    let ba = CairoByteArray(string: String(repeating: "b", count: 32))
    let encoded = CairoValue.byteArray(ba).encode()
    // [1, word0, pending_word, 1]
    #expect(encoded.count == 4)
    #expect(encoded[0] == Felt(1))  // 1 full word
    #expect(encoded[3] == Felt(1))  // 1 pending byte
  }

  @Test("62 bytes = 2 full words, 0 pending")
  func sixtyTwoBytes() {
    let ba = CairoByteArray(string: String(repeating: "c", count: 62))
    let encoded = CairoValue.byteArray(ba).encode()
    // [2, word0, word1, pending_word=0, pending_len=0]
    #expect(encoded.count == 5)
    #expect(encoded[0] == Felt(2))
    #expect(encoded[4] == .zero)
  }

  @Test("Short string roundtrip")
  func shortStringRoundtrip() throws {
    let original = "hello world"
    let ba = CairoByteArray(string: original)
    let encoded = CairoValue.byteArray(ba).encode()
    let (decoded, consumed) = try CairoValue.decode(type: .byteArray, from: encoded, at: 0)
    guard case .byteArray(let decodedBA) = decoded else {
      #expect(Bool(false), "Expected .byteArray")
      return
    }
    #expect(decodedBA.toString() == original)
    #expect(consumed == encoded.count)
  }

  @Test("Long string roundtrip")
  func longStringRoundtrip() throws {
    let original =
      "The quick brown fox jumps over the lazy dog. This is a longer string for testing."
    let ba = CairoByteArray(string: original)
    let encoded = CairoValue.byteArray(ba).encode()
    let (decoded, _) = try CairoValue.decode(type: .byteArray, from: encoded, at: 0)
    guard case .byteArray(let decodedBA) = decoded else {
      #expect(Bool(false), "Expected .byteArray")
      return
    }
    #expect(decodedBA.toString() == original)
  }

  @Test("toString recovers original bytes")
  func toStringRecovery() {
    let ba = CairoByteArray(string: "ABC")
    #expect(ba.toString() == "ABC")
  }
}

// MARK: - Option

@Suite("CairoValue option")
struct CairoValueOptionTests {

  @Test("Some(felt) encodes as [0, value]")
  func someEncode() {
    let v = CairoValue.some(.felt252(Felt(42)))
    let encoded = v.encode()
    #expect(encoded.count == 2)
    #expect(encoded[0] == .zero)  // variant 0 = Some
    #expect(encoded[1] == Felt(42))
  }

  @Test("None encodes as [1]")
  func noneEncode() {
    let encoded = CairoValue.none.encode()
    #expect(encoded.count == 1)
    #expect(encoded[0] == Felt(1))  // variant 1 = None
  }

  @Test("Decode Some")
  func decodeSome() throws {
    let calldata = [Felt.zero, Felt(99)]
    let (value, consumed) = try CairoValue.decode(type: .option(.felt252), from: calldata, at: 0)
    #expect(value == .some(.felt252(Felt(99))))
    #expect(consumed == 2)
  }

  @Test("Decode None")
  func decodeNone() throws {
    let calldata = [Felt(1)]
    let (value, consumed) = try CairoValue.decode(type: .option(.felt252), from: calldata, at: 0)
    #expect(value == .none)
    #expect(consumed == 1)
  }

  @Test("Invalid variant throws")
  func invalidVariant() {
    #expect(throws: CairoABIError.self) {
      try CairoValue.decode(type: .option(.felt252), from: [Felt(2)], at: 0)
    }
  }

  @Test("Option<u256> Some roundtrip")
  func optionU256Roundtrip() throws {
    let inner = CairoValue.u256(BigUInt(1000))
    let v = CairoValue.some(inner)
    let encoded = v.encode()
    // [0, low, high] = 3 felts
    #expect(encoded.count == 3)
    let (decoded, _) = try CairoValue.decode(type: .option(.u256), from: encoded, at: 0)
    #expect(decoded == v)
  }
}

// MARK: - Array

@Suite("CairoValue array")
struct CairoValueArrayTests {

  @Test("Empty array encodes as [0]")
  func emptyArray() {
    let v = CairoValue.array([])
    #expect(v.encode() == [.zero])
  }

  @Test("Felt array encodes with length prefix")
  func feltArray() {
    let v = CairoValue.array([.felt252(Felt(10)), .felt252(Felt(20)), .felt252(Felt(30))])
    let encoded = v.encode()
    #expect(encoded == [Felt(3), Felt(10), Felt(20), Felt(30)])
  }

  @Test("u256 array encodes correctly")
  func u256Array() {
    let v = CairoValue.array([.u256(BigUInt(100)), .u256(BigUInt(200))])
    let encoded = v.encode()
    // [2, low0, high0, low1, high1] = 5 felts
    #expect(encoded.count == 5)
    #expect(encoded[0] == Felt(2))  // length
  }

  @Test("Array decode roundtrip")
  func decodeRoundtrip() throws {
    let original = CairoValue.array([.felt252(Felt(1)), .felt252(Felt(2)), .felt252(Felt(3))])
    let encoded = original.encode()
    let (decoded, consumed) = try CairoValue.decode(type: .array(.felt252), from: encoded, at: 0)
    #expect(decoded == original)
    #expect(consumed == 4)
  }
}

// MARK: - Tuple

@Suite("CairoValue tuple")
struct CairoValueTupleTests {

  @Test("Tuple encodes fields in order")
  func encode() {
    let v = CairoValue.tuple([.felt252(Felt(1)), .bool(true), .u64(999)])
    let encoded = v.encode()
    #expect(encoded == [Felt(1), Felt(1), Felt(999)])
  }

  @Test("Empty tuple encodes as []")
  func emptyTuple() {
    #expect(CairoValue.tuple([]).encode() == [])
  }

  @Test("Tuple with u256 field")
  func tupleWithU256() {
    let v = CairoValue.tuple([.felt252(Felt(0xABC)), .u256(BigUInt(500))])
    let encoded = v.encode()
    // felt(1) + u256(2) = 3 felts
    #expect(encoded.count == 3)
    #expect(encoded[0] == Felt(0xABC))
  }

  @Test("Tuple decode roundtrip")
  func decodeRoundtrip() throws {
    let original = CairoValue.tuple([.felt252(Felt(0x1)), .u256(BigUInt(1000))])
    let encoded = original.encode()
    let (decoded, consumed) = try CairoValue.decode(
      type: .tuple([.felt252, .u256]), from: encoded, at: 0)
    #expect(decoded == original)
    #expect(consumed == 3)
  }
}

// MARK: - Enum

@Suite("CairoValue enum")
struct CairoValueEnumTests {

  @Test("Enum variant 0 encodes as [0, ...data]")
  func encodeVariant0() {
    let v = CairoValue.enum(variant: 0, data: [.felt252(Felt(42))])
    let encoded = v.encode()
    #expect(encoded == [.zero, Felt(42)])
  }

  @Test("Enum variant with no data")
  func encodeVariantNoData() {
    let v = CairoValue.enum(variant: 2, data: [])
    let encoded = v.encode()
    #expect(encoded == [Felt(2)])
  }
}

// MARK: - encodeCalldata

@Suite("CairoValue encodeCalldata")
struct CairoValueEncodeCalldataTests {

  @Test("Encode single felt")
  func encodeSingle() {
    let calldata = CairoValue.encodeCalldata(.felt252(Felt(42)))
    #expect(calldata == [Felt(42)])
  }

  @Test("Encode multiple values")
  func encodeMultiple() {
    let calldata = CairoValue.encodeCalldata(
      .felt252(Felt(0x1)),
      .felt252(Felt(100)),
      .felt252(.zero)
    )
    #expect(calldata == [Felt(0x1), Felt(100), .zero])
  }

  @Test("Encode mixed types: felt + u256 + bool")
  func encodeMixed() {
    let calldata = CairoValue.encodeCalldata(
      .felt252(Felt(0xabc)),
      .u256(BigUInt(1000)),
      .bool(true)
    )
    // felt(1) + u256(2) + bool(1) = 4 felts
    #expect(calldata.count == 4)
    #expect(calldata[0] == Felt(0xabc))
    #expect(calldata[3] == Felt(1))  // true
  }

  @Test("ERC20 transfer calldata: (recipient, amount_u256)")
  func erc20TransferCalldata() {
    let calldata = CairoValue.encodeCalldata(
      .contractAddress(Felt(0x1234)),
      .u256(BigUInt("1000000000000000000"))  // 1 ETH
    )
    // address(1) + u256(2) = 3 felts
    #expect(calldata.count == 3)
  }

  @Test("Sequential decode from encoded calldata")
  func sequentialDecode() throws {
    let calldata = CairoValue.encodeCalldata(
      .felt252(Felt(0x1)),
      .u256(BigUInt(500))
    )
    var offset = 0
    let (addr, c1) = try CairoValue.decode(type: .felt252, from: calldata, at: offset)
    offset += c1
    let (amount, c2) = try CairoValue.decode(type: .u256, from: calldata, at: offset)
    offset += c2

    #expect(addr == .felt252(Felt(0x1)))
    #expect(amount.u256Value == BigUInt(500))
    #expect(offset == 3)
  }
}
