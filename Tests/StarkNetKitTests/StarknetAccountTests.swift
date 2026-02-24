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

// MARK: - StarknetAccount (control existing accounts)

@Suite("StarknetAccount")
struct StarknetAccountTests {

  let privateKey = Felt("0x1234567890abcdef1234567890abcdef")!

  func makeSigner() throws -> StarknetSigner {
    try StarknetSigner(privateKey: privateKey)
  }

  func makeAccount() throws -> StarknetAccount {
    StarknetAccount(
      signer: try makeSigner(),
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
    let pubKey = account.signer.publicKeyFelt!
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
    let signer = try makeSigner()
    let account = StarknetAccount(
      signer: signer, address: StarknetAddress("0xabc")!, chain: .sepolia)

    let tx = StarknetDeployAccountV1(
      classHash: Felt(0x111), contractAddressSalt: Felt(0x222),
      constructorCalldata: [Felt(0x333)], maxFee: Felt(500),
      nonce: .zero, chainId: account.chain.chainId
    )
    let signed = try account.signDeployAccountV1(tx)

    #expect(signed.signature.count == 2)
    let hash = try tx.transactionHash()
    let valid = try StarkCurve.verify(
      publicKey: signer.publicKeyFelt!, hash: hash,
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
    } catch let error as StarknetAccountError {
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
    } catch let error as StarknetAccountError {
      #expect(error == .noProvider)
    }
  }

  @Test("account with provider does not throw noProvider")
  func accountWithProvider() throws {
    let signer = try makeSigner()
    let account = StarknetAccount(
      signer: signer,
      address: StarknetAddress("0xabc")!,
      chain: .sepolia,
      provider: StarknetProvider(chain: .sepolia)
    )
    #expect(account.provider != nil)
  }

  // MARK: - SignableAccount conformance

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
      publicKey: account.signer.publicKeyFelt!, hash: hash,
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
      publicKey: account.signer.publicKeyFelt!,
      hash: Felt(message),
      r: sig.r, s: sig.s
    )
    #expect(valid)
  }

  @Test("balanceRequest returns starknet_call for STRK ERC20")
  func balanceRequestMethod() throws {
    let account = try makeAccount()
    let request = account.balanceRequest()
    #expect(request.method == "starknet_call")
  }

  @Test("sendTransactionRequest returns correct method for InvokeV3")
  func sendTxRequestInvokeV3() throws {
    let account = try makeAccount()
    let call = StarknetCall(contractAddress: Felt(0x1), entryPointSelector: Felt(0x2), calldata: [])
    let inner = account.buildInvokeV3(calls: [call], resourceBounds: .zero, nonce: Felt(0))
    var tx = StarknetTransaction.invokeV3(inner)
    try account.sign(transaction: &tx)

    let request = account.sendTransactionRequest(tx)
    #expect(request.method == "starknet_addInvokeTransaction")
  }

  @Test("sendTransactionRequest returns correct method for DeployAccountV1")
  func sendTxRequestDeployV1() throws {
    let account = try makeAccount()
    let inner = StarknetDeployAccountV1(
      classHash: Felt(0x111), contractAddressSalt: Felt(0x222),
      constructorCalldata: [Felt(0x333)], maxFee: Felt(500),
      nonce: .zero, chainId: account.chain.chainId
    )
    var tx = StarknetTransaction.deployAccountV1(inner)
    try account.sign(transaction: &tx)

    let request = account.sendTransactionRequest(tx)
    #expect(request.method == "starknet_addDeployAccountTransaction")
  }

  @Test("conforms to SignableAccount protocol")
  func conformsToSignableAccount() throws {
    let account = try makeAccount()
    func acceptSignable<A: SignableAccount>(_ a: A) where A.C == Starknet {}
    acceptSignable(account)
  }
}

// MARK: - StarknetAccountError

@Suite("StarknetAccountError")
struct StarknetAccountErrorTests {

  @Test("error cases are equatable")
  func equatable() {
    #expect(StarknetAccountError.noProvider == .noProvider)
    #expect(StarknetAccountError.emptyFeeEstimate == .emptyFeeEstimate)
    #expect(StarknetAccountError.noProvider != .emptyFeeEstimate)
  }
}
