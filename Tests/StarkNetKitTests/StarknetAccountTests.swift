//
//  StarknetAccountTests.swift
//  StarknetKitTests
//
//  Tests for StarknetAccountType (deploy) and StarknetAccount (control existing accounts).
//

import BigInt
import Foundation
import MultiChainCore
import Testing

@testable import StarknetKit

// MARK: - OpenZeppelinAccount (for deploy)

@Suite("OpenZeppelinAccount")
struct OpenZeppelinAccountTests {

  @Test("Default class hash is non-zero")
  func classHash() {
    let oz = OpenZeppelinAccount()
    #expect(oz.classHash == OpenZeppelinAccount.defaultClassHash)
  }

  @Test("Custom class hash")
  func customClassHash() {
    let custom = Felt(0xabc)
    let oz = OpenZeppelinAccount(classHash: custom)
    #expect(oz.classHash == custom)
  }

  @Test("Constructor calldata is [publicKey]")
  func constructorCalldata() {
    let oz = OpenZeppelinAccount()
    let pubKey = Felt(0x12345)
    #expect(oz.constructorCalldata(publicKey: pubKey) == [pubKey])
  }

  @Test("Compute address is deterministic")
  func addressDeterministic() throws {
    let oz = OpenZeppelinAccount()
    let pubKey = Felt(0x12345)
    let salt = Felt(0x6789)
    let addr1 = try oz.computeAddress(publicKey: pubKey, salt: salt)
    let addr2 = try oz.computeAddress(publicKey: pubKey, salt: salt)
    #expect(addr1 == addr2)
  }

  @Test("Different salt gives different address")
  func differentSalt() throws {
    let oz = OpenZeppelinAccount()
    let pubKey = Felt(0x12345)
    let addr1 = try oz.computeAddress(publicKey: pubKey, salt: Felt(1))
    let addr2 = try oz.computeAddress(publicKey: pubKey, salt: Felt(2))
    #expect(addr1 != addr2)
  }

  @Test("Address matches manual contract address calculation")
  func addressMatchesManual() throws {
    let oz = OpenZeppelinAccount()
    let pubKey = Felt(0xabc)
    let salt = Felt(0xdef)
    let addr = try oz.computeAddress(publicKey: pubKey, salt: salt)

    let felt = try StarknetContractAddress.calculate(
      classHash: oz.classHash,
      calldata: [pubKey],
      salt: salt,
      deployerAddress: .zero
    )
    #expect(addr == StarknetAddress(felt.bigEndianData))
  }
}

// MARK: - ArgentAccount (for deploy)

@Suite("ArgentAccount")
struct ArgentAccountTests {

  @Test("Default class hash matches Argent v0.4.0")
  func classHash() {
    let argent = ArgentAccount()
    #expect(argent.classHash == ArgentAccount.defaultClassHash)
  }

  @Test("Custom class hash")
  func customClassHash() {
    let custom = Felt(0xabc)
    let argent = ArgentAccount(classHash: custom)
    #expect(argent.classHash == custom)
  }

  @Test("Constructor calldata is [0, publicKey, 1]")
  func constructorCalldata() {
    let argent = ArgentAccount()
    let pubKey = Felt(0x12345)
    let calldata = argent.constructorCalldata(publicKey: pubKey)
    #expect(calldata == [Felt.zero, pubKey, Felt(1)])
  }

  @Test("Compute address is deterministic")
  func addressDeterministic() throws {
    let argent = ArgentAccount()
    let pubKey = Felt(0x12345)
    let salt = pubKey
    let addr1 = try argent.computeAddress(publicKey: pubKey, salt: salt)
    let addr2 = try argent.computeAddress(publicKey: pubKey, salt: salt)
    #expect(addr1 == addr2)
  }

  @Test("Address differs from OpenZeppelin for same key")
  func addressDiffersFromOZ() throws {
    let pubKey = Felt(0x12345)
    let salt = pubKey
    let ozAddr = try OpenZeppelinAccount().computeAddress(publicKey: pubKey, salt: salt)
    let argentAddr = try ArgentAccount().computeAddress(publicKey: pubKey, salt: salt)
    #expect(ozAddr != argentAddr)
  }

