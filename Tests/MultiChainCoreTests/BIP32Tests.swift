//
//  BIP32Tests.swift
//  MultiChainCoreTests
//
//  TDD: RED phase - Write failing tests first
//  Reference: https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
//

import XCTest

@testable import MultiChainCore

final class BIP32Tests: XCTestCase {

  // MARK: - Test Vector 1
  // Seed: 000102030405060708090a0b0c0d0e0f

  func testVector1_MasterKey() throws {
    let seedHex = "000102030405060708090a0b0c0d0e0f"
    let seed = Data(hexString: seedHex)!

    let masterKey = try BIP32.masterKey(seed: seed)

    // Expected from BIP32 spec
    let expectedPrivateKey = "e8f32e723decf4051aefac8e2c93c9c5b214313817cdb01a1494b917c8436b35"
    let expectedChainCode = "873dff81c02f525623fd1fe5167eac3a55a049de3d314bb42ee227ffed37d508"

    XCTAssertEqual(masterKey.privateKey.hexString, expectedPrivateKey)
    XCTAssertEqual(masterKey.chainCode.hexString, expectedChainCode)
  }

  func testVector1_DeriveHardenedChild_m_0h() throws {
    let seedHex = "000102030405060708090a0b0c0d0e0f"
    let seed = Data(hexString: seedHex)!

    let masterKey = try BIP32.masterKey(seed: seed)
    let childKey = try BIP32.deriveChild(from: masterKey, index: 0, hardened: true)

    // Expected from BIP32 spec for m/0'
    let expectedPrivateKey = "edb2e14f9ee77d26dd93b4ecede8d16ed408ce149b6cd80b0715a2d911a0afea"
    let expectedChainCode = "47fdacbd0f1097043b78c63c20c34ef4ed9a111d980047ad16282c7ae6236141"

    XCTAssertEqual(childKey.privateKey.hexString, expectedPrivateKey)
    XCTAssertEqual(childKey.chainCode.hexString, expectedChainCode)
  }

  func testVector1_DerivePath_m_0h_1_2h_2_1000000000() throws {
    let seedHex = "000102030405060708090a0b0c0d0e0f"
    let seed = Data(hexString: seedHex)!

    let path = DerivationPath("m/0'/1/2'/2/1000000000")!
    let derivedKey = try BIP32.derive(seed: seed, path: path)

    // Expected from BIP32 spec for m/0'/1/2'/2/1000000000
    let expectedPrivateKey = "471b76e389e528d6de6d816857e012c5455051cad6660850e58372a6c3e6e7c8"
    let expectedChainCode = "c783e67b921d2beb8f6b389cc646d7263b4145701dadd2161548a8b078e65e9e"

    XCTAssertEqual(derivedKey.privateKey.hexString, expectedPrivateKey)
    XCTAssertEqual(derivedKey.chainCode.hexString, expectedChainCode)
  }

  // MARK: - Test Vector 2
  // Seed: fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542

  func testVector2_MasterKey() throws {
    let seedHex =
      "fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542"
    let seed = Data(hexString: seedHex)!

    let masterKey = try BIP32.masterKey(seed: seed)

    // Expected from BIP32 spec
    let expectedPrivateKey = "4b03d6fc340455b363f51020ad3ecca4f0850280cf436c70c727923f6db46c3e"
    let expectedChainCode = "60499f801b896d83179a4374aeb7822aaeaceaa0db1f85ee3e904c4defbd9689"

    XCTAssertEqual(masterKey.privateKey.hexString, expectedPrivateKey)
    XCTAssertEqual(masterKey.chainCode.hexString, expectedChainCode)
  }

  func testVector2_DeriveNormalChild_m_0() throws {
    let seedHex =
      "fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542"
    let seed = Data(hexString: seedHex)!

    let masterKey = try BIP32.masterKey(seed: seed)
    let childKey = try BIP32.deriveChild(from: masterKey, index: 0, hardened: false)

    // Expected from BIP32 spec for m/0
    let expectedPrivateKey = "abe74a98f6c7eabee0428f53798f0ab8aa1bd37873999041703c742f15ac7e1e"
    let expectedChainCode = "f0909affaa7ee7abe5dd4e100598d4dc53cd709d5a5c2cac40e7412f232f7c9c"

    XCTAssertEqual(childKey.privateKey.hexString, expectedPrivateKey)
    XCTAssertEqual(childKey.chainCode.hexString, expectedChainCode)
  }

