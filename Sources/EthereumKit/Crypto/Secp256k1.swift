//
//  Secp256k1.swift
//  EthereumKit
//

import Foundation
import P256K

public enum Secp256k1Error: Error {
  case invalidPrivateKey
  case invalidPublicKey
  case signingFailed
  case recoveryFailed
}

public enum Secp256k1 {

  private static let privateKeyLength = 32
  private static let messageDigestLength = 32
  private static let uncompressedPublicKeyLength = 65
  private static let uncompressedPublicKeyPrefix: UInt8 = 0x04
  private static let compactSignatureLength = 64
  private static let ethereumSignatureLength = 65
  private static let ethereumVOffset: Int32 = 27
  private static let ethereumAddressLength = 20

  // MARK: - Public Key Derivation

  public static func publicKey(from privateKey: Data, compressed: Bool = true) throws -> Data {
    guard privateKey.count == privateKeyLength else {
      throw Secp256k1Error.invalidPrivateKey
    }

    do {
      let privKey = try P256K.Signing.PrivateKey(dataRepresentation: privateKey)
      if compressed {
        return privKey.publicKey.dataRepresentation
      } else {
        return privKey.publicKey.uncompressedRepresentation
      }
    } catch {
      throw Secp256k1Error.invalidPrivateKey
    }
  }

  // MARK: - Address Derivation

  public static func ethereumAddress(from publicKey: Data) -> EthereumAddress {
    var key = publicKey
    if key.count == uncompressedPublicKeyLength && key[0] == uncompressedPublicKeyPrefix {
      key = key.dropFirst()
    }
    let hash = Keccak256.hash(key)
    return EthereumAddress(hash.suffix(ethereumAddressLength))
  }

  public static func ethereumAddress(fromPrivateKey privateKey: Data) throws -> EthereumAddress {
    let publicKey = try self.publicKey(from: privateKey, compressed: false)
    return ethereumAddress(from: publicKey)
  }

  public static func ethereumAddressAndPublicKey(fromPrivateKey privateKey: Data) throws -> (
    EthereumAddress, Data
  ) {
    let publicKey = try self.publicKey(from: privateKey, compressed: false)
    let compressedPublicKey = try self.publicKey(from: privateKey, compressed: true)
    return (ethereumAddress(from: publicKey), compressedPublicKey)
  }

  // MARK: - Signing

  public static func sign(message: Data, privateKey: Data) throws -> Data {
    guard message.count == messageDigestLength else {
      throw Secp256k1Error.signingFailed
    }

    do {
      let privKey = try P256K.Recovery.PrivateKey(dataRepresentation: privateKey)
      let digest = SHA256Digest(Array(message))
      let signature = try privKey.signature(for: digest)

      let compact = try signature.compactRepresentation
      let v = UInt8(compact.recoveryId + ethereumVOffset)

      return compact.signature + Data([v])
    } catch {
      throw Secp256k1Error.signingFailed
    }
  }

  // MARK: - Recovery

  public static func recoverPublicKey(message: Data, signature: Data) throws -> Data {
    guard signature.count == uncompressedPublicKeyLength, message.count == messageDigestLength
    else {
      throw Secp256k1Error.recoveryFailed
    }

    let compactSig = signature.prefix(compactSignatureLength)
    var v = Int32(signature.last!)
    if v >= ethereumVOffset { v -= ethereumVOffset }

    do {
      let recoverySig = try P256K.Recovery.ECDSASignature(
        compactRepresentation: compactSig,
        recoveryId: v
      )
      let digest = SHA256Digest(Array(message))
      let publicKey = try P256K.Recovery.PublicKey(
        digest, signature: recoverySig, format: .uncompressed)
      return publicKey.dataRepresentation
    } catch {
      throw Secp256k1Error.recoveryFailed
    }
  }
}
