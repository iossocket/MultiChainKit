//
//  AccountSigningTests.swift
//  EthereumKitTests
//

import MultiChainCore
import XCTest

@testable import EthereumKit

final class EthereumAccountSigningTests: XCTestCase {

  // Anvil default private key for account 0
  let privateKey = Data(hex: "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")
  let expectedAddress = EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!

  // MARK: - Initialization

  func testInitFromPrivateKey() throws {
    let account = try EthereumAccount(privateKey: privateKey)

    XCTAssertEqual(account.address, expectedAddress)
  }

  func testInitFromMnemonic() throws {
    let mnemonic = "test test test test test test test test test test test junk"
    let account = try EthereumAccount(mnemonic: mnemonic, path: .ethereum)

    // First account from this mnemonic
    XCTAssertNotNil(account.address)
    XCTAssertNotNil(account.publicKey)
  }

  func testInitWithInvalidPrivateKeyThrows() {
    let invalidKey = Data(repeating: 0, count: 32)

    XCTAssertThrowsError(try EthereumAccount(privateKey: invalidKey)) { error in
      XCTAssertTrue(error is SignerError)
    }
  }

  // MARK: - Signer Protocol

  func testSignHash() throws {
    let account = try EthereumAccount(privateKey: privateKey)
    let hash = Keccak256.hash("test message".data(using: .utf8)!)

    let signature = try account.sign(hash: hash)

    XCTAssertEqual(signature.r.count, 32)
    XCTAssertEqual(signature.s.count, 32)
    XCTAssertTrue(signature.v == 27 || signature.v == 28)
  }

  // MARK: - Message Signing (EIP-191)

  func testSignMessage() throws {
    let account = try EthereumAccount(privateKey: privateKey)
    let message = "Hello, Ethereum!"

    let signature = try account.signMessage(message)

    XCTAssertNotNil(signature)
    // Verify signature can recover to same address
    let recovered = try account.recoverMessageSigner(message: message, signature: signature)
    XCTAssertEqual(recovered, account.address)
  }

  func testSignMessageData() throws {
    let account = try EthereumAccount(privateKey: privateKey)
    let messageData = "Hello, Ethereum!".data(using: .utf8)!

    let signature = try account.signMessage(messageData)

    XCTAssertNotNil(signature)
  }

  // MARK: - Transaction Signing

  func testSignTransaction() throws {
    let account = try EthereumAccount(privateKey: privateKey)
    let toAddress = EthereumAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")!

    var tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(1),
      maxFeePerGas: Wei.fromGwei(20),
      gasLimit: 21000,
      to: toAddress,
      value: Wei.fromEther(1),
      data: Data()
    )

    try account.sign(transaction: &tx)

    XCTAssertNotNil(tx.signature)
    XCTAssertNotNil(tx.rawTransaction)
  }

  func testSignedTransactionRecoversSender() throws {
    let account = try EthereumAccount(privateKey: privateKey)
    let toAddress = EthereumAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")!

    var tx = EthereumTransaction(
      chainId: 1,
      nonce: 5,
      maxPriorityFeePerGas: Wei.fromGwei(2),
      maxFeePerGas: Wei.fromGwei(30),
      gasLimit: 21000,
      to: toAddress,
      value: Wei.fromEther(1),
      data: Data()
    )

    try account.sign(transaction: &tx)

    let recovered = try tx.recoverSender()
    XCTAssertEqual(recovered, account.address)
  }

  // MARK: - Transfer Helper

  func testCreateAndSignTransferTransaction() throws {
    let account = try EthereumAccount(privateKey: privateKey)
    let toAddress = EthereumAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")!

    var tx = EthereumTransaction(
      chainId: 1,
      nonce: 0,
      maxPriorityFeePerGas: Wei.fromGwei(1),
      maxFeePerGas: Wei.fromGwei(20),
      gasLimit: 21000,
      to: toAddress,
      value: Wei.fromEther(1),
      data: Data()
    )

    try account.sign(transaction: &tx)

    XCTAssertNotNil(tx.signature)
    XCTAssertNotNil(tx.rawTransaction)
    XCTAssertEqual(tx.to, toAddress)
    XCTAssertEqual(tx.gasLimit, 21000)
  }

  // MARK: - Protocol Conformance

  func testConformsToAccountProtocol() throws {
    let account = try EthereumAccount(privateKey: privateKey)
    func acceptAccount<A: Account>(_ a: A) where A.C == EvmChain {}
    acceptAccount(account)
  }

  func testProviderIsNilByDefault() throws {
    let account = try EthereumAccount(privateKey: privateKey)
    XCTAssertNil(account.provider)
  }

  func testInvalidMnemonicThrows() {
    XCTAssertThrowsError(try EthereumAccount(mnemonic: "not a valid mnemonic", path: .ethereum)) { error in
      XCTAssertTrue(error is SignerError)
    }
  }
}

// MARK: - Anvil Integration Tests

final class AccountSigningAnvilTests: XCTestCase {

  lazy var provider = EthereumProvider(
    chainId: 31337,
    name: "Anvil",
    url: URL(string: "http://127.0.0.1:8545")!,
    isTestnet: true
  )

  let privateKey = Data(hex: "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")
  let toAddress = EthereumAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")!

  override func setUpWithError() throws {
    try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil, "Skip on CI")
  }

  func testSignAndSendTransaction() async throws {
    let account = try EthereumAccount(privateKey: privateKey)

    // 1. Get nonce
    let nonceHex: String = try await provider.send(
      request: EthereumRequestBuilder.getTransactionCountRequest(address: account.address, block: .pending)
    )
    let nonce = UInt64(nonceHex.dropFirst(2), radix: 16) ?? 0

    // 2. Get gas price
    let gasPriceHex: String = try await provider.send(request: EthereumRequestBuilder.gasPriceRequest())
    let gasPrice = Wei(gasPriceHex) ?? .zero

    // 3. Create and sign transaction
    var tx = EthereumTransaction(
      chainId: 31337,
      nonce: nonce,
      maxPriorityFeePerGas: gasPrice,
      maxFeePerGas: gasPrice * 2,
      gasLimit: 21000,
      to: toAddress,
      value: Wei.fromEther(1),
      data: Data()
    )

    try account.sign(transaction: &tx)

    // 4. Send
    guard let rawTx = tx.rawTransaction else {
      XCTFail("Failed to encode transaction")
      return
    }

    let txHash: String = try await provider.send(
      request: EthereumRequestBuilder.sendRawTransactionRequest(rawTx)
    )
    XCTAssertTrue(txHash.hasPrefix("0x"))

    // 5. Wait and verify receipt
    try await Task.sleep(nanoseconds: 1_000_000_000)

    let receipt: EthereumReceipt = try await provider.send(
      request: EthereumRequestBuilder.transactionReceiptRequest(hash: txHash)
    )
    XCTAssertTrue(receipt.isSuccess)
  }
}
