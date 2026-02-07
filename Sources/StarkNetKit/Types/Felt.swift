//
//  Felt.swift
//  StarkNetKit
//
//  StarkNet Field Element - 251-bit prime field element
//  Prime: P = 2^251 + 17 * 2^192 + 1
//

import BigInt
import Foundation
import MultiChainCore

// MARK: - Felt

public struct Felt: ChainValue, Sendable {

  // MARK: - Constants

  /// StarkNet prime: 2^251 + 17 * 2^192 + 1
  public static let PRIME: BigUInt = BigUInt("800000000000011000000000000000000000000000000000000000000000001", radix: 16)!

  // MARK: - Properties

  private let value: BigUInt

  // MARK: - Init

  public init(_ value: BigUInt) {
    self.value = value % Felt.PRIME
  }

  public init(_ int: UInt64) {
    self.init(BigUInt(int))
  }

  public init?(_ hex: String) {
    var lowercasedHex = hex.lowercased()
    if lowercasedHex.starts(with: "0x") {
      lowercasedHex = String(lowercasedHex.dropFirst(2))
    }
    guard !lowercasedHex.isEmpty, let bigInt = BigUInt(lowercasedHex, radix: 16) else {
      return nil
    }
    self.init(bigInt)
  }

  public init(_ data: Data) {
    let value = BigUInt(data)
    self.init(value)
  }

  // MARK: - Static Properties

  public static var zero: Felt {
    return Felt(UInt64(0))
  }

  public static var one: Felt {
    return Felt(UInt64(1))
  }

  // MARK: - ChainValue Protocol

  public var hexString: String { "0x" + String(value, radix: 16) }

  public var description: String { String(value) }

  // MARK: - Data Conversion

  /// Returns 32-byte big-endian representation
  public var bigEndianData: Data { 
    let data = value.serialize()
    if data.count < 32 {
      return Data(repeating: 0, count: 32 - data.count) + data
    }
    return data
  }

  // MARK: - Arithmetic

  public static func + (lhs: Felt, rhs: Felt) -> Felt {
    Felt(lhs.value + rhs.value)
  }

  public static func - (lhs: Felt, rhs: Felt) -> Felt {
    Felt((lhs.value + Felt.PRIME - rhs.value) % Felt.PRIME)
  }

  public static func * (lhs: Felt, rhs: Felt) -> Felt {
    Felt(lhs.value * rhs.value)
  }

  public static func / (lhs: Felt, rhs: Felt) -> Felt {
    precondition(rhs.value != 0, "Division by zero")
    return rhs.inverse()! * lhs
  }

  // MARK: - Modular Inverse

  /// Returns the modular multiplicative inverse, or nil if self is zero
  public func inverse() -> Felt? {
    guard value != 0 else { return nil }
    let exp = Felt.PRIME - 2
    let inv = value.power(exp, modulus: Felt.PRIME)
    return Felt(inv)
  }

  // MARK: - Power

  /// Compute self^exponent mod PRIME
  public func pow(_ exponent: UInt64) -> Felt {
    Felt(self.value.power(BigUInt(exponent), modulus: Felt.PRIME))
  }

  /// Compute self^exponent mod PRIME (BigUInt exponent)
  public func pow(_ exponent: BigUInt) -> Felt {
    Felt(self.value.power(exponent, modulus: Felt.PRIME))
  }

  // MARK: - Bit Operations

  /// Number of bits needed to represent this value
  public var bitLength: Int {
    self.value.bitWidth
  }

  // MARK: - Comparable

  public static func < (lhs: Felt, rhs: Felt) -> Bool {
    lhs.value < rhs.value
  }

  // MARK: - Hashable

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.value)
  }

  // MARK: - ExpressibleByIntegerLiteral

  public init(integerLiteral value: UInt64) {
    self.init(value)
  }

  // MARK: - Codable

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let hex = try container.decode(String.self)
    guard let val = Felt(hex) else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid hex")
    }
    self = val
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(hexString)
  }
}

// MARK: - Equatable

extension Felt: Equatable {
  public static func == (lhs: Felt, rhs: Felt) -> Bool {
    lhs.value == rhs.value
  }
}
