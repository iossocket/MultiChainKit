//
//  CryptoTests.swift
//  EthereumKitTests
//

import XCTest

@testable import EthereumKit

final class CryptoTests: XCTestCase {

  // MARK: - Keccak256

  func testKeccak256EmptyData() {
    let hash = Keccak256.hash(Data())
    XCTAssertEqual(hash.count, 32)
    XCTAssertEqual(
      hash.hexString, "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")
  }

  func testKeccak256HelloWorld() {
    let data = "Hello, World!".data(using: .utf8)!
    let hash = Keccak256.hash(data)
    XCTAssertEqual(
      hash.hexString, "acaf3289d7b601cbd114fb36c4d29c85bbfd5e133f14cb355c3fd8d99367964f")
  }

  func testKeccak256String() {
    let hash = Keccak256.hash("test")
    XCTAssertEqual(
      hash.hexString, "9c22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb658")
  }

  // MARK: - Secp256k1 Public Key

  func testPublicKeyFromPrivateKey() throws {
    let privateKey = Data(hex: "e8f32e723decf4051aefac8e2c93c9c5b214313817cdb01a1494b917c8436b35")!
    let publicKey = try Secp256k1.publicKey(from: privateKey, compressed: false)

    XCTAssertEqual(publicKey.count, 65)
    XCTAssertEqual(publicKey[0], 0x04)
  }

  func testCompressedPublicKey() throws {
    let privateKey = Data(hex: "e8f32e723decf4051aefac8e2c93c9c5b214313817cdb01a1494b917c8436b35")!
    let publicKey = try Secp256k1.publicKey(from: privateKey, compressed: true)

    XCTAssertEqual(publicKey.count, 33)
    XCTAssertTrue(publicKey[0] == 0x02 || publicKey[0] == 0x03)
  }

  func testInvalidPrivateKey() {
    let invalidKey = Data(repeating: 0, count: 32)
    XCTAssertThrowsError(try Secp256k1.publicKey(from: invalidKey, compressed: true))
  }

  func testPrivateKeyWrongLength() {
    let shortKey = Data(repeating: 1, count: 16)
    XCTAssertThrowsError(try Secp256k1.publicKey(from: shortKey, compressed: true))
  }

  // MARK: - Address Derivation

  func testAddressFromPublicKey() throws {
    let privateKey = Data(hex: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")!
    let publicKey = try Secp256k1.publicKey(from: privateKey, compressed: false)
    let address = Secp256k1.ethereumAddress(from: publicKey)

    XCTAssertEqual(address.data.count, 20)
  }

  func testAddressFromPrivateKey() throws {
    let privateKey = Data(hex: "4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318")!
    let address = try Secp256k1.ethereumAddress(fromPrivateKey: privateKey)

    XCTAssertEqual(address.checksummed.lowercased(), "0x2c7536e3605d9c16a7a3d7b1898e529396a65c23")
  }

  func testAddressAndPublicKeyFromPrivateKey() throws {
    let privateKey = Data(hex: "4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318")!
    let (address, publicKey) = try Secp256k1.ethereumAddressAndPublicKey(fromPrivateKey: privateKey)

    XCTAssertEqual(address.checksummed.lowercased(), "0x2c7536e3605d9c16a7a3d7b1898e529396a65c23")
    XCTAssertEqual(publicKey.count, 33)
    XCTAssertTrue(publicKey[0] == 0x02 || publicKey[0] == 0x03)
  }

  // MARK: - Signing

  func testSignMessage() throws {
    let privateKey = Data(hex: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")!
    let message = Keccak256.hash("test message")

    let signature = try Secp256k1.sign(message: message, privateKey: privateKey)

    XCTAssertEqual(signature.count, 65)
  }

  func testSignatureComponents() throws {
    let privateKey = Data(hex: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")!
    let message = Keccak256.hash("test")

    let signature = try Secp256k1.sign(message: message, privateKey: privateKey)

    let r = signature.prefix(32)
    let s = signature.dropFirst(32).prefix(32)
    let v = signature.last!

    XCTAssertEqual(r.count, 32)
    XCTAssertEqual(s.count, 32)
    XCTAssertTrue(v == 27 || v == 28 || v == 0 || v == 1)
  }

  // MARK: - Recovery

  func testRecoverPublicKey() throws {
    let privateKey = Data(hex: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")!
    let message = Keccak256.hash("test recovery")

    let originalPublicKey = try Secp256k1.publicKey(from: privateKey, compressed: false)
    let signature = try Secp256k1.sign(message: message, privateKey: privateKey)

    let recoveredPublicKey = try Secp256k1.recoverPublicKey(message: message, signature: signature)

    XCTAssertEqual(recoveredPublicKey, originalPublicKey)
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

  fileprivate var hexString: String {
    map { String(format: "%02x", $0) }.joined()
  }
}
