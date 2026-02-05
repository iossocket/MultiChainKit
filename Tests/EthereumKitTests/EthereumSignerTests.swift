//
//  EthereumSignerTests.swift
//  EthereumKitTests
//

import MultiChainCore
import XCTest

@testable import EthereumKit

final class EthereumSignerTests: XCTestCase {

  // MARK: - Test Data

  let testPrivateKey = Data(
    hex: "4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318")!
  let testAddress = "0x2c7536E3605D9C16a7a3D7b1898e529396a65c23"

  let testMnemonic =
    "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
  let ethereumPath = DerivationPath.ethereum

  // MARK: - Init from Private Key

  func testInitFromPrivateKey() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    XCTAssertNotNil(signer)
  }

  func testInitFromPrivateKeyInvalidLength() {
    let shortKey = Data(repeating: 0x01, count: 16)
    XCTAssertThrowsError(try EthereumSigner(privateKey: shortKey)) { error in
      XCTAssertTrue(error is SignerError)
    }
  }

  func testInitFromPrivateKeyAllZeros() {
    let zeroKey = Data(repeating: 0x00, count: 32)
    XCTAssertThrowsError(try EthereumSigner(privateKey: zeroKey)) { error in
      XCTAssertTrue(error is SignerError)
    }
  }

  // MARK: - Init from Mnemonic

  func testInitFromMnemonic() throws {
    let signer = try EthereumSigner(mnemonic: testMnemonic, path: ethereumPath)
    XCTAssertNotNil(signer)
  }

  func testInitFromMnemonicInvalid() {
    let invalidMnemonic = "invalid mnemonic phrase"
    XCTAssertThrowsError(try EthereumSigner(mnemonic: invalidMnemonic, path: ethereumPath)) {
      error in
      XCTAssertTrue(error is SignerError)
    }
  }

  func testInitFromMnemonicWithPassword() throws {
    let signer = try EthereumSigner(mnemonic: testMnemonic, path: ethereumPath, password: "TREZOR")
    XCTAssertNotNil(signer)
  }

  // MARK: - Public Key

  func testPublicKeyFromPrivateKey() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    let publicKey = signer.publicKey

    XCTAssertEqual(publicKey!.count, 33)  // Compressed
    XCTAssertTrue(publicKey![0] == 0x02 || publicKey![0] == 0x03)
  }

  func testPublicKeyConsistency() throws {
    let signer1 = try EthereumSigner(privateKey: testPrivateKey)
    let signer2 = try EthereumSigner(privateKey: testPrivateKey)

    XCTAssertEqual(signer1.publicKey, signer2.publicKey)
  }

  // MARK: - Address

  func testAddressFromPrivateKey() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    let address = signer.address

    XCTAssertEqual(address!.checksummed.lowercased(), testAddress.lowercased())
  }

  func testAddressFromMnemonic() throws {
    // m/44'/60'/0'/0/0 from "abandon...about" mnemonic
    let signer = try EthereumSigner(mnemonic: testMnemonic, path: ethereumPath)
    let address = signer.address

    // Known address for this mnemonic at standard path
    XCTAssertEqual(
      address!.checksummed.lowercased(), "0x9858effd232b4033e47d90003d41ec34ecaeda94")
  }

  // MARK: - Signing

  func testSignHash() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    let hash = Keccak256.hash("test message")

    let signature: EthereumSignature = try signer.sign(hash: hash)

    XCTAssertEqual(signature.rawData.count, 65)
  }

  func testSignatureComponents() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    let hash = Keccak256.hash("test")

    let signature = try signer.sign(hash: hash)

    XCTAssertEqual(signature.r.count, 32)
    XCTAssertEqual(signature.s.count, 32)
    XCTAssertTrue(signature.v == 27 || signature.v == 28)
  }

  func testSignInvalidHashLength() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    let shortHash = Data(repeating: 0x01, count: 16)

    XCTAssertThrowsError(try signer.sign(hash: shortHash)) { error in
      XCTAssertTrue(error is SignerError)
    }
  }

  func testSignDeterministic() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    let hash = Keccak256.hash("deterministic test")

    let sig1 = try signer.sign(hash: hash)
    let sig2 = try signer.sign(hash: hash)

    XCTAssertEqual(sig1.rawData, sig2.rawData)
  }

  // MARK: - Signature Recovery

  func testSignatureRecovery() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    let hash = Keccak256.hash("recovery test")

    let signature = try signer.sign(hash: hash)
    let recoveredAddress = try signature.recoverAddress(from: hash)

    XCTAssertEqual(recoveredAddress, signer.address)
  }

  // MARK: - Personal Message Signing (EIP-191)

  func testSignPersonalMessage() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    let message = "Hello, Ethereum!"

    let signature = try signer.signPersonalMessage(message)

    XCTAssertEqual(signature.rawData.count, 65)
  }

  func testSignPersonalMessageData() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)
    let messageData = "Hello, Ethereum!".data(using: .utf8)!

    let signature = try signer.signPersonalMessage(messageData)

    XCTAssertEqual(signature.rawData.count, 65)
  }

  // MARK: - Different Derivation Paths

  func testDifferentAccountIndex() throws {
    let path0 = DerivationPath.ethereum.account(0)
    let path1 = DerivationPath.ethereum.account(1)

    let signer0 = try EthereumSigner(mnemonic: testMnemonic, path: path0)
    let signer1 = try EthereumSigner(mnemonic: testMnemonic, path: path1)

    XCTAssertNotEqual(signer0.address, signer1.address)
    XCTAssertNotEqual(signer0.publicKey, signer1.publicKey)
  }

  func testCustomDerivationPath() throws {
    let customPath = DerivationPath("m/44'/60'/0'/0/5")!
    let signer = try EthereumSigner(mnemonic: testMnemonic, path: customPath)

    XCTAssertNotNil(signer)
    XCTAssertEqual(signer.publicKey!.count, 33)
  }

  // MARK: - Protocol Conformance

  func testSignerProtocolConformance() throws {
    let signer = try EthereumSigner(privateKey: testPrivateKey)

    // Signer protocol
    let _: Data = signer.publicKey!
    let _: EthereumSignature = try signer.sign(hash: Keccak256.hash("test"))
  }

  func testPrivateKeySignerProtocolConformance() throws {
    // PrivateKeySigner protocol
    let _: EthereumSigner = try EthereumSigner(privateKey: testPrivateKey)
  }

  func testMnemonicSignerProtocolConformance() throws {
    // MnemonicSigner protocol
    let _: EthereumSigner = try EthereumSigner(mnemonic: testMnemonic, path: ethereumPath)
  }
}

