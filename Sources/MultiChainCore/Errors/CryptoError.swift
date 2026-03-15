//
//  CryptoError.swift
//  MultiChainCore
//

import Foundation

public enum CryptoError: Error, Sendable, Equatable, CustomStringConvertible {
  // Key management (was SignerError)
  case invalidPrivateKey
  case invalidMnemonic
  case invalidPath(String)
  case signingFailed(String)
  case publicKeyDerivationFailed

  // BIP39 (was BIP39Error)
  case invalidEntropySize(Int)
  case entropyGenerationFailed
  case invalidChecksumLength
  case checksumMismatch
  case seedGenerationFailed

  // BIP32 (was BIP32Error)
  case invalidSeedLength
  case derivationFailed
  case invalidPublicKey

  public var description: String {
    switch self {
    case .invalidPrivateKey: return "Invalid private key"
    case .invalidMnemonic: return "Invalid mnemonic"
    case .invalidPath(let path): return "Invalid path: \(path)"
    case .signingFailed(let reason): return "Signing failed: \(reason)"
    case .publicKeyDerivationFailed: return "Public key derivation failed"
    case .invalidEntropySize(let n): return "Invalid entropy size: \(n)"
    case .entropyGenerationFailed: return "Entropy generation failed"
    case .invalidChecksumLength: return "Invalid checksum length"
    case .checksumMismatch: return "Checksum mismatch"
    case .seedGenerationFailed: return "Seed generation failed"
    case .invalidSeedLength: return "Invalid seed length"
    case .derivationFailed: return "Derivation failed"
    case .invalidPublicKey: return "Invalid public key"
    }
  }
}
