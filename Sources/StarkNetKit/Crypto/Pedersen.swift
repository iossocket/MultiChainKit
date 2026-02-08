//
//  PedersenHash.swift
//  StarknetKit
//

import BigInt
import StarknetCrypto
import Foundation

public enum StarknetHashError: Error {
  case invalidElements
}

public enum Pedersen {

  /// Pedersen hash of two Felt values.
  public static func hash(_ a: Felt, _ b: Felt) throws -> Felt {
    let hashData = try PedersenHash.hash(a.littleEndianData, b.littleEndianData)
    return Felt(littleEndian: hashData)
  }

  /// Chain hash: h(h(h(0, a), b), c) then hash with length.
  /// pedersenOn([a, b, c]) = pedersen(pedersen(pedersen(pedersen(0, a), b), c), 3)
  public static func hashMany(_ elements: [Felt]) throws -> Felt {
    var result = Felt.zero.littleEndianData
    for element in elements {
      result = try PedersenHash.hash(result, element.littleEndianData)
    }
    result = try PedersenHash.hash(result, Felt(UInt64(elements.count)).littleEndianData)
    return Felt(littleEndian: result)
  }
}
