//
//  RLP.swift
//  EthereumKit
//
//  Recursive Length Prefix encoding/decoding
//  https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp/
//

import Foundation

// MARK: - RLPError

public enum RLPError: Error {
  case emptyInput
  case invalidFormat
  case truncatedData
  case invalidLength
}

// MARK: - RLPItem

public enum RLPItem {
  case data(Data)
  case list([RLPItem])

  public var data: Data? {
    if case .data(let d) = self { return d }
    return nil
  }

  public var list: [RLPItem]? {
    if case .list(let l) = self { return l }
    return nil
  }
}

// MARK: - RLP

public enum RLP {

  // MARK: - Encode Data

  public static func encode(_ data: Data) -> Data {
    if data.count == 1 && data[0] < 0x80 {
      return data
    }
    return encodeLength(data.count, offset: 0x80) + data
  }

  // MARK: - Encode String

  public static func encode(_ string: String) -> Data {
    encode(Data(string.utf8))
  }

  // MARK: - Encode Integer

  public static func encode(_ value: UInt64) -> Data {
    if value == 0 {
      return Data([0x80])
    }
    return encode(bigInt: value.bigEndianData)
  }

  // MARK: - Encode BigInt (as Data, strips leading zeros)

  public static func encode(bigInt data: Data) -> Data {
    let stripped = data.dropLeadingZeros()
    if stripped.isEmpty {
      return Data([0x80])
    }
    return encode(stripped)
  }

  // MARK: - Encode List

  public static func encode(list items: [Data]) -> Data {
    let payload = items.reduce(Data()) { $0 + $1 }
    return encodeLength(payload.count, offset: 0xc0) + payload
  }

  // MARK: - Decode

  public static func decode(_ data: Data) throws -> RLPItem {
    guard !data.isEmpty else {
      throw RLPError.emptyInput
    }
    let (item, _) = try decodeItem(data, offset: 0)
    return item
  }

  // MARK: - Private Encode Helpers

  private static func encodeLength(_ length: Int, offset: UInt8) -> Data {
    if length < 56 {
      return Data([offset + UInt8(length)])
    }
    let lengthBytes = length.bigEndianData.dropLeadingZeros()
    return Data([offset + 55 + UInt8(lengthBytes.count)]) + lengthBytes
  }

  // MARK: - Private Decode Helpers

  private static func decodeItem(_ data: Data, offset: Int) throws -> (RLPItem, Int) {
    guard offset < data.count else {
      throw RLPError.truncatedData
    }

    let prefix = data[offset]

    if prefix < 0x80 {
      // Single byte
      return (.data(Data([prefix])), offset + 1)
    } else if prefix <= 0xb7 {
      // Short string (0-55 bytes)
      let length = Int(prefix - 0x80)
      let end = offset + 1 + length
      guard end <= data.count else {
        throw RLPError.truncatedData
      }
      let content = length == 0 ? Data() : Data(data[(offset + 1)..<end])
      return (.data(content), end)
    } else if prefix <= 0xbf {
      // Long string (>55 bytes)
      let lengthOfLength = Int(prefix - 0xb7)
      guard offset + 1 + lengthOfLength <= data.count else {
        throw RLPError.truncatedData
      }
      let length = try decodeLength(data, offset: offset + 1, lengthOfLength: lengthOfLength)
      let end = offset + 1 + lengthOfLength + length
      guard end <= data.count else {
        throw RLPError.truncatedData
      }
      let content = Data(data[(offset + 1 + lengthOfLength)..<end])
      return (.data(content), end)
    } else if prefix <= 0xf7 {
      // Short list (0-55 bytes payload)
      let length = Int(prefix - 0xc0)
      let end = offset + 1 + length
      guard end <= data.count else {
        throw RLPError.truncatedData
      }
      let items = try decodeList(data, start: offset + 1, end: end)
      return (.list(items), end)
    } else {
      // Long list (>55 bytes payload)
      let lengthOfLength = Int(prefix - 0xf7)
      guard offset + 1 + lengthOfLength <= data.count else {
        throw RLPError.truncatedData
      }
      let length = try decodeLength(data, offset: offset + 1, lengthOfLength: lengthOfLength)
      let end = offset + 1 + lengthOfLength + length
      guard end <= data.count else {
        throw RLPError.truncatedData
      }
      let items = try decodeList(data, start: offset + 1 + lengthOfLength, end: end)
      return (.list(items), end)
    }
  }

  private static func decodeLength(_ data: Data, offset: Int, lengthOfLength: Int) throws -> Int {
    guard offset + lengthOfLength <= data.count else {
      throw RLPError.truncatedData
    }
    var length = 0
    for i in 0..<lengthOfLength {
      length = length << 8 | Int(data[offset + i])
    }
    return length
  }

  private static func decodeList(_ data: Data, start: Int, end: Int) throws -> [RLPItem] {
    var items: [RLPItem] = []
    var offset = start
    while offset < end {
      let (item, newOffset) = try decodeItem(data, offset: offset)
      items.append(item)
      offset = newOffset
    }
    return items
  }
}

// MARK: - Data Extensions

extension Data {
  fileprivate func dropLeadingZeros() -> Data {
    guard let firstNonZero = self.firstIndex(where: { $0 != 0 }) else {
      return Data()
    }
    return Data(self[firstNonZero...])
  }
}

extension UInt64 {
  fileprivate var bigEndianData: Data {
    var value = self.bigEndian
    return Data(bytes: &value, count: 8)
  }
}

extension Int {
  fileprivate var bigEndianData: Data {
    var value = self.bigEndian
    return Data(bytes: &value, count: 8)
  }
}
