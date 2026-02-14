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

/// Convenience facade that derives Ethereum and Starknet accounts from a single mnemonic.
public struct MultiChainWallet: Sendable {
  public private(set) var ethereum: EthereumSignableAccount
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

    // Ethereum: mnemonic → signer → account
    self.ethereum = try EthereumSignableAccount(mnemonic: mnemonic, path: ethereumPath)

    // Starknet: mnemonic → signer → compute address → account
    let signer = try StarknetSigner(mnemonic: mnemonic, path: starknetPath)
    guard let pubKey = signer.publicKeyFelt else {
      throw SignerError.publicKeyDerivationFailed
    }
    let address = try starknetAccountType.computeAddress(publicKey: pubKey, salt: pubKey)
    self.starknet = StarknetAccount(signer: signer, address: address, chain: starknetChain)
  }

  /// Attach an Ethereum provider to the wallet.
  public mutating func connectEthereum(provider: EthereumProvider) throws {
    self.ethereum = try EthereumSignableAccount(
      mnemonic: mnemonic, path: ethereumPath, provider: provider)
  }

  /// Attach a Starknet provider to the wallet.
  public mutating func connectStarknet(provider: StarknetProvider) {
    self.starknet = StarknetAccount(
      signer: starknet.signer,
      address: starknet.address,
      chain: starknet.chain,
      provider: provider
    )
  }
}