  func testVector2_DerivePath_m_0_2147483647h_1() throws {
    let seedHex =
      "fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542"
    let seed = Data(hexString: seedHex)!

    let path = DerivationPath("m/0/2147483647'/1")!
    let derivedKey = try BIP32.derive(seed: seed, path: path)

    // Expected from BIP32 spec for m/0/2147483647'/1
    let expectedPrivateKey = "704addf544a06e5ee4bea37098463c23613da32020d604506da8c0518e1da4b7"
    let expectedChainCode = "f366f48f1ea9f2d1d3fe958c95ca84ea18e4c4ddb9366c336c927eb246fb38cb"

    XCTAssertEqual(derivedKey.privateKey.hexString, expectedPrivateKey)
    XCTAssertEqual(derivedKey.chainCode.hexString, expectedChainCode)
  }

  // MARK: - Public Key Derivation Tests

  func testPublicKeyDerivation() throws {
    let seedHex = "000102030405060708090a0b0c0d0e0f"
    let seed = Data(hexString: seedHex)!

    let masterKey = try BIP32.masterKey(seed: seed)
    let publicKey = try BIP32.publicKey(from: masterKey)

    // Master public key should be 33 bytes (compressed)
    XCTAssertEqual(publicKey.count, 33)

    // Expected compressed public key for test vector 1 master
    let expectedPublicKey = "0339a36013301597daef41fbe593a02cc513d0b55527ec2df1050e2e8ff49c85c2"
    XCTAssertEqual(publicKey.hexString, expectedPublicKey)
  }

  // MARK: - Ethereum Path Tests

  func testEthereumStandardPath() throws {
    let seedHex = "000102030405060708090a0b0c0d0e0f"
    let seed = Data(hexString: seedHex)!

    // Ethereum standard path: m/44'/60'/0'/0/0
    let path = DerivationPath.ethereum
    let derivedKey = try BIP32.derive(seed: seed, path: path)

    // Just verify it doesn't throw and returns valid key
    XCTAssertEqual(derivedKey.privateKey.count, 32)
    XCTAssertEqual(derivedKey.chainCode.count, 32)
  }

  func testStarkNetStandardPath() throws {
    let seedHex = "000102030405060708090a0b0c0d0e0f"
    let seed = Data(hexString: seedHex)!

    // StarkNet standard path: m/44'/9004'/0'/0/0
    let path = DerivationPath.starknet
    let derivedKey = try BIP32.derive(seed: seed, path: path)

    // Just verify it doesn't throw and returns valid key
    XCTAssertEqual(derivedKey.privateKey.count, 32)
    XCTAssertEqual(derivedKey.chainCode.count, 32)
  }

  // MARK: - Error Cases

  func testInvalidSeedLength() {
    let shortSeed = Data([0x00, 0x01, 0x02])  // Too short

    XCTAssertThrowsError(try BIP32.masterKey(seed: shortSeed)) { error in
      guard case BIP32Error.invalidSeedLength = error else {
        XCTFail("Expected invalidSeedLength error")
        return
      }
    }
  }

  func testSeedTooLong() {
    let longSeed = Data(repeating: 0x00, count: 65)  // Too long (max 64)

    XCTAssertThrowsError(try BIP32.masterKey(seed: longSeed)) { error in
      guard case BIP32Error.invalidSeedLength = error else {
        XCTFail("Expected invalidSeedLength error")
        return
      }
    }
  }
}

// MARK: - Data Extension for Tests

extension Data {
  init?(hexString: String) {
    let hex = hexString.lowercased()
    guard hex.count % 2 == 0 else { return nil }

    var data = Data()
    var index = hex.startIndex

    while index < hex.endIndex {
      let nextIndex = hex.index(index, offsetBy: 2)
      guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
      data.append(byte)
      index = nextIndex
    }

    self = data
  }

  var hexString: String {
    map { String(format: "%02x", $0) }.joined()
  }
}
