//
//  StarknetAddress.swift
//  StarknetKit
//

import BigInt
import CryptoSwift
import Foundation
import MultiChainCore

public struct StarknetAddress: ChainAddress, Sendable {
  public let data: Data

  public init(_ data: Data) {
    assert(data.count <= 32, "Starknet address must be 32 bytes, got \(data.count)")
    if data.count >= 32 {
      self.data = data.prefix(32)
    } else {
      self.data = Data(repeating: 0, count: 32 - data.count) + data
    }
  }

  public init?(_ string: String) {
    var hex = string
    if hex.hasPrefix("0x") || hex.hasPrefix("0X") { hex = String(hex.dropFirst(2)) }
    guard hex.count <= 64, !hex.isEmpty else { return nil }

    // Pad to 64 chars
    let padded = String(repeating: "0", count: 64 - hex.count) + hex

    var bytes = Data()
    var index = padded.startIndex
    while index < padded.endIndex {
      let nextIndex = padded.index(index, offsetBy: 2)
      guard let byte = UInt8(padded[index..<nextIndex], radix: 16) else { return nil }
      bytes.append(byte)
      index = nextIndex
    }
    self.data = bytes
  }

  public static var zero: StarknetAddress {
    StarknetAddress(Data(repeating: 0, count: 32))
  }

  // MARK: - Checksum (starknet.js compatible)

  // StarkNet checksum: keccak256 of the address value (big-endian bytes),
  // NOT of the hex string like Ethereum EIP-55.
  public var checksummed: String {
    // Full 64-char hex with leading zeros
    let chars = Array(data.map { String(format: "%02x", $0) }.joined())

    // keccakBn: keccak of the minimal big-endian byte representation (no leading zeros)
    let bigInt = BigUInt(data)
    let minimalBytes = bigInt.serialize()  // minimal big-endian, no leading zeros
    let hashed = Data(minimalBytes).sha3(.keccak256)

    var result = "0x"
    for (i, char) in chars.enumerated() {
      if char >= "0" && char <= "9" {
        result.append(char)
      } else {
        let hashByte = hashed[i / 2]
        let nibble = (i % 2 == 0) ? (hashByte >> 4) : (hashByte & 0x0F)
        result.append(nibble >= 8 ? char.uppercased() : char.lowercased())
      }
    }
    return result
  }

  // MARK: - CustomStringConvertible

  public var description: String { checksummed }

  // MARK: - Hashable

  public func hash(into hasher: inout Hasher) { hasher.combine(data) }

  // MARK: - Codable

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    guard let address = StarknetAddress(string) else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid address")
    }
    self = address
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(checksummed)
  }
}