  @Test("Address matches manual contract address calculation")
  func addressMatchesManual() throws {
    let argent = ArgentAccount()
    let pubKey = Felt(0xabc)
    let salt = pubKey
    let addr = try argent.computeAddress(publicKey: pubKey, salt: salt)

    let felt = try StarknetContractAddress.calculate(
      classHash: argent.classHash,
      calldata: [Felt.zero, pubKey, Felt(1)],
      salt: salt,
      deployerAddress: .zero
    )
    #expect(addr == StarknetAddress(felt.bigEndianData))
  }
}

// MARK: - StarknetAccount (control existing accounts)

@Suite("StarknetAccount")
struct StarknetAccountTests {

  let privateKey = Felt("0x1234567890abcdef1234567890abcdef")!

  func makeAccount() throws -> StarknetAccount {
    try StarknetAccount(
      privateKey: privateKey,
      address: StarknetAddress("0xabc")!,
      chain: .sepolia
    )
  }

  // MARK: - Construction

  @Test("Create account with private key + address")
  func createWithAddress() throws {
    let account = try makeAccount()
    #expect(account.address == StarknetAddress("0xabc")!)
    #expect(account.chain == .sepolia)
  }

  @Test("addressFelt matches address data")
  func addressFelt() throws {
    let account = try makeAccount()
    #expect(account.addressFelt == Felt(account.address.data))
  }

  // MARK: - Build InvokeV1

  @Test("Build InvokeV1 from calls")
  func buildInvokeV1() throws {
    let account = try makeAccount()
    let call = StarknetCall(
      contractAddress: Felt(0x1), entryPointSelector: Felt(0x2), calldata: [Felt(100)])
    let tx = account.buildInvokeV1(calls: [call], maxFee: Felt(1000), nonce: Felt(5))

    #expect(tx.senderAddress == account.addressFelt)
    #expect(tx.maxFee == Felt(1000))
    #expect(tx.nonce == Felt(5))
    #expect(tx.chainId == Felt.fromShortString("SN_SEPOLIA"))
    #expect(tx.calldata == StarknetCall.encodeMulticall([call]))
    #expect(tx.signature.isEmpty)
  }

  // MARK: - Build InvokeV3

  @Test("Build InvokeV3 from calls")
  func buildInvokeV3() throws {
    let account = try makeAccount()
    let call = StarknetCall(contractAddress: Felt(0x1), entryPointSelector: Felt(0x2), calldata: [])
    let bounds = StarknetResourceBoundsMapping(
      l1Gas: StarknetResourceBounds(maxAmount: 1000, maxPricePerUnit: BigUInt(500)),
      l2Gas: .zero,
      l1DataGas: .zero
    )
    let tx = account.buildInvokeV3(calls: [call], resourceBounds: bounds, nonce: Felt(3))

    #expect(tx.senderAddress == account.addressFelt)
    #expect(tx.nonce == Felt(3))
    #expect(tx.resourceBounds == bounds)
    #expect(tx.tip == 0)
    #expect(tx.nonceDAMode == .l1)
    #expect(tx.feeDAMode == .l1)
    #expect(tx.signature.isEmpty)
  }

  // MARK: - Sign InvokeV1

  @Test("Sign InvokeV1 attaches signature")
  func signInvokeV1() throws {
    let account = try makeAccount()
    let call = StarknetCall(contractAddress: Felt(0x1), entryPointSelector: Felt(0x2), calldata: [])
    let unsigned = account.buildInvokeV1(calls: [call], maxFee: Felt(100), nonce: Felt(0))
    let signed = try account.signInvokeV1(unsigned)

    #expect(signed.signature.count == 2)
    #expect(signed.senderAddress == unsigned.senderAddress)
    #expect(signed.calldata == unsigned.calldata)
    #expect(signed.maxFee == unsigned.maxFee)
  }

