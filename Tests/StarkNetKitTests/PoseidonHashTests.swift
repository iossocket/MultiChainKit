//
//  PoseidonHashTests.swift
//  StarknetKitTests
//
//  Tests for Poseidon hash function
//

import BigInt
import Foundation
import Testing

@testable import StarknetKit

@Suite("PoseidonHash Tests")
struct PoseidonHashTests {

  // MARK: - Single value

  @Test("Poseidon hash: single zero")
  func hashSingleZero() throws {
    let result = try Poseidon.hash(.zero)
    #expect(result == Felt("0x60009f680a43e6f760790f76214b26243464cdd4f31fdc460baf66d32897c1b")!)
  }

  @Test("Poseidon hash: single one")
  func hashSingleOne() throws {
    let result = try Poseidon.hash(.one)
    #expect(result == Felt("0x6d226d4c804cd74567f5ac59c6a4af1fe2a6eced19fb7560a9124579877da25")!)
  }

  @Test("Poseidon hash: single big number")
  func hashSingleBig() throws {
    let value = Felt(BigUInt("737869762948382064636737869762948382064636737869762948382064636"))
    let result = try Poseidon.hash(value)
    #expect(result == Felt("0x1580978ed34d52bfbc78c9f21da6e9df1ed6544bf1dd561616b0aba45a40380")!)
  }

  // MARK: - Two values

  @Test("Poseidon hash: two zeros")
  func hashTwoZeros() throws {
    let result = try Poseidon.hash(.zero, .zero)
    #expect(result == Felt("0x293d3e8a80f400daaaffdd5932e2bcc8814bab8f414a75dcacf87318f8b14c5")!)
  }

  @Test("Poseidon hash: two big numbers")
  func hashTwoBig() throws {
    let value = Felt(BigUInt("737869762948382064636737869762948382064636737869762948382064636"))
    let result = try Poseidon.hash(value, value)
    #expect(result == Felt("0x59c0ba54a2613d811726e10be9d6f7e01cf52d6d68ced0d16829027948cdfc3")!)
  }

  // MARK: - Many values

  @Test("Poseidon hash: three zeros")
  func hashThreeZeros() throws {
    let result = try Poseidon.hashMany([.zero, .zero, .zero])
    #expect(result == Felt("0x29aee7812642221479b7e8af204ceaa5a7b7e113349fc8fb93e6303b477eb4d")!)
  }

  @Test("Poseidon hash: [10, 8, 5]")
  func hashSmallValues() throws {
    let result = try Poseidon.hashMany([Felt(10), Felt(8), Felt(5)])
    #expect(result == Felt("0x53aa661c2388b74f48a16163c38893760e26884211599194ffe264f14b5c6e7")!)
  }

  @Test("Poseidon hash: three big numbers")
  func hashThreeBig() throws {
    let v1 = Felt(BigUInt("737869762948382064636737869762948382064636737869762948382064636"))
    let v2 = Felt(BigUInt("948382064636737869762948382064636737869762948382064636737869762"))
    let result = try Poseidon.hashMany([v1, v2, v1])
    #expect(result == Felt("0xdaa82261a460722d8deb7d3bb2cb1838084887549df141540b6d88658d34ed")!)
  }

  @Test("Poseidon hash: four zeros")
  func hashFourZeros() throws {
    let result = try Poseidon.hashMany([.zero, .zero, .zero, .zero])
    #expect(result == Felt("0x5c4def9d0323f31f80e90c55fa780591ed2e2fee266491c0bd891aedac38935")!)
  }

  @Test("Poseidon hash: four values [1, 10, 100, 1000]")
  func hashFourValues() throws {
    let result = try Poseidon.hashMany([.one, Felt(10), Felt(100), Felt(1000)])
    #expect(result == Felt("0x51f923f87ee53d16c2d680c2c0c9eb0132ba255d52b6dd69f4b9918dcbe00a1")!)
  }

  @Test("Poseidon hash: ten zeros")
  func hashTenZeros() throws {
    let result = try Poseidon.hashMany(Array(repeating: Felt.zero, count: 10))
    #expect(result == Felt("0x7c19756199eacf9ac8c06ecab986929be144ee4a852db16f796435562e69c7c")!)
  }
}
