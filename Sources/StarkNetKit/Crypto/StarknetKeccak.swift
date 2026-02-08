//
//  StarknetKeccak.swift
//  StarknetKit
//

import BigInt
import CryptoSwift
import Foundation

private let mask250 = BigUInt(2).power(250) - BigUInt(1)

public enum StarknetKeccak {

  /// sn_keccak: keccak256 of data, masked to 250 bits.
  public static func hash(_ data: Data) -> Felt {
    let hashed = Data([UInt8](data).sha3(.keccak256))
    let masked = BigUInt(hashed) & mask250
    return Felt(masked)
  }

  /// Compute StarkNet function entry point selector.
  /// Special names "__default__" and "__l1_default__" return Felt.zero.
  public static func functionSelector(_ name: String) -> Felt {
    if name == "__default__" || name == "__l1_default__" {
      return .zero
    }
    return hash(Data(name.utf8))
  }
}
