//
//  FeltTests.swift
//  StarknetKitTests
//
//  Tests for Starknet Felt (Field Element) type
//

import Foundation
import Testing

@testable import StarknetKit

// MARK: - Felt Tests

@Suite("Felt Tests")
struct FeltTests {

  // MARK: - Constants

  // Starknet prime: 2^251 + 17 * 2^192 + 1
  static let PRIME_HEX = "0x800000000000011000000000000000000000000000000000000000000000001"

  // MARK: - Initialization Tests

  @Test("Initialize from UInt64")
  func initFromUInt64() {
    let felt = Felt(123_456_789)
    #expect(felt.hexString == "0x75bcd15")
  }

  @Test("Initialize from zero")
  func initFromZero() {
    let felt = Felt(0)
    #expect(felt == Felt.zero)
    #expect(felt.hexString == "0x0")
  }

  @Test("Initialize from hex string with 0x prefix")
  func initFromHexWithPrefix() {
    let felt = Felt("0x1234abcd")
    #expect(felt != nil)
    #expect(felt?.hexString == "0x1234abcd")
  }

  @Test("Initialize from hex string without prefix")
  func initFromHexWithoutPrefix() {
    let felt = Felt("1234abcd")
    #expect(felt != nil)
    #expect(felt?.hexString == "0x1234abcd")
  }

  @Test("Initialize from uppercase hex")
  func initFromUppercaseHex() {
    let felt = Felt("0x1234ABCD")
    #expect(felt != nil)
    #expect(felt?.hexString == "0x1234abcd")
  }

  @Test("Initialize from invalid hex returns nil")
  func initFromInvalidHex() {
    let felt = Felt("0xGGGG")
    #expect(felt == nil)
  }

  @Test("Initialize from empty string returns nil")
  func initFromEmptyString() {
    let felt = Felt("")
    #expect(felt == nil)
  }

  @Test("Initialize from integer literal")
  func initFromIntegerLiteral() {
    let felt: Felt = 42
    #expect(felt.hexString == "0x2a")
  }

  // MARK: - Prime Field Tests

  @Test("Value at prime boundary wraps to zero")
  func primeWrapsToZero() {
    // PRIME should wrap to 0
    let felt = Felt(FeltTests.PRIME_HEX)
    #expect(felt != nil)
    #expect(felt == Felt.zero)
  }

  @Test("Value greater than prime is reduced")
  func valueGreaterThanPrimeIsReduced() {
    // PRIME + 1 should equal 1
    let primeHex = FeltTests.PRIME_HEX
    guard let prime = Felt(primeHex) else {
      Issue.record("Failed to create prime")
      return
    }
    let one: Felt = 1
    let result = prime + one
    #expect(result == one)
  }

  @Test("Maximum valid felt value")
  func maxValidFelt() {
    // PRIME - 1 is the maximum valid value
    let maxHex = "0x800000000000011000000000000000000000000000000000000000000000000"
    let felt = Felt(maxHex)
    #expect(felt != nil)
  }

  // MARK: - Arithmetic Tests

  @Test("Addition")
  func addition() {
    let a = Felt(100)
    let b = Felt(200)
    let result = a + b
    #expect(result == Felt(300))
  }

  @Test("Addition with overflow wraps around prime")
  func additionOverflow() {
    // (PRIME - 1) + 2 = 1
    let maxHex = "0x800000000000011000000000000000000000000000000000000000000000000"
    guard let max = Felt(maxHex) else {
      Issue.record("Failed to create max felt")
      return
    }
    let two: Felt = 2
    let result = max + two
    #expect(result == Felt(1))
  }

  @Test("Subtraction")
  func subtraction() {
    let a = Felt(300)
    let b = Felt(100)
    let result = a - b
    #expect(result == Felt(200))
  }

  @Test("Subtraction with underflow wraps around prime")
  func subtractionUnderflow() {
    // 0 - 1 = PRIME - 1
    let zero = Felt.zero
    let one: Felt = 1
    let result = zero - one
    let maxHex = "0x800000000000011000000000000000000000000000000000000000000000000"
    #expect(result == Felt(maxHex))
  }

  @Test("Multiplication")
  func multiplication() {
    let a = Felt(100)
    let b = Felt(200)
    let result = a * b
    #expect(result == Felt(20000))
  }

  @Test("Multiplication by zero")
  func multiplicationByZero() {
    let a = Felt(12345)
    let result = a * Felt.zero
    #expect(result == Felt.zero)
  }

  @Test("Multiplication by one")
  func multiplicationByOne() {
    let a = Felt(12345)
    let one: Felt = 1
    let result = a * one
    #expect(result == a)
  }

  @Test("Division")
  func division() {
    let a = Felt(20000)
    let b = Felt(100)
    let result = a / b
    #expect(result == Felt(200))
  }

  @Test("Division is multiplication by inverse")
  func divisionIsMultiplicationByInverse() {
    // a / b = a * b^(-1) mod p
    let a = Felt(100)
    let b = Felt(7)
    let quotient = a / b
    // Verify: quotient * b = a
    #expect(quotient * b == a)
  }

  // MARK: - Comparison Tests

  @Test("Equality")
  func equality() {
    let a = Felt(12345)
    let b = Felt(12345)
    #expect(a == b)
  }

  @Test("Inequality")
  func inequality() {
    let a = Felt(12345)
    let b = Felt(54321)
    #expect(a != b)
  }

  @Test("Less than")
  func lessThan() {
    let a = Felt(100)
    let b = Felt(200)
    #expect(a < b)
  }

