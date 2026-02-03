//
//  EthereumAddress.swift
//  EthereumKit
//

import CryptoSwift
import Foundation
import MultiChainCore

/// Ethereum 20-byte address with EIP-55 checksum support.
public struct EthereumAddress: ChainAddress, Sendable {
  public let data: Data

  public init(_ data: Data) {
    assert(data.count <= 20, "Ethereum address must be 20 bytes, got \(data.count)")
    if data.count >= 20 {
      self.data = data.prefix(20)
    } else {
      var padded = Data(repeating: 0, count: 20 - data.count)
      padded.append(data)
      self.data = padded
    }
  }

  public init?(_ string: String) {
    var hex = string
    if hex.hasPrefix("0x") || hex.hasPrefix("0X") { hex = String(hex.dropFirst(2)) }
    guard hex.count == 40 else { return nil }

    var bytes = Data()
    var index = hex.startIndex
    while index < hex.endIndex {
      let nextIndex = hex.index(index, offsetBy: 2)
      guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
      bytes.append(byte)
      index = nextIndex
    }
    self.data = bytes
  }

  public static var zero: EthereumAddress {
    EthereumAddress(Data(repeating: 0, count: 20))
  }

  // MARK: - EIP-55 Checksum

  public var checksummed: String {
    let hex = data.map { String(format: "%02x", $0) }.joined()
    let hash = hex.bytes.sha3(.keccak256)

    var result = "0x"
    for (i, char) in hex.enumerated() {
      if char >= "0" && char <= "9" {
        result.append(char)
      } else {
        let hashByte = hash[i / 2]
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
    guard let address = EthereumAddress(string) else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid address")
    }
    self = address
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(checksummed)
  }
}
