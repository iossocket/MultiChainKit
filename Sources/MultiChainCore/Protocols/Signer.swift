//
//  Signer.swift
//  MultiChainCore
//

import Foundation

// MARK: - Signer

/// Creates digital signatures using a private key.
public protocol Signer<C>: Sendable {
  associatedtype C: Chain

  var publicKey: Data { get }
  func sign(hash: Data) throws -> C.Signature
}

// MARK: - PrivateKeySigner

/// Signer initialized from raw private key bytes.
public protocol PrivateKeySigner: Signer {
  init(privateKey: Data) throws
}

// MARK: - MnemonicSigner

/// Signer that derives key from BIP39 mnemonic.
public protocol MnemonicSigner: Signer {
  init(mnemonic: String, path: DerivationPath) throws
}

// MARK: - SignerError

public enum SignerError: Error, Sendable, CustomStringConvertible {
  case invalidPrivateKey
  case invalidMnemonic
  case invalidPath(String)
  case signingFailed(String)
  case publicKeyDerivationFailed

  public var description: String {
    switch self {
    case .invalidPrivateKey: return "Invalid private key"
    case .invalidMnemonic: return "Invalid mnemonic phrase"
    case .invalidPath(let path): return "Invalid derivation path: \(path)"
    case .signingFailed(let reason): return "Signing failed: \(reason)"
    case .publicKeyDerivationFailed: return "Failed to derive public key"
    }
  }
}

// MARK: - DerivationPath

/// BIP32 HD wallet derivation path (e.g. m/44'/60'/0'/0/0).
public struct DerivationPath: Sendable, Equatable, Hashable, CustomStringConvertible {
  public let components: [UInt32]
  public static let hardenedOffset: UInt32 = 0x8000_0000

  public static let ethereum = DerivationPath(components: [
    44 + hardenedOffset,
    60 + hardenedOffset,
    0 + hardenedOffset,
    0,
    0,
  ])

  public static let starknet = DerivationPath(components: [
    44 + hardenedOffset,
    9004 + hardenedOffset,
    0 + hardenedOffset,
    0,
    0,
  ])

  public init(components: [UInt32]) {
    self.components = components
  }

  public init?(_ string: String) {
    var path = string
    guard path.hasPrefix("m/") else { return nil }
    path.removeFirst(2)

    var components: [UInt32] = []
    for part in path.split(separator: "/") {
      var partStr = String(part)
      let hardened = partStr.hasSuffix("'") || partStr.hasSuffix("h")
      if hardened { partStr.removeLast() }

      guard let index = UInt32(partStr) else { return nil }
      components.append(hardened ? index + Self.hardenedOffset : index)
    }

    self.components = components
  }

  public var description: String {
    let parts = components.map { c -> String in
      let isHardened = c >= Self.hardenedOffset
      let index = isHardened ? c - Self.hardenedOffset : c
      return isHardened ? "\(index)'" : "\(index)"
    }
    return "m/" + parts.joined(separator: "/")
  }

  public func account(_ index: UInt32) -> DerivationPath {
    guard components.count >= 5 else { return self }
    var newComponents = components
    newComponents[4] = index
    return DerivationPath(components: newComponents)
  }
}
