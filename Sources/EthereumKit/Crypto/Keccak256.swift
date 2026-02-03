//
//  Keccak256.swift
//  EthereumKit
//

import CryptoSwift
import Foundation

public enum Keccak256 {
  public static func hash(_ data: Data) -> Data {
    data.sha3(.keccak256)
  }

  public static func hash(_ string: String) -> Data {
    hash(string.data(using: .utf8) ?? Data())
  }
}
