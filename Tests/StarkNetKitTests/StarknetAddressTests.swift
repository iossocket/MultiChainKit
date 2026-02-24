//
//  StarknetAddressTests.swift
//  StarknetKitTests
//
//  Tests for StarknetAddress type
//

import Foundation
import Testing

@testable import StarknetKit

@Suite("StarknetAddress Tests")
struct StarknetAddressTests {

  // MARK: - Initialization Tests

  @Test("Initialize from full 64-char hex string")
  func initFromFullHex() {
    let addr = StarknetAddress("0x02fd23d9182193775423497fc0c472e156c57c69e4089a1967fb288a2d84e914")
    #expect(addr != nil)
    #expect(addr!.data.count == 32)
  }

  @Test("Initialize from short hex string with padding")
  func initFromShortHex() {
    let addr = StarknetAddress("0xa")
    #expect(addr != nil)
    #expect(addr!.data.count == 32)
    #expect(addr!.data[31] == 0x0a)
    #expect(addr!.data[0] == 0x00)
  }

  @Test("Initialize from hex without 0x prefix")
  func initWithoutPrefix() {
    let addr = StarknetAddress("0a")
    #expect(addr != nil)
    #expect(addr!.data[31] == 0x0a)
  }

  @Test("Initialize from Data")
  func initFromData() {
    var data = Data(repeating: 0, count: 32)
    data[31] = 0x1f
    let addr = StarknetAddress(data)
    #expect(addr.data == data)
  }

  @Test("Initialize from short Data pads with zeros")
  func initFromShortData() {
    let data = Data([0x01, 0x02])
    let addr = StarknetAddress(data)
    #expect(addr.data.count == 32)
    #expect(addr.data[30] == 0x01)
    #expect(addr.data[31] == 0x02)
  }

  @Test("Initialize from empty string returns nil")
  func initFromEmptyString() {
    let addr = StarknetAddress("")
    #expect(addr == nil)
  }

  @Test("Initialize from invalid hex returns nil")
  func initFromInvalidHex() {
    let addr = StarknetAddress("0xGGGG")
    #expect(addr == nil)
  }

  @Test("Initialize from too long hex returns nil")
  func initFromTooLongHex() {
    // 65 hex chars (> 64)
    let hex = "0x" + String(repeating: "a", count: 65)
    let addr = StarknetAddress(hex)
    #expect(addr == nil)
  }

  // MARK: - Zero Address

  @Test("Zero address")
  func zeroAddress() {
    let zero = StarknetAddress.zero
    #expect(zero.data == Data(repeating: 0, count: 32))
  }

  // MARK: - Checksum Tests (starknet.js / starknet-jvm test vectors)

  @Test("Checksum: starknet.js test vector")
  func checksumStarknetJS() {
    let addr = StarknetAddress("0x2fd23d9182193775423497fc0c472e156c57c69e4089a1967fb288a2d84e914")!
    #expect(
      addr.checksummed == "0x02Fd23d9182193775423497fc0c472E156C57C69E4089A1967fb288A2d84e914")
  }

  @Test("Checksum: abcdef pattern")
  func checksumAbcdefPattern() {
    let addr = StarknetAddress(
      "0x00abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefab")!
    #expect(
      addr.checksummed == "0x00AbcDefaBcdefabCDEfAbCDEfAbcdEFAbCDEfabCDefaBCdEFaBcDeFaBcDefAb")
  }

  @Test("Checksum: fedcba pattern")
  func checksumFedcbaPattern() {
    let addr = StarknetAddress("0xfedcbafedcbafedcbafedcbafedcbafedcbafedcbafedcbafedcbafedcbafe")!
    #expect(
      addr.checksummed == "0x00fEdCBafEdcbafEDCbAFedCBAFeDCbafEdCBAfeDcbaFeDCbAfEDCbAfeDcbAFE")
  }

  @Test("Checksum: small value 0xa")
  func checksumSmallValue() {
    let addr = StarknetAddress("0xa")!
    #expect(
      addr.checksummed == "0x000000000000000000000000000000000000000000000000000000000000000A")
  }

  @Test("Checksum: zero address")
  func checksumZero() {
    let addr = StarknetAddress("0x0")!
    #expect(
      addr.checksummed == "0x0000000000000000000000000000000000000000000000000000000000000000")
  }

  @Test("Checksum: starknet.js JSDoc example")
  func checksumJSDocExample() {
    let addr = StarknetAddress("0x90591d9fa3efc87067d95a643f8455e0b8190eb8cb7bfd39e4fb7571fdf")!
    #expect(
      addr.checksummed == "0x0000090591D9fA3EfC87067d95a643f8455E0b8190eb8Cb7bFd39e4fb7571fDF")
  }

  @Test("Checksum: ETH token contract address")
  func checksumEthToken() {
    let addr = StarknetAddress("0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7")!
    #expect(
      addr.checksummed == "0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7")
  }

  @Test("Checksum: short address")
  func checksumShortAddress() {
    // Verify short addresses get properly padded and checksummed
    let addr = StarknetAddress("0xbd3fcc84644ddd6b96f7c741b1562b82f9e004dc7")!
    let checksummed = addr.checksummed
    // Should be 66 chars (0x + 64 hex)
    #expect(checksummed.count == 66)
    #expect(checksummed.hasPrefix("0x00000000000000000000000"))
  }

  // MARK: - Equality Tests

  @Test("Equal addresses")
  func equalAddresses() {
    let a = StarknetAddress("0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7")!
    let b = StarknetAddress("0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7")!
    #expect(a == b)
  }

  @Test("Different addresses")
  func differentAddresses() {
    let a = StarknetAddress("0x1")!
    let b = StarknetAddress("0x2")!
    #expect(a != b)
  }

  // MARK: - Hashable Tests

  @Test("Hashable conformance")
  func hashable() {
    let a = StarknetAddress("0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7")!
    let b = StarknetAddress("0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7")!
    let c = StarknetAddress("0x1")!

    var set = Set<StarknetAddress>()
    set.insert(a)
    set.insert(b)
    set.insert(c)
    #expect(set.count == 2)
  }

  // MARK: - Codable Tests

  @Test("Encode to JSON")
  func encodeToJSON() throws {
    let addr = StarknetAddress("0xa")!
    let data = try JSONEncoder().encode(addr)
    let json = String(data: data, encoding: .utf8)!
    // Should encode as checksummed string
    #expect(json == "\"0x000000000000000000000000000000000000000000000000000000000000000A\"")
  }

  @Test("Decode from JSON")
  func decodeFromJSON() throws {
    let json = "\"0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7\""
    let data = json.data(using: .utf8)!
    let addr = try JSONDecoder().decode(StarknetAddress.self, from: data)
    #expect(
      addr == StarknetAddress("0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7"))
  }

  @Test("Decode invalid JSON throws")
  func decodeInvalidJSON() {
    let json = "\"not-a-hex\""
    let data = json.data(using: .utf8)!
    #expect(throws: DecodingError.self) {
      _ = try JSONDecoder().decode(StarknetAddress.self, from: data)
    }
  }

  // MARK: - Description Tests

  @Test("Description returns checksummed")
  func descriptionReturnsChecksummed() {
    let addr = StarknetAddress("0x2fd23d9182193775423497fc0c472e156c57c69e4089a1967fb288a2d84e914")!
    #expect(addr.description == addr.checksummed)
  }
}
