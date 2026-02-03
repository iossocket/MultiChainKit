//
//  BIP32.swift
//  MultiChainCore
//
//  https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
//

import BigInt
import CryptoSwift
import Foundation

// MARK: - BIP32Error

public enum BIP32Error: Error, Sendable {
  case invalidSeedLength
  case invalidPrivateKey
  case derivationFailed
  case invalidPublicKey
}

// MARK: - ExtendedKey

public struct ExtendedKey: Sendable {
  public let privateKey: Data
  public let chainCode: Data

  public init(privateKey: Data, chainCode: Data) {
    self.privateKey = privateKey
    self.chainCode = chainCode
  }
}

// MARK: - BIP32

public enum BIP32 {

  private static let curveOrder = BigUInt(
    "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141", radix: 16)!
  private static let fieldPrime = BigUInt(
    "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F", radix: 16)!
  private static let Gx = BigUInt(
    "79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798", radix: 16)!
  private static let Gy = BigUInt(
    "483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8", radix: 16)!

  // MARK: - Master Key

  public static func masterKey(seed: Data) throws -> ExtendedKey {
    guard seed.count >= 16 && seed.count <= 64 else {
      throw BIP32Error.invalidSeedLength
    }

    let hmac = HMAC(key: Array("Bitcoin seed".utf8), variant: .sha2(.sha512))
    let result = try hmac.authenticate(Array(seed))

    let privateKey = Data(result[0..<32])
    let chainCode = Data(result[32..<64])

    let keyInt = BigUInt(Data(privateKey))
    guard keyInt > 0 && keyInt < curveOrder else {
      throw BIP32Error.invalidPrivateKey
    }

    return ExtendedKey(privateKey: privateKey, chainCode: chainCode)
  }

  // MARK: - Child Derivation

  public static func deriveChild(from parent: ExtendedKey, index: UInt32, hardened: Bool) throws
    -> ExtendedKey
  {
    var data = Data()
    let childIndex = hardened ? (0x8000_0000 | index) : index

    if hardened {
      data.append(0x00)
      data.append(parent.privateKey)
    } else {
      let pubKey = try publicKey(from: parent)
      data.append(pubKey)
    }

    data.append(contentsOf: withUnsafeBytes(of: childIndex.bigEndian) { Array($0) })

    let hmac = HMAC(key: Array(parent.chainCode), variant: .sha2(.sha512))
    let result = try hmac.authenticate(Array(data))

    let il = Data(result[0..<32])
    let ir = Data(result[32..<64])

    let ilInt = BigUInt(Data(il))
    let parentKeyInt = BigUInt(Data(parent.privateKey))
    let childKeyInt = (ilInt + parentKeyInt) % curveOrder

    guard ilInt < curveOrder && childKeyInt > 0 else {
      throw BIP32Error.derivationFailed
    }

    let childKeyData = childKeyInt.serialize().padLeft(toLength: 32)
    return ExtendedKey(privateKey: childKeyData, chainCode: ir)
  }

  // MARK: - Path Derivation

  public static func derive(seed: Data, path: DerivationPath) throws -> ExtendedKey {
    var key = try masterKey(seed: seed)

    for component in path.components {
      let hardened = component >= DerivationPath.hardenedOffset
      let index = hardened ? component - DerivationPath.hardenedOffset : component
      key = try deriveChild(from: key, index: index, hardened: hardened)
    }

    return key
  }

  // MARK: - Public Key

  public static func publicKey(from key: ExtendedKey) throws -> Data {
    let privateKeyInt = BigUInt(Data(key.privateKey))

    guard privateKeyInt > 0 && privateKeyInt < curveOrder else {
      throw BIP32Error.invalidPrivateKey
    }

    let (x, y) = pointMultiply(k: privateKeyInt, px: Gx, py: Gy)

    var compressed = Data()
    compressed.append(y.isMultiple(of: 2) ? 0x02 : 0x03)
    compressed.append(x.serialize().padLeft(toLength: 32))

    return compressed
  }

  // MARK: - EC Math

  private static func pointAdd(x1: BigUInt, y1: BigUInt, x2: BigUInt, y2: BigUInt) -> (
    BigUInt, BigUInt
  ) {
    let p = fieldPrime

    if x1 == 0 && y1 == 0 { return (x2, y2) }
    if x2 == 0 && y2 == 0 { return (x1, y1) }

    let lambda: BigUInt
    if x1 == x2 && y1 == y2 {
      let numerator = (3 * x1 * x1) % p
      let denominator = (2 * y1) % p
      lambda = (numerator * modInverse(denominator, p)) % p
    } else if x1 == x2 {
      return (0, 0)
    } else {
      let dy = y2 >= y1 ? (y2 - y1) % p : p - ((y1 - y2) % p)
      let dx = x2 >= x1 ? (x2 - x1) % p : p - ((x1 - x2) % p)
      lambda = (dy * modInverse(dx, p)) % p
    }

    let lambdaSquared = (lambda * lambda) % p
    var x3 = lambdaSquared
    x3 = x3 >= x1 ? x3 - x1 : p - ((x1 - x3) % p)
    x3 = x3 % p
    x3 = x3 >= x2 ? x3 - x2 : p - ((x2 - x3) % p)
    x3 = x3 % p

    let dx1x3 = x1 >= x3 ? (x1 - x3) % p : p - ((x3 - x1) % p)
    var y3 = (lambda * dx1x3) % p
    y3 = y3 >= y1 ? (y3 - y1) % p : p - ((y1 - y3) % p)

    return (x3, y3)
  }

  private static func pointMultiply(k: BigUInt, px: BigUInt, py: BigUInt) -> (BigUInt, BigUInt) {
    var result: (BigUInt, BigUInt) = (0, 0)
    var addend = (px, py)
    var scalar = k

    while scalar > 0 {
      if scalar & 1 == 1 {
        result = pointAdd(x1: result.0, y1: result.1, x2: addend.0, y2: addend.1)
      }
      addend = pointAdd(x1: addend.0, y1: addend.1, x2: addend.0, y2: addend.1)
      scalar >>= 1
    }

    return result
  }

  private static func modInverse(_ a: BigUInt, _ p: BigUInt) -> BigUInt {
    return a.power(p - 2, modulus: p)
  }
}

// MARK: - Data Extension

extension Data {
  func padLeft(toLength length: Int, with byte: UInt8 = 0x00) -> Data {
    if count >= length { return self }
    var padded = Data(repeating: byte, count: length - count)
    padded.append(self)
    return padded
  }
}
