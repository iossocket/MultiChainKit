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
  /// For empty input the sponge absorbs nothing, pads with 1, and permutes:
  /// hades([1,0,0])[0] = 0x2272be0f580fd156823304800919530eaa97430e972d7213ee13f4fbf7a5dbc
  public static func hashMany(_ elements: [Felt]) throws -> Felt {
    if elements.isEmpty {
      return Felt("0x2272be0f580fd156823304800919530eaa97430e972d7213ee13f4fbf7a5dbc")!
    }
    let dataList = elements.map { $0.littleEndianData }
    let result = try PoseidonHash.hash(dataList)
    return Felt(littleEndian: result)
  }
}