  @Test("Sign InvokeV1 signature is verifiable")
  func signInvokeV1Verifiable() throws {
    let account = try makeAccount()
    let call = StarknetCall(
      contractAddress: Felt(0x1), entryPointSelector: Felt(0x2), calldata: [Felt(42)])
    let unsigned = account.buildInvokeV1(calls: [call], maxFee: Felt(100), nonce: Felt(1))
    let signed = try account.signInvokeV1(unsigned)

    let hash = try unsigned.transactionHash()
    let pubKey = account.publicKeyFelt!
    let valid = try StarkCurve.verify(
      publicKey: pubKey, hash: hash,
      r: signed.signature[0], s: signed.signature[1]
    )
    #expect(valid)
  }

  // MARK: - Sign InvokeV3

  @Test("Sign InvokeV3 attaches signature")
  func signInvokeV3() throws {
    let account = try makeAccount()
    let call = StarknetCall(contractAddress: Felt(0x1), entryPointSelector: Felt(0x2), calldata: [])
    let bounds = StarknetResourceBoundsMapping.zero
    let unsigned = account.buildInvokeV3(calls: [call], resourceBounds: bounds, nonce: Felt(0))
    let signed = try account.signInvokeV3(unsigned)

    #expect(signed.signature.count == 2)
    #expect(signed.senderAddress == unsigned.senderAddress)
  }

  // MARK: - Sign DeployAccount

  @Test("Sign DeployAccountV1 is verifiable")
  func signDeployAccountV1() throws {
    let account = try StarknetAccount(
      privateKey: privateKey,
      address: StarknetAddress("0xabc")!,
      chain: .sepolia
    )

    let tx = StarknetDeployAccountV1(
      classHash: Felt(0x111), contractAddressSalt: Felt(0x222),
      constructorCalldata: [Felt(0x333)], maxFee: Felt(500),
      nonce: .zero, chainId: account.chain.chainId
    )
    let signed = try account.signDeployAccountV1(tx)

    #expect(signed.signature.count == 2)
    let hash = try tx.transactionHash()
    let valid = try StarkCurve.verify(
      publicKey: account.publicKeyFelt!, hash: hash,
      r: signed.signature[0], s: signed.signature[1]
    )
    #expect(valid)
  }

  @Test("Sign DeployAccountV3 attaches signature")
  func signDeployAccountV3() throws {
    let account = try makeAccount()
    let tx = StarknetDeployAccountV3(
      classHash: Felt(0x111), contractAddressSalt: Felt(0x222),
      constructorCalldata: [Felt(0x333)], resourceBounds: .zero,
      nonce: .zero, chainId: account.chain.chainId
    )
    let signed = try account.signDeployAccountV3(tx)
    #expect(signed.signature.count == 2)
  }

  // MARK: - Provider requirement

  @Test("estimateFee throws noProvider when provider is nil")
  func estimateFeeNoProvider() async throws {
    let account = try makeAccount()  // no provider
    let call = StarknetCall(
      contractAddress: Felt(0x1),
      entryPointSelector: Felt(0x2),
      calldata: []
    )
    do {
      _ = try await account.estimateFee(calls: [call], nonce: .zero)
      Issue.record("Expected noProvider error")
    } catch let error as ChainError {
      #expect(error == .noProvider)
    }
  }

  @Test("execute throws noProvider when provider is nil")
  func executeNoProvider() async throws {
    let account = try makeAccount()  // no provider
    let call = StarknetCall(
      contractAddress: Felt(0x1),
      entryPointSelector: Felt(0x2),
      calldata: []
    )
    do {
      _ = try await account.execute(calls: [call], resourceBounds: .zero, nonce: .zero)
      Issue.record("Expected noProvider error")
    } catch let error as ChainError {
      #expect(error == .noProvider)
    }
  }

  @Test("account with provider does not throw noProvider")
  func accountWithProvider() throws {
    let account = try StarknetAccount(
      privateKey: privateKey,
      address: StarknetAddress("0xabc")!,
      chain: .sepolia,
      provider: StarknetProvider(chain: .sepolia)
    )
    #expect(account.provider != nil)
  }

