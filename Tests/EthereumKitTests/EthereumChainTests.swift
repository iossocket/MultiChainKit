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
    let chain = Ethereum.mainnet
    XCTAssertEqual(chain.chainId, 1)
  }

  func testMainnetName() {
    let chain = Ethereum.mainnet
    XCTAssertEqual(chain.name, "Ethereum Mainnet")
  }

  func testMainnetIsNotTestnet() {
    let chain = Ethereum.mainnet
    XCTAssertFalse(chain.isTestnet)
  }

  func testMainnetRpcURL() {
    let chain = Ethereum.mainnet
    XCTAssertTrue(chain.rpcURL.absoluteString.contains("mainnet"))
  }

  func testMainnetId() {
    let chain = Ethereum.mainnet
    XCTAssertEqual(chain.id, "ethereum:1")
  }

  // MARK: - Sepolia

  func testSepoliaChainId() {
    let chain = Ethereum.sepolia
    XCTAssertEqual(chain.chainId, 11_155_111)
  }

  func testSepoliaName() {
    let chain = Ethereum.sepolia
    XCTAssertEqual(chain.name, "Sepolia")
  }

  func testSepoliaIsTestnet() {
    let chain = Ethereum.sepolia
    XCTAssertTrue(chain.isTestnet)
  }

  func testSepoliaRpcURL() {
    let chain = Ethereum.sepolia
    XCTAssertTrue(chain.rpcURL.absoluteString.contains("sepolia"))
  }

  func testSepoliaId() {
    let chain = Ethereum.sepolia
    XCTAssertEqual(chain.id, "ethereum:11155111")
  }

  // MARK: - Custom Chain

  func testCustomChain() {
    let rpcURL = URL(string: "https://my-node.example.com")!
    let chain = Ethereum(chainId: 1337, name: "Local", rpcURL: rpcURL, isTestnet: true)

    XCTAssertEqual(chain.chainId, 1337)
    XCTAssertEqual(chain.name, "Local")
    XCTAssertEqual(chain.rpcURL, rpcURL)
    XCTAssertTrue(chain.isTestnet)
    XCTAssertEqual(chain.id, "ethereum:1337")
  }

  // MARK: - Equality

  func testEqualityWithSameChain() {
    let a = Ethereum.mainnet
    let b = Ethereum.mainnet
    XCTAssertEqual(a, b)
  }

  func testEqualityWithSameChainId() {
    let a = Ethereum.mainnet
    let b = Ethereum(
      chainId: 1, name: "Different Name", rpcURL: URL(string: "https://other.com")!,
      isTestnet: false)
    XCTAssertEqual(a, b)  // Equal by chainId
  }

  func testInequalityWithDifferentChain() {
    let a = Ethereum.mainnet
    let b = Ethereum.sepolia
    XCTAssertNotEqual(a, b)
  }

  // MARK: - Hashable

  func testHashable() {
    let mainnet = Ethereum.mainnet
    let sepolia = Ethereum.sepolia
    let anotherMainnet = Ethereum(
      chainId: 1, name: "ETH", rpcURL: URL(string: "https://x.com")!, isTestnet: false)

    var set = Set<Ethereum>()
    set.insert(mainnet)
    set.insert(sepolia)
    set.insert(anotherMainnet)

    XCTAssertEqual(set.count, 2)
  }

  // MARK: - Chain Protocol Conformance

  func testAssociatedTypes() {
    // Verify associated types compile correctly
    let _: Ethereum.Value.Type = Wei.self
    let _: Ethereum.Address.Type = EthereumAddress.self
  }
}
