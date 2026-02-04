//
//  EthereumTransaction+Signing.swift
//  EthereumKit
//

import Foundation

extension EthereumTransaction {

  // MARK: - Sign

  public mutating func sign(with signer: EthereumSigner) throws {
    signature = try signer.sign(hash: hashForSigning())
  }

  // MARK: - Recover Sender

  public func recoverSender() throws -> EthereumAddress {
    guard let signature else {
      throw EthereumSignatureError.invalidSignature
    }
    return try signature.recoverAddress(from: hashForSigning())
  }

  // MARK: - Verify Signature

  public func verifySignature() throws -> Bool {
    _ = try recoverSender()
    return true
  }

  // MARK: - Raw Transaction

  public var rawTransaction: String? {
    guard signature != nil else {
      return nil
    }
    return "0x" + encode().toHexString()
  }
}
