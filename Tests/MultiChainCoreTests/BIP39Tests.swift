//
//  BIP39Tests.swift
//  MultiChainCoreTests
//
//  BIP39 Mnemonic tests using standard test vectors
//  Reference: https://github.com/trezor/python-mnemonic/blob/master/vectors.json
//

import XCTest

@testable import MultiChainCore

final class BIP39Tests: XCTestCase {

  // MARK: - Test Vector 1 (128-bit entropy = 12 words)

  func testVector1_EntropyToMnemonic() throws {
    let entropy = Data(hexString: "00000000000000000000000000000000")!
    let mnemonic = try BIP39.mnemonicFromEntropy(entropy)

    let expected =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    XCTAssertEqual(mnemonic, expected)
  }

  func testVector1_MnemonicToSeed() throws {
    let mnemonic =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    let seed = try BIP39.seed(from: mnemonic, password: "TREZOR")

    let expectedSeed =
      "c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e53495531f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04"
    XCTAssertEqual(seed.hexString, expectedSeed)
  }

  func testVector1_Validation() {
    let validMnemonic =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    XCTAssertTrue(BIP39.validate(validMnemonic))
  }

  // MARK: - Test Vector 2 (128-bit entropy)

  func testVector2_EntropyToMnemonic() throws {
    let entropy = Data(hexString: "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f")!
    let mnemonic = try BIP39.mnemonicFromEntropy(entropy)

    let expected = "legal winner thank year wave sausage worth useful legal winner thank yellow"
    XCTAssertEqual(mnemonic, expected)
  }

  func testVector2_MnemonicToSeed() throws {
    let mnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
    let seed = try BIP39.seed(from: mnemonic, password: "TREZOR")

    let expectedSeed =
      "2e8905819b8723fe2c1d161860e5ee1830318dbf49a83bd451cfb8440c28bd6fa457fe1296106559a3c80937a1c1069be3a3a5bd381ee6260e8d9739fce1f607"
    XCTAssertEqual(seed.hexString, expectedSeed)
  }

  // MARK: - Test Vector 3 (128-bit entropy)

  func testVector3_EntropyToMnemonic() throws {
    let entropy = Data(hexString: "80808080808080808080808080808080")!
    let mnemonic = try BIP39.mnemonicFromEntropy(entropy)

    let expected = "letter advice cage absurd amount doctor acoustic avoid letter advice cage above"
    XCTAssertEqual(mnemonic, expected)
  }

  // MARK: - Test Vector 4 (128-bit entropy)

  func testVector4_EntropyToMnemonic() throws {
    let entropy = Data(hexString: "ffffffffffffffffffffffffffffffff")!
    let mnemonic = try BIP39.mnemonicFromEntropy(entropy)

    let expected = "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong"
    XCTAssertEqual(mnemonic, expected)
  }

  // MARK: - Test Vector 5 (192-bit entropy = 18 words)

  func testVector5_EntropyToMnemonic() throws {
    let entropy = Data(hexString: "000000000000000000000000000000000000000000000000")!
    let mnemonic = try BIP39.mnemonicFromEntropy(entropy)

    let expected =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon agent"
    XCTAssertEqual(mnemonic, expected)
  }

  func testVector5_MnemonicToSeed() throws {
    let mnemonic =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon agent"
    let seed = try BIP39.seed(from: mnemonic, password: "TREZOR")

    let expectedSeed =
      "035895f2f481b1b0f01fcf8c289c794660b289981a78f8106447707fdd9666ca06da5a9a565181599b79f53b844d8a71dd9f439c52a3d7b3e8a79c906ac845fa"
    XCTAssertEqual(seed.hexString, expectedSeed)
  }

  // MARK: - Test Vector 6 (256-bit entropy = 24 words)

  func testVector6_EntropyToMnemonic() throws {
    let entropy = Data(
      hexString: "0000000000000000000000000000000000000000000000000000000000000000")!
    let mnemonic = try BIP39.mnemonicFromEntropy(entropy)

    let expected =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"
    XCTAssertEqual(mnemonic, expected)
  }

  func testVector6_MnemonicToSeed() throws {
    let mnemonic =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"
    let seed = try BIP39.seed(from: mnemonic, password: "TREZOR")

    let expectedSeed =
      "bda85446c68413707090a52022edd26a1c9462295029f2e60cd7c4f2bbd3097170af7a4d73245cafa9c3cca8d561a7c3de6f5d4a10be8ed2a5e608d68f92fcc8"
    XCTAssertEqual(seed.hexString, expectedSeed)
  }

  // MARK: - Test Vector 7 (256-bit entropy)

  func testVector7_EntropyToMnemonic() throws {
    let entropy = Data(
      hexString: "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f")!
    let mnemonic = try BIP39.mnemonicFromEntropy(entropy)

    let expected =
      "legal winner thank year wave sausage worth useful legal winner thank year wave sausage worth useful legal winner thank year wave sausage worth title"
    XCTAssertEqual(mnemonic, expected)
  }

  // MARK: - Mnemonic Generation

  func testGenerateMnemonic_12Words() throws {
    let mnemonic = try BIP39.generateMnemonic(strength: 128)
    let words = mnemonic.components(separatedBy: " ")

    XCTAssertEqual(words.count, 12)
    XCTAssertTrue(BIP39.validate(mnemonic))
  }

