//
//  EthereumSignature.swift
//  EthereumKit
//

import Foundation
import MultiChainCore
import P256K

public enum EthereumSignatureError: Error {
  case invalidSignature
  case invalidInputMessage
}

public struct EthereumSignature: ChainSignature, Sendable, Equatable {
  public let r: Data
  public let s: Data
  public let v: UInt8

  // MARK: - Init

  public init(r: Data, s: Data, v: UInt8) {
    self.r = r
    self.s = s
    self.v = v
  }

  public init(data: Data) throws {
    if data.count != EthereumKitConstants.EthereumSignatureLength {
      throw EthereumSignatureError.invalidSignature
    }
    let startIndexOfR = data.startIndex
    let startIndexOfS = data.index(startIndexOfR, offsetBy: 32)
    let startIndexOfV = data.index(startIndexOfS, offsetBy: 32)
    self.r = data[startIndexOfR..<startIndexOfS]
    self.s = data[startIndexOfS..<startIndexOfV]
    self.v = UInt8(data[64])
  }

  // MARK: - ChainSignature

  public var rawData: Data {
    var raw = Data()
    raw.append(self.r)
    raw.append(self.s)
    raw.append(self.v)
    return raw
  }

  // MARK: - Recovery

  public func recoverAddress(from hash: Data) throws -> EthereumAddress {
    let pubKey = try Secp256k1.recoverPublicKey(message: hash, signature: self.rawData)
    return Secp256k1.ethereumAddress(from: pubKey)
  }
}
