//
//  MultiChainKit.swift
//  MultiChainKit
//
//  Unified entry point: one mnemonic, multiple chains.
//

@_exported import EthereumKit
@_exported import MultiChainCore
@_exported import StarknetKit

// MARK: - MultiChainWallet

/// Convenience facade that derives EVM and Starknet accounts from a single mnemonic.
public struct MultiChainWallet: Sendable {
  public private(set) var ethereum: EthereumAccount
  public private(set) var starknet: StarknetAccount

  private let mnemonic: String
  private let ethereumPath: DerivationPath
  private let starknetPath: DerivationPath

  /// Create a wallet from a BIP39 mnemonic, deriving accounts for both chains.
  public init(
    mnemonic: String,
    ethereumPath: DerivationPath = .ethereum,
    starknetPath: DerivationPath = .starknet,
    starknetAccountType: some StarknetAccountType = OpenZeppelinAccount(),
    starknetChain: Starknet = .sepolia
  ) throws {
    self.mnemonic = mnemonic
    self.ethereumPath = ethereumPath
    self.starknetPath = starknetPath

    // Ethereum: mnemonic → account
    self.ethereum = try EthereumAccount(mnemonic: mnemonic, path: ethereumPath)

    // Starknet: mnemonic → derive key → compute address → account
    let seed = try BIP39.seed(from: mnemonic, password: "")
    let starkPrivateKey = try StarknetKeyDerivation.derivePrivateKey(seed: seed, path: starknetPath)
    guard let pubKey = try? StarkCurve.getPublicKey(privateKey: starkPrivateKey) else {
      throw SignerError.publicKeyDerivationFailed
    }
    let address = try starknetAccountType.computeAddress(publicKey: pubKey, salt: pubKey)
    self.starknet = try StarknetAccount(
      privateKey: starkPrivateKey, address: address, chain: starknetChain)
  }

  public mutating func connectEthereum(provider: EthereumProvider) throws {
    self.ethereum = try EthereumAccount(mnemonic: mnemonic, path: ethereumPath, provider: provider)
  }

  public func evmAccount(provider: EthereumProvider) throws -> EthereumAccount {
    try EthereumAccount(mnemonic: mnemonic, path: ethereumPath, provider: provider)
  }

  /// Attach a Starknet provider to the wallet.
  public mutating func connectStarknet(provider: StarknetProvider) throws {
    let seed = try BIP39.seed(from: mnemonic, password: "")
    let starkPrivateKey = try StarknetKeyDerivation.derivePrivateKey(seed: seed, path: starknetPath)
    self.starknet = try StarknetAccount(
      privateKey: starkPrivateKey,
      address: starknet.address,
      chain: starknet.chain,
      provider: provider
    )
  }
}
