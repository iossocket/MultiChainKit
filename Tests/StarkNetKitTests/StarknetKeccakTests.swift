//
//  StarknetKeccakTests.swift
//  StarknetKitTests
//
//  Tests for sn_keccak and function selector
//

import Foundation
import Testing

@testable import StarknetKit

@Suite("StarknetKeccak Tests")
struct StarknetKeccakTests {

  // MARK: - Function Selector

  @Test("Selector: test")
  func selectorTest() {
    let result = StarknetKeccak.functionSelector("test")
    #expect(result == Felt("0x22ff5f21f0b81b113e63f7db6da94fedef11b2119b4088b89664fb9a3cb658")!)
  }

  @Test("Selector: initialize")
  func selectorInitialize() {
    let result = StarknetKeccak.functionSelector("initialize")
    #expect(result == Felt("0x79dc0da7c54b95f10aa182ad0a46400db63156920adb65eca2654c0945a463")!)
  }

  @Test("Selector: mint")
  func selectorMint() {
    let result = StarknetKeccak.functionSelector("mint")
    #expect(result == Felt("0x2f0b3c5710379609eb5495f1ecd348cb28167711b73609fe565a72734550354")!)
  }

  @Test("Selector: __default__ returns zero")
  func selectorDefault() {
    let result = StarknetKeccak.functionSelector("__default__")
    #expect(result == .zero)
  }

  @Test("Selector: __l1_default__ returns zero")
  func selectorL1Default() {
    let result = StarknetKeccak.functionSelector("__l1_default__")
    #expect(result == .zero)
  }

  // MARK: - sn_keccak

  @Test("sn_keccak: transfer")
  func snKeccakTransfer() {
    let result = StarknetKeccak.hash("transfer".data(using: .utf8)!)
    // sn_keccak is keccak256 masked to 250 bits, same as selector for non-special names
    #expect(result == StarknetKeccak.functionSelector("transfer"))
  }

  @Test("sn_keccak: result is at most 250 bits")
  func snKeccakBitLength() {
    let result = StarknetKeccak.hash("test".data(using: .utf8)!)
    #expect(result.bitLength <= 250)
  }
}