// MARK: - EthereumSignature Tests

final class EthereumSignatureTests: XCTestCase {

  func testSignatureFromRawData() throws {
    let r = Data(repeating: 0x01, count: 32)
    let s = Data(repeating: 0x02, count: 32)
    let v: UInt8 = 27

    let signature = EthereumSignature(r: r, s: s, v: v)

    XCTAssertEqual(signature.r, r)
    XCTAssertEqual(signature.s, s)
    XCTAssertEqual(signature.v, v)
    XCTAssertEqual(signature.rawData.count, 65)
  }

  func testSignatureRawDataFormat() throws {
    let r = Data(repeating: 0xAA, count: 32)
    let s = Data(repeating: 0xBB, count: 32)
    let v: UInt8 = 28

    let signature = EthereumSignature(r: r, s: s, v: v)
    let rawData = signature.rawData

    XCTAssertEqual(rawData.prefix(32), r)
    XCTAssertEqual(rawData.dropFirst(32).prefix(32), s)
    XCTAssertEqual(rawData.last, v)
  }

  func testSignatureFromData() throws {
    var data = Data(repeating: 0x01, count: 32)  // r
    data.append(Data(repeating: 0x02, count: 32))  // s
    data.append(27)  // v

    let signature = try EthereumSignature(data: data)

    XCTAssertEqual(signature.r, Data(repeating: 0x01, count: 32))
    XCTAssertEqual(signature.s, Data(repeating: 0x02, count: 32))
    XCTAssertEqual(signature.v, 27)
  }

  func testSignatureFromDataInvalidLength() {
    let shortData = Data(repeating: 0x01, count: 64)

    XCTAssertThrowsError(try EthereumSignature(data: shortData))
  }
}

// MARK: - Test Helpers

extension Data {
  fileprivate init?(hex: String) {
    var hexStr = hex
    if hexStr.hasPrefix("0x") { hexStr = String(hexStr.dropFirst(2)) }
    guard hexStr.count % 2 == 0 else { return nil }

    var data = Data()
    var index = hexStr.startIndex
    while index < hexStr.endIndex {
      let nextIndex = hexStr.index(index, offsetBy: 2)
      guard let byte = UInt8(hexStr[index..<nextIndex], radix: 16) else { return nil }
      data.append(byte)
      index = nextIndex
    }
    self = data
  }
}
