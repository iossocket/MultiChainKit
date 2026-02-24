//
//  EthereumChainTests.swift
//  EthereumKitTests
//

import MultiChainCore
import XCTest

@testable import EthereumKit

final class EthereumChainTests: XCTestCase {

  // MARK: - Mainnet

  func testMainnetChainId() {
    let chain = EvmChain.mainnet
    XCTAssertEqual(chain.chainId, 1)
  }

  func testMainnetName() {
    let chain = EvmChain.mainnet
    XCTAssertEqual(chain.name, "Ethereum Mainnet")
  }

  func testMainnetIsNotTestnet() {
    let chain = EvmChain.mainnet
    XCTAssertFalse(chain.isTestnet)
  }

  func testMainnetRpcURL() {
    let chain = EvmChain.mainnet
    XCTAssertTrue(chain.rpcURL.absoluteString.contains("mainnet"))
  }

  func testMainnetId() {
    let chain = EvmChain.mainnet
    XCTAssertEqual(chain.id, "evm:1")
  }

  // MARK: - Sepolia

  func testSepoliaChainId() {
    let chain = EvmChain.sepolia
    XCTAssertEqual(chain.chainId, 11_155_111)
  }

  func testSepoliaName() {
    let chain = EvmChain.sepolia
    XCTAssertEqual(chain.name, "Sepolia")
  }

  func testSepoliaIsTestnet() {
    let chain = EvmChain.sepolia
    XCTAssertTrue(chain.isTestnet)
  }

  func testSepoliaRpcURL() {
    let chain = EvmChain.sepolia
    XCTAssertTrue(chain.rpcURL.absoluteString.contains("sepolia"))
  }

  func testSepoliaId() {
    let chain = EvmChain.sepolia
    XCTAssertEqual(chain.id, "evm:11155111")
  }

  // MARK: - Custom Chain

  func testCustomChain() {
    let rpcURL = URL(string: "https://my-node.example.com")!
    let chain = EvmChain(chainId: 1337, name: "Local", rpcURL: rpcURL, isTestnet: true)

    XCTAssertEqual(chain.chainId, 1337)
    XCTAssertEqual(chain.name, "Local")
    XCTAssertEqual(chain.rpcURL, rpcURL)
    XCTAssertTrue(chain.isTestnet)
    XCTAssertEqual(chain.id, "evm:1337")
  }

  // MARK: - Equality

  func testEqualityWithSameChain() {
    let a = EvmChain.mainnet
    let b = EvmChain.mainnet
    XCTAssertEqual(a, b)
  }

  func testEqualityWithSameChainId() {
    let a = EvmChain.mainnet
    let b = EvmChain(
      chainId: 1, name: "Different Name", rpcURL: URL(string: "https://other.com")!,
      isTestnet: false)
    XCTAssertEqual(a, b)  // Equal by chainId
  }

  func testInequalityWithDifferentChain() {
    let a = EvmChain.mainnet
    let b = EvmChain.sepolia
    XCTAssertNotEqual(a, b)
  }

  // MARK: - Hashable

  func testHashable() {
    let mainnet = EvmChain.mainnet
    let sepolia = EvmChain.sepolia
    let anotherMainnet = EvmChain(
      chainId: 1, name: "ETH", rpcURL: URL(string: "https://x.com")!, isTestnet: false)

    var set = Set<EvmChain>()
    set.insert(mainnet)
    set.insert(sepolia)
    set.insert(anotherMainnet)

    XCTAssertEqual(set.count, 2)
  }

  // MARK: - Chain Protocol Conformance

  func testAssociatedTypes() {
    // Verify associated types compile correctly
    let _: EvmChain.Value.Type = Wei.self
    let _: EvmChain.Address.Type = EthereumAddress.self
  }
}
