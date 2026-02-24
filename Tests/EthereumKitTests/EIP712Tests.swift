//
//  EIP712Tests.swift
//  EthereumKitTests
//
//  Tests for EIP-712 Typed Data Signing
//  Reference: https://eips.ethereum.org/EIPS/eip-712
//

import XCTest

@testable import EthereumKit

final class EIP712Tests: XCTestCase {

  // MARK: - Domain Separator

  func testDomainSeparator() throws {
    let domain = EIP712Domain(
      name: "Ether Mail",
      version: "1",
      chainId: 1,
      verifyingContract: EthereumAddress("0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC")
    )

    let separator = domain.separator()
    XCTAssertEqual(separator.count, 32)

    // Known test vector from EIP-712
    let expected = Data(hex: "f2cee375fa42b42143804025fc449deafd50cc031ca257e0b194a650a912090f")
    XCTAssertEqual(separator, expected)
  }

  func testDomainSeparatorWithSalt() throws {
    let domain = EIP712Domain(
      name: "Test",
      version: "1",
      chainId: 1,
      verifyingContract: nil,
      salt: Data(repeating: 0xab, count: 32)
    )

    let separator = domain.separator()
    XCTAssertEqual(separator.count, 32)
  }

  func testMinimalDomain() throws {
    // Domain with only name
    let domain = EIP712Domain(name: "Minimal")

    let separator = domain.separator()
    XCTAssertEqual(separator.count, 32)
  }

  // MARK: - Type Hash

  func testDomainTypeHash() {
    // EIP712Domain type hash
    let domainTypeHash = EIP712.typeHash(
      "EIP712Domain",
      types: [
        "EIP712Domain": [
          EIP712Type(name: "name", type: "string"),
          EIP712Type(name: "version", type: "string"),
          EIP712Type(name: "chainId", type: "uint256"),
          EIP712Type(name: "verifyingContract", type: "address"),
        ]
      ]
    )

    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    let expected = Data(hex: "8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f")
    XCTAssertEqual(domainTypeHash, expected)
  }

  func testMailTypeHash() {
    let types: [String: [EIP712Type]] = [
      "Mail": [
        EIP712Type(name: "from", type: "Person"),
        EIP712Type(name: "to", type: "Person"),
        EIP712Type(name: "contents", type: "string"),
      ],
      "Person": [
        EIP712Type(name: "name", type: "string"),
        EIP712Type(name: "wallet", type: "address"),
      ],
    ]

    let mailTypeHash = EIP712.typeHash("Mail", types: types)

    // keccak256("Mail(Person from,Person to,string contents)Person(string name,address wallet)")
    let expected = Data(hex: "a0cedeb2dc280ba39b857546d74f5549c3a1d7bdc2dd96bf881f76108e23dac2")
    XCTAssertEqual(mailTypeHash, expected)
  }

  // MARK: - Encode Type

  func testEncodeType() {
    let types: [String: [EIP712Type]] = [
      "Mail": [
        EIP712Type(name: "from", type: "Person"),
        EIP712Type(name: "to", type: "Person"),
        EIP712Type(name: "contents", type: "string"),
      ],
      "Person": [
        EIP712Type(name: "name", type: "string"),
        EIP712Type(name: "wallet", type: "address"),
      ],
    ]

    let encoded = EIP712.encodeType("Mail", types: types)
    XCTAssertEqual(
      encoded, "Mail(Person from,Person to,string contents)Person(string name,address wallet)")
  }

  func testEncodeTypeSimple() {
    let types: [String: [EIP712Type]] = [
      "Person": [
        EIP712Type(name: "name", type: "string"),
        EIP712Type(name: "wallet", type: "address"),
      ]
    ]

    let encoded = EIP712.encodeType("Person", types: types)
    XCTAssertEqual(encoded, "Person(string name,address wallet)")
  }

  // MARK: - Struct Hash

