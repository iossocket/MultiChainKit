//
//  MultiChainWalletTests.swift
//  MultiChainKitTests
//

import Testing

@testable import MultiChainKit

// Standard test mnemonic (DO NOT use in production)
private let testMnemonic =
  "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

@Suite("MultiChainWallet")
struct MultiChainWalletTests {

  @Test("init derives both Ethereum and Starknet accounts")
  func initDerivesBothAccounts() throws {
    let wallet = try MultiChainWallet(mnemonic: testMnemonic)
    #expect(wallet.ethereum.address != .zero)
    #expect(wallet.starknet.address != .zero)
  }

  @Test("Ethereum address matches direct EthereumSignableAccount")
  func ethereumAddressMatchesDirect() throws {
    let wallet = try MultiChainWallet(mnemonic: testMnemonic)
    let direct = try EthereumSignableAccount(mnemonic: testMnemonic, path: .ethereum)
    #expect(wallet.ethereum.address == direct.address)
  }

  @Test("Starknet address is deterministic")
  func starknetAddressDeterministic() throws {
    let wallet1 = try MultiChainWallet(mnemonic: testMnemonic)
    let wallet2 = try MultiChainWallet(mnemonic: testMnemonic)
    #expect(wallet1.starknet.address == wallet2.starknet.address)
  }

  @Test("Starknet address matches manual derivation")
  func starknetAddressMatchesManual() throws {
    let wallet = try MultiChainWallet(mnemonic: testMnemonic)

    let signer = try StarknetSigner(mnemonic: testMnemonic, path: .starknet)
    let pubKey = signer.publicKeyFelt!
    let address = try OpenZeppelinAccount().computeAddress(publicKey: pubKey, salt: pubKey)

    #expect(wallet.starknet.address == address)
  }

  @Test("connectStarknet attaches provider")
  func connectStarknet() throws {
    var wallet = try MultiChainWallet(mnemonic: testMnemonic)
    let addressBefore = wallet.starknet.address
    #expect(wallet.starknet.provider == nil)

    let provider = StarknetProvider(chain: .sepolia)
    wallet.connectStarknet(provider: provider)

    #expect(wallet.starknet.provider != nil)
    #expect(wallet.starknet.address == addressBefore)
  }

  @Test("connectEthereum attaches provider")
  func connectEthereum() throws {
    var wallet = try MultiChainWallet(mnemonic: testMnemonic)
    let addressBefore = wallet.ethereum.address
    #expect(wallet.ethereum.provider == nil)

    let provider = EthereumProvider(chain: .sepolia)
    try wallet.connectEthereum(provider: provider)

    #expect(wallet.ethereum.provider != nil)
    #expect(wallet.ethereum.address == addressBefore)
  }

  @Test("different mnemonics produce different addresses")
  func differentMnemonics() throws {
    let wallet1 = try MultiChainWallet(mnemonic: testMnemonic)
    let wallet2 = try MultiChainWallet(
      mnemonic: "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong")
    #expect(wallet1.ethereum.address != wallet2.ethereum.address)
    #expect(wallet1.starknet.address != wallet2.starknet.address)
  }

  @Test("invalid mnemonic throws")
  func invalidMnemonic() {
    #expect(throws: (any Error).self) {
      _ = try MultiChainWallet(mnemonic: "not a valid mnemonic")
    }
  }
}

@Suite("StarknetKeyDerivation")
struct StarknetKeyDerivationTests {

  @Test("derivePrivateKey produces valid Felt < curveOrder")
  func derivePrivateKeyValid() throws {
    let seed = try BIP39.seed(from: testMnemonic, password: "")
    let key = try StarknetKeyDerivation.derivePrivateKey(seed: seed, path: .starknet)
    #expect(key != .zero)
    #expect(key.bigUIntValue < StarkCurve.curveOrder)
  }

  @Test("derivePrivateKey is deterministic")
  func derivePrivateKeyDeterministic() throws {
    let seed = try BIP39.seed(from: testMnemonic, password: "")
    let key1 = try StarknetKeyDerivation.derivePrivateKey(seed: seed, path: .starknet)
    let key2 = try StarknetKeyDerivation.derivePrivateKey(seed: seed, path: .starknet)
    #expect(key1 == key2)
  }

  @Test("StarknetSigner mnemonic init produces same key as manual derivation")
  func signerMnemonicMatchesManual() throws {
    let signer = try StarknetSigner(mnemonic: testMnemonic, path: .starknet)

    let seed = try BIP39.seed(from: testMnemonic, password: "")
    let key = try StarknetKeyDerivation.derivePrivateKey(seed: seed, path: .starknet)
    let manualSigner = try StarknetSigner(privateKey: key)

    #expect(signer.publicKey == manualSigner.publicKey)
  }
}
