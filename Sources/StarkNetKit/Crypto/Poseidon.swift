//
//  PoseidonHash.swift
//  StarknetKit
//

import BigInt
import Foundation
import StarknetCrypto

public enum Poseidon {

  /// Poseidon hash of a single Felt value (direct Hades: state=[value, 0, 1]).
  public static func hash(_ value: Felt) throws -> Felt {
    let result = try PoseidonHash.hashSingle(value.littleEndianData)
    return Felt(littleEndian: result)
  }

  /// Poseidon hash of two Felt values (direct Hades: state=[a, b, 2]).
  public static func hash(_ a: Felt, _ b: Felt) throws -> Felt {
    let result = try PoseidonHash.hashDirect(a.littleEndianData, b.littleEndianData)
    return Felt(littleEndian: result)
  }

  /// Poseidon hash of an array of Felt values (sponge construction).
  /// Empty input is equivalent to hashMany([0]) per sponge padding rules.
  public static func hashMany(_ elements: [Felt]) throws -> Felt {
    let input = elements.isEmpty ? [Felt.zero] : elements
    let dataList = input.map { $0.littleEndianData }
    let result = try PoseidonHash.hash(dataList)
    return Felt(littleEndian: result)
  }
}
