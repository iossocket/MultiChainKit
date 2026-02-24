//
//  PrivateKey.swift
//  MultiChainKit
//
//
import Foundation

public enum PrivateKeyUtils {
  public static func normalizePrivateKey(hex: String) throws -> Data {
    let cleaned =
      hex.lowercased().hasPrefix("0x")
      ? String(hex.dropFirst(2))
      : hex
    var data = Data(hex: cleaned)
    if data.count > 32 {
      throw Secp256k1Error.invalidPrivateKey
    }
    if data.count < 32 {
      let padding = Data(repeating: 0, count: 32 - data.count)
      data = padding + data
    }

    return data
  }
}
