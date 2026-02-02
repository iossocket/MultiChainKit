//
//  Wei.swift
//  EthereumKit
//

import Foundation
import BigInt
import MultiChainCore

public struct Wei: ChainValue, Sendable {
    private let value: BigUInt

    private static let gwei = BigUInt(1_000_000_000)
    private static let ether = BigUInt(10).power(18)

    public init(_ value: BigUInt) {
        self.value = value
    }

    public init(_ int: UInt64) {
        self.value = BigUInt(int)
    }

    public init?(_ hex: String) {
        var s = hex
        if s.hasPrefix("0x") || s.hasPrefix("0X") { s = String(s.dropFirst(2)) }
        guard let v = BigUInt(s, radix: 16) else { return nil }
        self.value = v
    }

    public static var zero: Wei { Wei(BigUInt(0)) }

    public var hexString: String { "0x" + String(value, radix: 16) }

    // MARK: - Unit Conversions

    public static func fromGwei(_ v: UInt64) -> Wei { Wei(BigUInt(v) * gwei) }
    public static func fromEther(_ v: UInt64) -> Wei { Wei(BigUInt(v) * ether) }

    public func toGwei() -> UInt64 { UInt64(value / Self.gwei) }
    public func toEther() -> UInt64 { UInt64(value / Self.ether) }

    public func toGweiDecimal() -> Decimal {
        let (q, r) = value.quotientAndRemainder(dividingBy: Self.gwei)
        return (Decimal(string: String(q)) ?? 0) + (Decimal(string: String(r)) ?? 0) / (Decimal(string: String(Self.gwei)) ?? 1)
    }

    public func toEtherDecimal() -> Decimal {
        let (q, r) = value.quotientAndRemainder(dividingBy: Self.ether)
        return (Decimal(string: String(q)) ?? 0) + (Decimal(string: String(r)) ?? 0) / (Decimal(string: String(Self.ether)) ?? 1)
    }

    // MARK: - Arithmetic

    public static func + (lhs: Wei, rhs: Wei) -> Wei { Wei(lhs.value + rhs.value) }
    public static func - (lhs: Wei, rhs: Wei) -> Wei { Wei(lhs.value - rhs.value) }
    public static func * (lhs: Wei, rhs: Wei) -> Wei { Wei(lhs.value * rhs.value) }
    public static func / (lhs: Wei, rhs: Wei) -> Wei { Wei(lhs.value / rhs.value) }

    // MARK: - Comparable

    public static func < (lhs: Wei, rhs: Wei) -> Bool { lhs.value < rhs.value }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) { hasher.combine(value) }

    // MARK: - CustomStringConvertible

    public var description: String { String(value) }

    // MARK: - ExpressibleByIntegerLiteral

    public init(integerLiteral value: UInt64) { self.value = BigUInt(value) }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hex = try container.decode(String.self)
        guard let wei = Wei(hex) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid hex")
        }
        self = wei
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexString)
    }
}