  func testPersonStructHash() throws {
    let types: [String: [EIP712Type]] = [
      "Person": [
        EIP712Type(name: "name", type: "string"),
        EIP712Type(name: "wallet", type: "address"),
      ]
    ]

    let person: [String: EIP712Value] = [
      "name": .string("Cow"),
      "wallet": .address(EthereumAddress("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826")!),
    ]

    let hash = try EIP712.hashStruct("Person", data: person, types: types)
    XCTAssertEqual(hash.count, 32)

    let expected = Data(hex: "fc71e5fa27ff56c350aa531bc129ebdf613b772b6604664f5d8dbe21b85eb0c8")
    XCTAssertEqual(hash, expected)
  }

  // MARK: - Full EIP-712 Hash (Mail Example from EIP-712)

  func testMailTypedDataHash() throws {
    let domain = EIP712Domain(
      name: "Ether Mail",
      version: "1",
      chainId: 1,
      verifyingContract: EthereumAddress("0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC")
    )

    let types: [String: [EIP712Type]] = [
      "Person": [
        EIP712Type(name: "name", type: "string"),
        EIP712Type(name: "wallet", type: "address"),
      ],
      "Mail": [
        EIP712Type(name: "from", type: "Person"),
        EIP712Type(name: "to", type: "Person"),
        EIP712Type(name: "contents", type: "string"),
      ],
    ]

    let message: [String: EIP712Value] = [
      "from": .struct([
        "name": .string("Cow"),
        "wallet": .address(EthereumAddress("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826")!),
      ]),
      "to": .struct([
        "name": .string("Bob"),
        "wallet": .address(EthereumAddress("0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB")!),
      ]),
      "contents": .string("Hello, Bob!"),
    ]

    let typedData = EIP712TypedData(
      types: types,
      primaryType: "Mail",
      domain: domain,
      message: message
    )

    let signHash = try typedData.signHash()
    XCTAssertEqual(signHash.count, 32)

    // Known test vector from EIP-712
    let expected = Data(hex: "be609aee343fb3c4b28e1df9e632fca64fcfaede20f02e86244efddf30957bd2")
    XCTAssertEqual(signHash, expected)
  }

  // MARK: - Sign Typed Data

  func testSignTypedData() throws {
    // Test private key
    let privateKey = Data(hex: "c85ef7d79691fe79573b1a7e708c2e5c5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e")
    let signer = try EthereumSigner(privateKey: privateKey)

    let domain = EIP712Domain(
      name: "Ether Mail",
      version: "1",
      chainId: 1,
      verifyingContract: EthereumAddress("0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC")
    )

    let types: [String: [EIP712Type]] = [
      "Person": [
        EIP712Type(name: "name", type: "string"),
        EIP712Type(name: "wallet", type: "address"),
      ],
      "Mail": [
        EIP712Type(name: "from", type: "Person"),
        EIP712Type(name: "to", type: "Person"),
        EIP712Type(name: "contents", type: "string"),
      ],
    ]

    let message: [String: EIP712Value] = [
      "from": .struct([
        "name": .string("Cow"),
        "wallet": .address(EthereumAddress("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826")!),
      ]),
      "to": .struct([
        "name": .string("Bob"),
        "wallet": .address(EthereumAddress("0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB")!),
      ]),
      "contents": .string("Hello, Bob!"),
    ]

    let typedData = EIP712TypedData(
      types: types,
      primaryType: "Mail",
      domain: domain,
      message: message
    )

    let signature = try signer.signTypedData(typedData)

    XCTAssertEqual(signature.r.count, 32)
    XCTAssertEqual(signature.s.count, 32)
    XCTAssertTrue(signature.v == 27 || signature.v == 28)

    // Verify signature can recover to signer address
    let signHash = try typedData.signHash()
    let recovered = try signature.recoverAddress(from: signHash)
    XCTAssertEqual(recovered, signer.address)
  }

  // MARK: - Permit (ERC-2612)