  @Test("Greater than")
  func greaterThan() {
    let a = Felt(200)
    let b = Felt(100)
    #expect(a > b)
  }

  @Test("Less than or equal")
  func lessThanOrEqual() {
    let a = Felt(100)
    let b = Felt(100)
    let c = Felt(200)
    #expect(a <= b)
    #expect(a <= c)
  }

  // MARK: - Hex String Tests

  @Test("Hex string is lowercase")
  func hexStringIsLowercase() {
    let felt = Felt("0xABCDEF")!
    #expect(felt.hexString == "0xabcdef")
  }

  @Test("Hex string has 0x prefix")
  func hexStringHasPrefix() {
    let felt = Felt(255)
    #expect(felt.hexString.hasPrefix("0x"))
  }

  @Test("Hex string removes leading zeros")
  func hexStringRemovesLeadingZeros() {
    let felt = Felt("0x0000001234")!
    #expect(felt.hexString == "0x1234")
  }

  @Test("Zero hex string")
  func zeroHexString() {
    let felt = Felt.zero
    #expect(felt.hexString == "0x0")
  }

  // MARK: - Data Conversion Tests

  @Test("Convert to big-endian Data")
  func toBigEndianData() {
    let felt = Felt(0x1234)
    let data = felt.bigEndianData
    // Should be 32 bytes, big-endian
    #expect(data.count == 32)
    #expect(data[30] == 0x12)
    #expect(data[31] == 0x34)
  }

  @Test("Initialize from Data")
  func initFromData() {
    var data = Data(repeating: 0, count: 32)
    data[30] = 0x12
    data[31] = 0x34
    let felt = Felt(data)
    #expect(felt.hexString == "0x1234")
  }

  // MARK: - Hashable Tests

  @Test("Hashable conformance")
  func hashable() {
    let a = Felt(12345)
    let b = Felt(12345)
    let c = Felt(54321)

    var set = Set<Felt>()
    set.insert(a)
    set.insert(b)
    set.insert(c)

    #expect(set.count == 2)
  }

  // MARK: - Codable Tests

  @Test("Encode to JSON")
  func encodeToJSON() throws {
    let felt = Felt(0x1234)
    let encoder = JSONEncoder()
    let data = try encoder.encode(felt)
    let json = String(data: data, encoding: .utf8)!
    #expect(json == "\"0x1234\"")
  }

  @Test("Decode from JSON")
  func decodeFromJSON() throws {
    let json = "\"0x1234\""
    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    let felt = try decoder.decode(Felt.self, from: data)
    #expect(felt == Felt(0x1234))
  }

  // MARK: - Description Tests

  @Test("CustomStringConvertible")
  func customStringConvertible() {
    let felt = Felt(12345)
    #expect(felt.description.contains("12345") || felt.description.contains("0x3039"))
  }

  // MARK: - Special Values Tests

  @Test("One constant")
  func oneConstant() {
    let one = Felt.one
    #expect(one == Felt(1))
  }

  @Test("Zero is additive identity")
  func zeroIsAdditiveIdentity() {
    let a = Felt(12345)
    #expect(a + Felt.zero == a)
    #expect(Felt.zero + a == a)
  }

  @Test("One is multiplicative identity")
  func oneIsMultiplicativeIdentity() {
    let a = Felt(12345)
    #expect(a * Felt.one == a)
    #expect(Felt.one * a == a)
  }

  // MARK: - Modular Inverse Tests

  @Test("Modular inverse")
  func modularInverse() {
    let a = Felt(7)
    guard let inv = a.inverse() else {
      Issue.record("Failed to compute inverse")
      return
    }
    // a * a^(-1) = 1
    #expect(a * inv == Felt.one)
  }

  @Test("Zero has no inverse")
  func zeroHasNoInverse() {
    let zero = Felt.zero
    let inv = zero.inverse()
    #expect(inv == nil)
  }

  // MARK: - Power Tests

  @Test("Power of zero")
  func powerOfZero() {
    let a = Felt(12345)
    let result = a.pow(UInt64(0))
    #expect(result == Felt.one)
  }

  @Test("Power of one")
  func powerOfOne() {
    let a = Felt(12345)
    let result = a.pow(UInt64(1))
    #expect(result == a)
  }

  @Test("Power of two")
  func powerOfTwo() {
    let a = Felt(5)
    let result = a.pow(UInt64(2))
    #expect(result == Felt(25))
  }

  @Test("Power of larger exponent")
  func powerOfLargerExponent() {
    let a = Felt(2)
    let result = a.pow(UInt64(10))
    #expect(result == Felt(1024))
  }

  // MARK: - Bit Operations Tests

  @Test("Bit length")
  func bitLength() {
    let felt = Felt(0b11111111)  // 255
    #expect(felt.bitLength == 8)

    let felt2 = Felt(0b100000000)  // 256
    #expect(felt2.bitLength == 9)

    #expect(Felt.zero.bitLength == 0)
  }

  // MARK: - Test Vectors from Starknet

  @Test("Starknet test vector 1")
  func starknetTestVector1() {
    // Known test vector
    let a = Felt("0x3e8")!  // 1000
    let b = Felt("0x7d0")!  // 2000
    let sum = a + b
    #expect(sum == Felt("0xbb8"))  // 3000
  }

  @Test("Starknet test vector 2")
  func starknetTestVector2() {
    // Large number test
    let felt = Felt("0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7")!
    #expect(felt.hexString == "0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7")
  }
}
