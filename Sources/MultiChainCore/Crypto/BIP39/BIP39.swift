//
//  BIP39.swift
//  MultiChainCore
//
//  https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
//

import Foundation
import CryptoSwift

// MARK: - BIP39Language

public enum BIP39Language: String, CaseIterable, Sendable {
    case english
    case chineseSimplified = "chinese_simplified"
    case chineseTraditional = "chinese_traditional"
    case japanese

    public var words: [String] {
        switch self {
        case .english: return BIP39WordList.english
        case .chineseSimplified: return BIP39WordList.chineseSimplified
        case .chineseTraditional: return BIP39WordList.chineseTraditional
        case .japanese: return BIP39WordList.japanese
        }
    }

    public var separator: String {
        self == .japanese ? "\u{3000}" : " "
    }
}

// MARK: - BIP39Error

public enum BIP39Error: Error, Sendable {
    case invalidEntropySize(Int)
    case entropyGenerationFailed
    case invalidMnemonic
    case invalidChecksumLength
    case checksumMismatch
    case seedGenerationFailed
}

// MARK: - BIP39

public enum BIP39 {

    // MARK: - Generation

    public static func generateMnemonic(
        strength: Int = 128,
        language: BIP39Language = .english
    ) throws -> String {
        let entropy = try generateEntropy(bits: strength)
        return try mnemonicFromEntropy(entropy, language: language)
    }

    public static func mnemonicFromEntropy(
        _ entropy: Data,
        language: BIP39Language = .english
    ) throws -> String {
        let words = try mnemonicWordsFromEntropy(entropy, language: language)
        return words.joined(separator: language.separator)
    }

    public static func mnemonicWordsFromEntropy(
        _ entropy: Data,
        language: BIP39Language = .english
    ) throws -> [String] {
        let entropyBits = entropy.count * 8
        guard entropyBits >= 128, entropyBits <= 256, entropyBits % 32 == 0 else {
            throw BIP39Error.invalidEntropySize(entropyBits)
        }

        let checksumLength = entropyBits / 32
        let hash = entropy.sha256()
        guard let checksumBits = bitsFromData(hash, count: checksumLength) else {
            throw BIP39Error.invalidChecksumLength
        }

        let entropyBitString = bitStringFromData(entropy)
        let combinedBits = entropyBitString + checksumBits

        let wordList = language.words
        var words: [String] = []

        for i in stride(from: 0, to: combinedBits.count, by: 11) {
            let endIndex = min(i + 11, combinedBits.count)
            let chunk = String(combinedBits[combinedBits.index(combinedBits.startIndex, offsetBy: i)..<combinedBits.index(combinedBits.startIndex, offsetBy: endIndex)])

            guard let index = Int(chunk, radix: 2), index < wordList.count else {
                throw BIP39Error.invalidMnemonic
            }
            words.append(wordList[index])
        }

        return words
    }

    // MARK: - Validation

    public static func validate(_ mnemonic: String, language: BIP39Language = .english) -> Bool {
        do {
            _ = try entropyFromMnemonic(mnemonic, language: language)
            return true
        } catch {
            return false
        }
    }

    public static func entropyFromMnemonic(
        _ mnemonic: String,
        language: BIP39Language = .english
    ) throws -> Data {
        let words = mnemonic.components(separatedBy: language.separator)
        return try entropyFromMnemonicWords(words, language: language)
    }

    public static func entropyFromMnemonicWords(
        _ words: [String],
        language: BIP39Language = .english
    ) throws -> Data {
        guard words.count >= 12, words.count <= 24, words.count % 3 == 0 else {
            throw BIP39Error.invalidMnemonic
        }

        let wordList = language.words

        var bitString = ""
        for word in words {
            guard let index = wordList.firstIndex(of: word) else {
                throw BIP39Error.invalidMnemonic
            }
            let bits = String(index, radix: 2)
            bitString += String(repeating: "0", count: 11 - bits.count) + bits
        }

        let checksumLength = words.count / 3
        let entropyBitCount = bitString.count - checksumLength

        let entropyBits = String(bitString.prefix(entropyBitCount))
        let checksumBits = String(bitString.suffix(checksumLength))

        guard let entropy = dataFromBitString(entropyBits) else {
            throw BIP39Error.invalidMnemonic
        }

        let hash = entropy.sha256()
        guard let expectedChecksum = bitsFromData(hash, count: checksumLength) else {
            throw BIP39Error.invalidChecksumLength
        }

        guard checksumBits == expectedChecksum else {
            throw BIP39Error.checksumMismatch
        }

        return entropy
    }

    // MARK: - Seed

    public static func seed(from mnemonic: String, password: String = "") throws -> Data {
        guard let mnemonicData = mnemonic.decomposedStringWithCompatibilityMapping.data(using: .utf8) else {
            throw BIP39Error.seedGenerationFailed
        }

        let salt = "mnemonic" + password
        guard let saltData = salt.decomposedStringWithCompatibilityMapping.data(using: .utf8) else {
            throw BIP39Error.seedGenerationFailed
        }

        do {
            let seed = try PKCS5.PBKDF2(
                password: Array(mnemonicData),
                salt: Array(saltData),
                iterations: 2048,
                keyLength: 64,
                variant: .sha2(.sha512)
            ).calculate()
            return Data(seed)
        } catch {
            throw BIP39Error.seedGenerationFailed
        }
    }

    // MARK: - Private

    private static func generateEntropy(bits: Int) throws -> Data {
        guard bits >= 128, bits <= 256, bits % 32 == 0 else {
            throw BIP39Error.invalidEntropySize(bits)
        }

        let byteCount = bits / 8
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)

        guard status == errSecSuccess else {
            throw BIP39Error.entropyGenerationFailed
        }

        return Data(bytes)
    }

    private static func bitStringFromData(_ data: Data) -> String {
        data.map { byte in
            let binary = String(byte, radix: 2)
            return String(repeating: "0", count: 8 - binary.count) + binary
        }.joined()
    }

    private static func bitsFromData(_ data: Data, count: Int) -> String? {
        let bitString = bitStringFromData(data)
        guard count <= bitString.count else { return nil }
        return String(bitString.prefix(count))
    }

    private static func dataFromBitString(_ bitString: String) -> Data? {
        guard bitString.count % 8 == 0 else { return nil }

        var bytes: [UInt8] = []
        var index = bitString.startIndex

        while index < bitString.endIndex {
            let nextIndex = bitString.index(index, offsetBy: 8)
            let byteString = String(bitString[index..<nextIndex])
            guard let byte = UInt8(byteString, radix: 2) else { return nil }
            bytes.append(byte)
            index = nextIndex
        }

        return Data(bytes)
    }
}