  func testPermitTypedData() throws {
    let domain = EIP712Domain(
      name: "MyToken",
      version: "1",
      chainId: 1,
      verifyingContract: EthereumAddress("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")
    )

    let types: [String: [EIP712Type]] = [
      "Permit": [
        EIP712Type(name: "owner", type: "address"),
        EIP712Type(name: "spender", type: "address"),
        EIP712Type(name: "value", type: "uint256"),
        EIP712Type(name: "nonce", type: "uint256"),
        EIP712Type(name: "deadline", type: "uint256"),
      ]
    ]

    let message: [String: EIP712Value] = [
      "owner": .address(EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!),
      "spender": .address(EthereumAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")!),
      "value": .uint(Wei("0xde0b6b3a7640000")!),  // 1 token (1e18)
      "nonce": .uint(Wei(0)),
      "deadline": .uint(Wei(1_893_456_000)),
    ]

    let typedData = EIP712TypedData(
      types: types,
      primaryType: "Permit",
      domain: domain,
      message: message
    )

    let signHash = try typedData.signHash()
    XCTAssertEqual(signHash.count, 32)
  }

  // MARK: - Array Types

  func testTypedDataWithArray() throws {
    let domain = EIP712Domain(name: "Test", version: "1", chainId: 1)

    let types: [String: [EIP712Type]] = [
      "Batch": [
        EIP712Type(name: "targets", type: "address[]"),
        EIP712Type(name: "values", type: "uint256[]"),
      ]
    ]

    let message: [String: EIP712Value] = [
      "targets": .array([
        .address(EthereumAddress("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")!),
        .address(EthereumAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")!),
      ]),
      "values": .array([
        .uint(Wei(100)),
        .uint(Wei(200)),
      ]),
    ]

    let typedData = EIP712TypedData(
      types: types,
      primaryType: "Batch",
      domain: domain,
      message: message
    )

    let signHash = try typedData.signHash()
    XCTAssertEqual(signHash.count, 32)
  }

  // MARK: - Bytes Types

  func testTypedDataWithBytes() throws {
    let domain = EIP712Domain(name: "Test", version: "1", chainId: 1)

    let types: [String: [EIP712Type]] = [
      "Data": [
        EIP712Type(name: "hash", type: "bytes32"),
        EIP712Type(name: "payload", type: "bytes"),
      ]
    ]

    let message: [String: EIP712Value] = [
      "hash": .fixedBytes(
        Data(hex: "abababababababababababababababababababababababababababababababab")),
      "payload": .bytes(Data(hex: "1234567890")),
    ]

    let typedData = EIP712TypedData(
      types: types,
      primaryType: "Data",
      domain: domain,
      message: message
    )

    let signHash = try typedData.signHash()
    XCTAssertEqual(signHash.count, 32)
  }

  // MARK: - Bool and Int Types

  func testTypedDataWithBoolAndInt() throws {
    let domain = EIP712Domain(name: "Test", version: "1", chainId: 1)

    let types: [String: [EIP712Type]] = [
      "Order": [
        EIP712Type(name: "active", type: "bool"),
        EIP712Type(name: "amount", type: "uint256"),
        EIP712Type(name: "price", type: "uint128"),
      ]
    ]

    let message: [String: EIP712Value] = [
      "active": .bool(true),
      "amount": .uint(Wei(1000)),
      "price": .uint(Wei(500)),
    ]

    let typedData = EIP712TypedData(
      types: types,
      primaryType: "Order",
      domain: domain,
      message: message
    )

    let signHash = try typedData.signHash()
    XCTAssertEqual(signHash.count, 32)
  }

  // MARK: - Nested Structs

  func testNestedStructs() throws {
    let domain = EIP712Domain(name: "Test", version: "1", chainId: 1)

    let types: [String: [EIP712Type]] = [
      "Inner": [
        EIP712Type(name: "value", type: "uint256")
      ],
      "Middle": [
        EIP712Type(name: "inner", type: "Inner"),
        EIP712Type(name: "name", type: "string"),
      ],
      "Outer": [
        EIP712Type(name: "middle", type: "Middle"),
        EIP712Type(name: "id", type: "uint256"),
      ],
    ]

    let message: [String: EIP712Value] = [
      "middle": .struct([
        "inner": .struct([
          "value": .uint(Wei(42))
        ]),
        "name": .string("test"),
      ]),
      "id": .uint(Wei(1)),
    ]

    let typedData = EIP712TypedData(
      types: types,
      primaryType: "Outer",
      domain: domain,
      message: message
    )

    let signHash = try typedData.signHash()
    XCTAssertEqual(signHash.count, 32)
  }
}