  func testGenerateMnemonic_15Words() throws {
    let mnemonic = try BIP39.generateMnemonic(strength: 160)
    let words = mnemonic.components(separatedBy: " ")

    XCTAssertEqual(words.count, 15)
    XCTAssertTrue(BIP39.validate(mnemonic))
  }

  func testGenerateMnemonic_18Words() throws {
    let mnemonic = try BIP39.generateMnemonic(strength: 192)
    let words = mnemonic.components(separatedBy: " ")

    XCTAssertEqual(words.count, 18)
    XCTAssertTrue(BIP39.validate(mnemonic))
  }

  func testGenerateMnemonic_21Words() throws {
    let mnemonic = try BIP39.generateMnemonic(strength: 224)
    let words = mnemonic.components(separatedBy: " ")

    XCTAssertEqual(words.count, 21)
    XCTAssertTrue(BIP39.validate(mnemonic))
  }

  func testGenerateMnemonic_24Words() throws {
    let mnemonic = try BIP39.generateMnemonic(strength: 256)
    let words = mnemonic.components(separatedBy: " ")

    XCTAssertEqual(words.count, 24)
    XCTAssertTrue(BIP39.validate(mnemonic))
  }

  // MARK: - Entropy Round-trip

  func testEntropyRoundTrip() throws {
    let originalEntropy = Data(
      hexString: "68a79eaca2324873eacc50cb9c6eca8cc68ea5d936f98787c60c7ebc74e6ce7c")!
    let mnemonic = try BIP39.mnemonicFromEntropy(originalEntropy)
    let recoveredEntropy = try BIP39.entropyFromMnemonic(mnemonic)

    XCTAssertEqual(recoveredEntropy, originalEntropy)
  }

  // MARK: - Validation Tests

  func testValidate_ValidMnemonic() {
    let mnemonic =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    XCTAssertTrue(BIP39.validate(mnemonic))
  }

  func testValidate_InvalidChecksum() {
    // Changed last word from "about" to "abandon" - invalid checksum
    let mnemonic =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon"
    XCTAssertFalse(BIP39.validate(mnemonic))
  }

  func testValidate_InvalidWord() {
    // "notaword" is not in the word list
    let mnemonic =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon notaword"
    XCTAssertFalse(BIP39.validate(mnemonic))
  }

  func testValidate_WrongWordCount() {
    // Only 11 words
    let mnemonic =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon"
    XCTAssertFalse(BIP39.validate(mnemonic))
  }

  func testValidate_TooFewWords() {
    let mnemonic = "abandon abandon abandon"
    XCTAssertFalse(BIP39.validate(mnemonic))
  }

  // MARK: - Error Cases

  func testInvalidEntropySize_TooSmall() {
    let entropy = Data(hexString: "00000000000000000000000000")!  // 104 bits
    XCTAssertThrowsError(try BIP39.mnemonicFromEntropy(entropy)) { error in
      guard case BIP39Error.invalidEntropySize = error else {
        XCTFail("Expected invalidEntropySize error")
        return
      }
    }
  }

  func testInvalidEntropySize_TooLarge() {
    let entropy = Data(
      hexString: "000000000000000000000000000000000000000000000000000000000000000000")!  // 264 bits
    XCTAssertThrowsError(try BIP39.mnemonicFromEntropy(entropy)) { error in
      guard case BIP39Error.invalidEntropySize = error else {
        XCTFail("Expected invalidEntropySize error")
        return
      }
    }
  }

  func testInvalidEntropySize_NotMultipleOf32() {
    let entropy = Data(hexString: "0000000000000000000000000000000000")!  // 136 bits
    XCTAssertThrowsError(try BIP39.mnemonicFromEntropy(entropy)) { error in
      guard case BIP39Error.invalidEntropySize = error else {
        XCTFail("Expected invalidEntropySize error")
        return
      }
    }
  }

  // MARK: - Seed Generation with Password

  func testSeedWithEmptyPassword() throws {
    let mnemonic =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    let seed = try BIP39.seed(from: mnemonic, password: "")

    // Different from TREZOR password
    let seedWithTrezor = try BIP39.seed(from: mnemonic, password: "TREZOR")
    XCTAssertNotEqual(seed, seedWithTrezor)
  }

  func testSeedLength() throws {
    let mnemonic =
      "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    let seed = try BIP39.seed(from: mnemonic)

    XCTAssertEqual(seed.count, 64)  // 512 bits
  }

  // MARK: - Word List Tests

  func testEnglishWordListCount() {
    XCTAssertEqual(BIP39WordList.english.count, 2048)
  }

  func testEnglishWordListFirstWord() {
    XCTAssertEqual(BIP39WordList.english.first, "abandon")
  }

  func testEnglishWordListLastWord() {
    XCTAssertEqual(BIP39WordList.english.last, "zoo")
  }

  func testEnglishWordListUniqueness() {
    let wordSet = Set(BIP39WordList.english)
    XCTAssertEqual(wordSet.count, BIP39WordList.english.count, "Word list contains duplicates")
  }

  // MARK: - Language Tests

  func testLanguageSeparator_English() {
    XCTAssertEqual(BIP39Language.english.separator, " ")
  }

  func testLanguageSeparator_Japanese() {
    XCTAssertEqual(BIP39Language.japanese.separator, "\u{3000}")  // Ideographic space
  }
}
