//
//  ContractTests.swift
//  EthereumKitTests
//
//  Tests for EthereumContract convenience API
//

import Foundation
import XCTest

@testable import EthereumKit

// MARK: - Contract Tests

final class ContractTests: XCTestCase {

  // MARK: - Test Data

  // ERC20 ABI (minimal)
  var erc20ABI: [ABIItem] {
    [
      ABIItem(
        type: .function,
        name: "name",
        inputs: [],
        outputs: [ABIParameter(name: "", type: "string")],
        stateMutability: .view
      ),
      ABIItem(
        type: .function,
        name: "symbol",
        inputs: [],
        outputs: [ABIParameter(name: "", type: "string")],
        stateMutability: .view
      ),
      ABIItem(
        type: .function,
        name: "decimals",
        inputs: [],
        outputs: [ABIParameter(name: "", type: "uint8")],
        stateMutability: .view
      ),
      ABIItem(
        type: .function,
        name: "totalSupply",
        inputs: [],
        outputs: [ABIParameter(name: "", type: "uint256")],
        stateMutability: .view
      ),
      ABIItem(
        type: .function,
        name: "balanceOf",
        inputs: [ABIParameter(name: "account", type: "address")],
        outputs: [ABIParameter(name: "", type: "uint256")],
        stateMutability: .view
      ),
      ABIItem(
        type: .function,
        name: "transfer",
        inputs: [
          ABIParameter(name: "to", type: "address"),
          ABIParameter(name: "amount", type: "uint256"),
        ],
        outputs: [ABIParameter(name: "", type: "bool")],
        stateMutability: .nonpayable
      ),
      ABIItem(
        type: .function,
        name: "approve",
        inputs: [
          ABIParameter(name: "spender", type: "address"),
          ABIParameter(name: "amount", type: "uint256"),
        ],
        outputs: [ABIParameter(name: "", type: "bool")],
        stateMutability: .nonpayable
      ),
      ABIItem(
        type: .event,
        name: "Transfer",
        inputs: [
          ABIParameter(name: "from", type: "address", indexed: true),
          ABIParameter(name: "to", type: "address", indexed: true),
          ABIParameter(name: "value", type: "uint256", indexed: false),
        ]
      ),
      ABIItem(
        type: .event,
        name: "Approval",
        inputs: [
          ABIParameter(name: "owner", type: "address", indexed: true),
          ABIParameter(name: "spender", type: "address", indexed: true),
          ABIParameter(name: "value", type: "uint256", indexed: false),
        ]
      ),
    ]
  }

  // MARK: - Encode Write Tests

  func testEncodeTransfer() throws {
    let provider = EthereumProvider(
      chainId: 1,
      name: "Mainnet",
      url: URL(string: "https://eth.example.com")!,
      isTestnet: false
    )

    let contract = EthereumContract(
      address: EthereumAddress("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")!,
      abi: erc20ABI,
      provider: provider
    )

    let to = EthereumAddress("0x1234567890123456789012345678901234567890")!
    let amount = Wei("0x0de0b6b3a7640000")!  // 1e18

    let calldata = try contract.encodeWrite(
      functionName: "transfer",
      args: [.address(to), .uint256(amount)]
    )

    // transfer(address,uint256) selector = 0xa9059cbb
    XCTAssertEqual(calldata.prefix(4).toHexString(), "a9059cbb")
    XCTAssertEqual(calldata.count, 68)  // 4 + 32 + 32
  }

  func testEncodeApprove() throws {
    let provider = EthereumProvider(
      chainId: 1,
      name: "Mainnet",
      url: URL(string: "https://eth.example.com")!,
      isTestnet: false
    )

    let contract = EthereumContract(
      address: EthereumAddress("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")!,
      abi: erc20ABI,
      provider: provider
    )

    let spender = EthereumAddress("0x1234567890123456789012345678901234567890")!
    // Max uint256
    let amount = Wei("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")!

    let calldata = try contract.encodeWrite(
      functionName: "approve",
      args: [.address(spender), .uint256(amount)]
    )

    // approve(address,uint256) selector = 0x095ea7b3
    XCTAssertEqual(calldata.prefix(4).toHexString(), "095ea7b3")
    XCTAssertEqual(calldata.count, 68)
  }

  func testEncodeBalanceOf() throws {
    let provider = EthereumProvider(
      chainId: 1,
      name: "Mainnet",
      url: URL(string: "https://eth.example.com")!,
      isTestnet: false
    )

    let contract = EthereumContract(
      address: EthereumAddress("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")!,
      abi: erc20ABI,
      provider: provider
    )

    let account = EthereumAddress("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")!

    let calldata = try contract.encodeWrite(
      functionName: "balanceOf",
      args: [.address(account)]
    )

    // balanceOf(address) selector = 0x70a08231
    XCTAssertEqual(calldata.prefix(4).toHexString(), "70a08231")
    XCTAssertEqual(calldata.count, 36)  // 4 + 32
  }

  // MARK: - Error Tests