  // MARK: - Account conformance

  @Test("sign(transaction:) signs InvokeV3 via protocol method")
  func signTransactionInvokeV3() throws {
    let account = try makeAccount()
    let call = StarknetCall(
      contractAddress: Felt(0x1), entryPointSelector: Felt(0x2), calldata: [Felt(99)])
    let inner = account.buildInvokeV3(calls: [call], resourceBounds: .zero, nonce: Felt(0))
    var tx = StarknetTransaction.invokeV3(inner)

    #expect(tx.signature.isEmpty)
    try account.sign(transaction: &tx)
    #expect(tx.signature.count == 2)

    // Verify signature
    let hash = try tx.transactionHashFelt()
    let valid = try StarkCurve.verify(
      publicKey: account.publicKeyFelt!, hash: hash,
      r: tx.signature[0], s: tx.signature[1]
    )
    #expect(valid)
  }

  @Test("sign(transaction:) signs InvokeV1 via protocol method")
  func signTransactionInvokeV1() throws {
    let account = try makeAccount()
    let call = StarknetCall(contractAddress: Felt(0x1), entryPointSelector: Felt(0x2), calldata: [])
    let inner = account.buildInvokeV1(calls: [call], maxFee: Felt(100), nonce: Felt(0))
    var tx = StarknetTransaction.invokeV1(inner)

    try account.sign(transaction: &tx)
    #expect(tx.signature.count == 2)
  }

  @Test("sign(transaction:) signs DeployAccountV3 via protocol method")
  func signTransactionDeployV3() throws {
    let account = try makeAccount()
    let inner = StarknetDeployAccountV3(
      classHash: Felt(0x111), contractAddressSalt: Felt(0x222),
      constructorCalldata: [Felt(0x333)], resourceBounds: .zero,
      nonce: .zero, chainId: account.chain.chainId
    )
    var tx = StarknetTransaction.deployAccountV3(inner)

    try account.sign(transaction: &tx)
    #expect(tx.signature.count == 2)
  }

  @Test("signMessage signs arbitrary data")
  func signMessageData() throws {
    let account = try makeAccount()
    let message = Felt(0xdead_beef).bigEndianData
    let sig = try account.signMessage(message)

    let valid = try StarkCurve.verify(
      publicKey: account.publicKeyFelt!,
      hash: Felt(message),
      r: sig.r, s: sig.s
    )
    #expect(valid)
  }

  @Test("conforms to Account protocol")
  func conformsToAccount() throws {
    let account = try makeAccount()
    func acceptAccount<A: Account>(_ a: A) where A.C == Starknet {}
    acceptAccount(account)
  }