  func testFunctionNotFound() {
    let provider = EthereumProvider(
      chainId: 1,
      name: "Mainnet",
      url: URL(string: "https://eth.example.com")!,
      isTestnet: false
    )

    let contract = EthereumContract(
      address: EthereumAddress("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")!,
      abi: erc20ABI,
      provider: provider
    )

    XCTAssertThrowsError(try contract.encodeWrite(functionName: "nonExistent", args: [])) { error in
      XCTAssertTrue(error is ContractError)
    }
  }

  func testArgumentCountMismatch() {
    let provider = EthereumProvider(
      chainId: 1,
      name: "Mainnet",
      url: URL(string: "https://eth.example.com")!,
      isTestnet: false
    )

    let contract = EthereumContract(
      address: EthereumAddress("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")!,
      abi: erc20ABI,
      provider: provider
    )

    XCTAssertThrowsError(
      try contract.encodeWrite(
        functionName: "transfer",
        args: [.address(EthereumAddress("0x1234567890123456789012345678901234567890")!)]
      )
    ) { error in
      XCTAssertTrue(error is ContractError)
    }
  }

  // MARK: - JSON ABI Tests

  func testInitFromJsonABI() throws {
    let jsonABI = """
      [
        {
          "type": "function",
          "name": "balanceOf",
          "inputs": [{"name": "account", "type": "address"}],
          "outputs": [{"name": "", "type": "uint256"}],
          "stateMutability": "view"
        }
      ]
      """

    let provider = EthereumProvider(
      chainId: 1,
      name: "Mainnet",
      url: URL(string: "https://eth.example.com")!,
      isTestnet: false
    )

    let contract = try EthereumContract(
      address: EthereumAddress("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")!,
      abiJson: jsonABI,
      provider: provider
    )

    XCTAssertEqual(contract.abi.count, 1)
    XCTAssertEqual(contract.abi[0].name, "balanceOf")
  }

  // MARK: - ABIValue Type Conversion Tests

  func testABIValueAsWei() {
    let wei = Wei("0x0de0b6b3a7640000")!
    let value = ABIValue.uint(bits: 256, value: wei)

    let result: Wei? = value.as(Wei.self)
    XCTAssertEqual(result, wei)
  }

  func testABIValueAsBool() {
    let value = ABIValue.bool(true)

    let result: Bool? = value.as(Bool.self)
    XCTAssertEqual(result, true)
  }

  func testABIValueAsString() {
    let value = ABIValue.string("Hello")

    let result: String? = value.as(String.self)
    XCTAssertEqual(result, "Hello")
  }

  func testABIValueAsData() {
    let data = Data([0x01, 0x02, 0x03])
    let value = ABIValue.bytes(data)

    let result: Data? = value.as(Data.self)
    XCTAssertEqual(result, data)
  }

  func testABIValueAsAddressString() {
    let addr = EthereumAddress("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")!
    let value = ABIValue.address(addr)

    let result: String? = value.as(String.self)
    XCTAssertEqual(result, "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
  }

  func testABIValueTypeMismatch() {
    let value = ABIValue.bool(true)

    let result: String? = value.as(String.self)
    XCTAssertNil(result)
  }

  // MARK: - Function Selector Tests

  func testERC20FunctionSelectors() {
    // Verify standard ERC20 function selectors
    let transferSelector = ABIValue.functionSelector("transfer(address,uint256)")
    XCTAssertEqual(transferSelector.toHexString(), "a9059cbb")

    let approveSelector = ABIValue.functionSelector("approve(address,uint256)")
    XCTAssertEqual(approveSelector.toHexString(), "095ea7b3")

    let balanceOfSelector = ABIValue.functionSelector("balanceOf(address)")
    XCTAssertEqual(balanceOfSelector.toHexString(), "70a08231")

    let totalSupplySelector = ABIValue.functionSelector("totalSupply()")
    XCTAssertEqual(totalSupplySelector.toHexString(), "18160ddd")

    let decimalsSelector = ABIValue.functionSelector("decimals()")
    XCTAssertEqual(decimalsSelector.toHexString(), "313ce567")
  }

  // MARK: - ABIItem Signature Tests

  func testABIItemSignature() {
    let transferItem = ABIItem(
      type: .function,
      name: "transfer",
      inputs: [
        ABIParameter(name: "to", type: "address"),
        ABIParameter(name: "amount", type: "uint256"),
      ],
      outputs: [ABIParameter(name: "", type: "bool")]
    )

    XCTAssertEqual(transferItem.signature, "transfer(address,uint256)")
    XCTAssertEqual(transferItem.selector?.toHexString(), "a9059cbb")
  }

  func testABIItemEventTopic() {
    let transferEvent = ABIItem(
      type: .event,
      name: "Transfer",
      inputs: [
        ABIParameter(name: "from", type: "address", indexed: true),
        ABIParameter(name: "to", type: "address", indexed: true),
        ABIParameter(name: "value", type: "uint256", indexed: false),
      ]
    )

    XCTAssertEqual(transferEvent.signature, "Transfer(address,address,uint256)")
    // keccak256("Transfer(address,address,uint256)")
    XCTAssertEqual(
      transferEvent.topic?.toHexString(),
      "ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    )
  }
}