  @Test("zero private key throws")
  func zeroPrivateKeyThrows() {
    #expect(throws: StarkCurveError.self) {
      try StarknetAccount(privateKey: Felt.zero, address: StarknetAddress("0xabc")!, chain: .sepolia)
    }
  }

  @Test("provider is nil by default")
  func providerNilByDefault() throws {
    let account = try makeAccount()
    #expect(account.provider == nil)
  }

  // MARK: - Init with accountType

  @Test("init with accountType derives address from private key")
  func initWithAccountType() throws {
    let pk = Felt("0x0229d44730456bc33d23f18e19c8ae04bcb08e5630eb0411cabc70c8f4b517a8")!
    let expectedPubKey = Felt("0x07e2b833a71338a56edfdbaf2a32aa5e9fae3fe16a79eec8e3fdd8dc02a1b977")!
    let expectedAddress = StarknetAddress(
      "0x013b8272E85850C5AE61012089001391161651ae6f523B0Eeeb89f2F21aDfbee")!

    let account = try StarknetAccount(
      privateKey: pk, accountType: ArgentAccount(), chain: .mainnet)

    #expect(account.publicKeyFelt == expectedPubKey)
    #expect(account.address == expectedAddress)
  }

  @Test("init with accountType defaults to OpenZeppelin")
  func initWithAccountTypeDefaultOZ() throws {
    let pk = Felt("0x0229d44730456bc33d23f18e19c8ae04bcb08e5630eb0411cabc70c8f4b517a8")!
    let pubKey = Felt("0x07e2b833a71338a56edfdbaf2a32aa5e9fae3fe16a79eec8e3fdd8dc02a1b977")!

    let account = try StarknetAccount(privateKey: pk, chain: .mainnet)
    let expectedAddr = try OpenZeppelinAccount().computeAddress(publicKey: pubKey, salt: pubKey)

    #expect(account.address == expectedAddr)
  }

  @Test("init with accountType: Argent vs OZ produce different addresses")
  func initArgentVsOZDifferentAddress() throws {
    let pk = Felt("0x0229d44730456bc33d23f18e19c8ae04bcb08e5630eb0411cabc70c8f4b517a8")!

    let ozAccount = try StarknetAccount(privateKey: pk, chain: .mainnet)
    let argentAccount = try StarknetAccount(
      privateKey: pk, accountType: ArgentAccount(), chain: .mainnet)

    #expect(ozAccount.address != argentAccount.address)
  }

  // MARK: - Init with mnemonic

  @Test("mnemonic init matches manual key derivation")
  func mnemonicInitMatchesManual() throws {
    let mnemonic =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    let seed = try BIP39.seed(from: mnemonic, password: "")
    let key = try StarknetKeyDerivation.derivePrivateKey(seed: seed, path: .starknet)
    let pubKey = try StarkCurve.getPublicKey(privateKey: key)
    let address = try OpenZeppelinAccount().computeAddress(
      publicKey: pubKey, salt: pubKey)

    let account = try StarknetAccount(
      mnemonic: mnemonic, path: .starknet, address: address, chain: .sepolia)

    #expect(account.publicKeyFelt == pubKey)
    #expect(account.address == address)
  }

  @Test("mnemonic init produces same address as accountType init")
  func mnemonicMatchesAccountTypeInit() throws {
    let mnemonic =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    let seed = try BIP39.seed(from: mnemonic, password: "")
    let key = try StarknetKeyDerivation.derivePrivateKey(seed: seed, path: .starknet)

    // accountType init derives address automatically
    let autoAccount = try StarknetAccount(privateKey: key, chain: .sepolia)

    // mnemonic init with manually computed address
    let pubKey = try StarkCurve.getPublicKey(privateKey: key)
    let address = try OpenZeppelinAccount().computeAddress(
      publicKey: pubKey, salt: pubKey)
    let mnemonicAccount = try StarknetAccount(
      mnemonic: mnemonic, path: .starknet, address: address, chain: .sepolia)

    #expect(autoAccount.address == mnemonicAccount.address)
    #expect(autoAccount.publicKey == mnemonicAccount.publicKey)
  }

  @Test("mnemonic init with invalid mnemonic throws")
  func mnemonicInitInvalidThrows() {
    #expect(throws: CryptoError.self) {
      try StarknetAccount(
        mnemonic: "not a valid mnemonic",
        path: .starknet,
        address: StarknetAddress("0xabc")!,
        chain: .sepolia)
    }
  }

  @Test("mnemonic init can sign and verify")
  func mnemonicInitCanSign() throws {
    let mnemonic =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    let seed = try BIP39.seed(from: mnemonic, password: "")
    let key = try StarknetKeyDerivation.derivePrivateKey(seed: seed, path: .starknet)
    let pubKey = try StarkCurve.getPublicKey(privateKey: key)
    let address = try OpenZeppelinAccount().computeAddress(
      publicKey: pubKey, salt: pubKey)

    let account = try StarknetAccount(
      mnemonic: mnemonic, path: .starknet, address: address, chain: .sepolia)

    let hash = Felt(0xdead_beef)
    let sig = try account.sign(feltHash: hash)
    let valid = try StarkCurve.verify(
      publicKey: account.publicKeyFelt!, hash: hash, r: sig.r, s: sig.s)
    #expect(valid)
  }
}