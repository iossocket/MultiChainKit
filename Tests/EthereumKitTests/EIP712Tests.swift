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
    let account = try EthereumAccount(privateKey: privateKey)

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

    let signature = try account.signTypedData(typedData)

    XCTAssertEqual(signature.r.count, 32)
    XCTAssertEqual(signature.s.count, 32)
    XCTAssertTrue(signature.v == 27 || signature.v == 28)

    // Verify signature can recover to account address
    let signHash = try typedData.signHash()
    let recovered = try signature.recoverAddress(from: signHash)
    XCTAssertEqual(recovered, account.address)
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

  // MARK: - Decodable Tests

  func testDecodeEIP712TypedData() throws {
    let json = """
    {
      "types": {
        "EIP712Domain": [
          {"name": "name", "type": "string"},
          {"name": "version", "type": "string"},
          {"name": "chainId", "type": "uint256"},
          {"name": "verifyingContract", "type": "address"},
          {"name": "salt", "type": "bytes32"}
        ],
        "Person": [
          {"name": "name", "type": "string"},
          {"name": "wallet", "type": "address"}
        ],
        "Mail": [
          {"name": "from", "type": "Person"},
          {"name": "to", "type": "Person"},
          {"name": "contents", "type": "string"}
        ]
      },
      "primaryType": "Mail",
      "domain": {
        "name": "Ether Mail",
        "version": "1",
        "chainId": "1",
        "verifyingContract": "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC",
        "salt": "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      },
      "message": {
        "from": {
          "name": "Cow",
          "wallet": "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"
        },
        "to": {
          "name": "Bob",
          "wallet": "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"
        },
        "contents": "Hello, Bob!"
      }
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    XCTAssertEqual(typedData.primaryType, "Mail")
    XCTAssertEqual(typedData.domain.name, "Ether Mail")
    XCTAssertEqual(typedData.domain.version, "1")
    XCTAssertEqual(typedData.domain.chainId, 1)
    XCTAssertEqual(typedData.message["contents"], .string("Hello, Bob!"))

    guard case .struct(let from) = typedData.message["from"] else {
      XCTFail("from should be struct"); return
    }
    XCTAssertEqual(from["name"], .string("Cow"))
    guard case .address(let addr) = from["wallet"] else {
      XCTFail("wallet should be address"); return
    }
    XCTAssertEqual(addr.checksummed, "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826")

    guard case .struct(let to) = typedData.message["to"] else {
      XCTFail("to should be struct"); return
    }
    XCTAssertEqual(to["name"], .string("Bob"))
  }

  func testDecodeEIP712Domain() throws {
    let json = """
    {
      "name": "Test",
      "version": "1",
      "chainId": "0x1",
      "verifyingContract": "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC",
      "salt": "0xabababababababababababababababababababababababababababababababab"
    }
    """

    let data = Data(json.utf8)
    let domain = try JSONDecoder().decode(EIP712Domain.self, from: data)

    XCTAssertEqual(domain.name, "Test")
    XCTAssertEqual(domain.version, "1")
    XCTAssertEqual(domain.chainId, 1)
    XCTAssertEqual(domain.verifyingContract?.checksummed, "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC")
    XCTAssertEqual(domain.salt?.count, 32)
  }

  func testDecodeMinimalDomain() throws {
    let json = """
    {
      "name": "Minimal",
      "version": null,
      "chainId": null,
      "verifyingContract": null,
      "salt": null
    }
    """

    let data = Data(json.utf8)
    let domain = try JSONDecoder().decode(EIP712Domain.self, from: data)

    XCTAssertEqual(domain.name, "Minimal")
    XCTAssertNil(domain.version)
    XCTAssertNil(domain.chainId)
    XCTAssertNil(domain.verifyingContract)
    XCTAssertNil(domain.salt)
  }

  func testDecodeEIP712Type() throws {
    let json = """
    {"name": "wallet", "type": "address"}
    """

    let data = Data(json.utf8)
    let type = try JSONDecoder().decode(EIP712Type.self, from: data)

    XCTAssertEqual(type.name, "wallet")
    XCTAssertEqual(type.type, "address")
  }

  // MARK: - Decode Primitive Types

  func testDecodeStringPrimitive() throws {
    let json = """
    {
      "types": {"Test": [{"name": "field", "type": "string"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"field": "hello world"}
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    XCTAssertEqual(typedData.message["field"], .string("hello world"))
  }

  func testDecodeBoolPrimitive() throws {
    let json = """
    {
      "types": {"Test": [{"name": "active", "type": "bool"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"active": true}
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    XCTAssertEqual(typedData.message["active"], .bool(true))
  }

  func testDecodeAddressPrimitive() throws {
    let json = """
    {
      "types": {"Test": [{"name": "addr", "type": "address"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"addr": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"}
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    guard case .address(let addr) = typedData.message["addr"] else {
      XCTFail("Should be address"); return
    }
    XCTAssertEqual(addr.checksummed, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
  }

  func testDecodeUint256() throws {
    let json = """
    {
      "types": {"Test": [{"name": "amount", "type": "uint256"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"amount": "0xde0b6b3a7640000"}
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    guard case .uint(let wei) = typedData.message["amount"] else {
      XCTFail("Should be uint"); return
    }
    XCTAssertEqual(wei.hexString, "0xde0b6b3a7640000")
  }

  func testDecodeUint8() throws {
    let json = """
    {
      "types": {"Test": [{"name": "votes", "type": "uint8"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"votes": "0x05"}
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    guard case .uint(let wei) = typedData.message["votes"] else {
      XCTFail("Should be uint"); return
    }
    XCTAssertEqual(wei.hexString, "0x5")
  }

  func testDecodeInt256() throws {
    let json = """
    {
      "types": {"Test": [{"name": "balance", "type": "int256"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"balance": "0x01"}
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    guard case .int(let wei) = typedData.message["balance"] else {
      XCTFail("Should be int"); return
    }
    XCTAssertEqual(wei.hexString, "0x1")
  }

  func testDecodeBytes() throws {
    let json = """
    {
      "types": {"Test": [{"name": "data", "type": "bytes"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"data": "0x1234567890abcdef"}
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    guard case .bytes(let d) = typedData.message["data"] else {
      XCTFail("Should be bytes"); return
    }
    XCTAssertEqual(d, Data(hex: "1234567890abcdef"))
  }

  func testDecodeFixedBytes() throws {
    let json = """
    {
      "types": {"Test": [{"name": "hash", "type": "bytes32"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"hash": "0xabababababababababababababababababababababababababababababababab"}
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    guard case .fixedBytes(let d) = typedData.message["hash"] else {
      XCTFail("Should be fixedBytes"); return
    }
    XCTAssertEqual(d.count, 32)
  }

  // MARK: - Decode Array Types

  func testDecodeDynamicArray() throws {
    let json = """
    {
      "types": {"Test": [{"name": "addresses", "type": "address[]"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {
        "addresses": [
          "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
          "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
        ]
      }
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    guard case .array(let arr) = typedData.message["addresses"] else {
      XCTFail("Should be array"); return
    }
    XCTAssertEqual(arr.count, 2)
    guard case .address(let addr0) = arr[0] else {
      XCTFail("First should be address"); return
    }
    XCTAssertEqual(addr0.checksummed, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
  }

  func testDecodeFixedArray() throws {
    let json = """
    {
      "types": {"Test": [{"name": "values", "type": "uint256[2]"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"values": ["0x01", "0x02"]}
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    guard case .array(let arr) = typedData.message["values"] else {
      XCTFail("Should be array"); return
    }
    XCTAssertEqual(arr.count, 2)
  }

  func testDecodeNestedArray() throws {
    let json = """
    {
      "types": {"Test": [{"name": "matrix", "type": "uint256[][]"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"matrix": [["0x01", "0x02"], ["0x03"]]}
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    guard case .array(let outer) = typedData.message["matrix"] else {
      XCTFail("Should be array"); return
    }
    XCTAssertEqual(outer.count, 2)
    guard case .array(let inner) = outer[0] else {
      XCTFail("First should be array"); return
    }
    XCTAssertEqual(inner.count, 2)
  }

  // MARK: - Decode Struct Types

  func testDecodeStruct() throws {
    let json = """
    {
      "types": {
        "Person": [
          {"name": "name", "type": "string"},
          {"name": "wallet", "type": "address"}
        ],
        "Test": [
          {"name": "person", "type": "Person"}
        ]
      },
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {
        "person": {
          "name": "Alice",
          "wallet": "0xAaAdEe4fE37aA0277F4f6a0Ee7D52b9b6C7a9D3e"
        }
      }
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    guard case .struct(let person) = typedData.message["person"] else {
      XCTFail("Should be struct"); return
    }
    XCTAssertEqual(person["name"], .string("Alice"))
    guard case .address(let addr) = person["wallet"] else {
      XCTFail("wallet should be address"); return
    }
    XCTAssertEqual(addr.checksummed.lowercased(), "0xaaadee4fe37aa0277f4f6a0ee7d52b9b6c7a9d3e")
  }

  func testDecodeNestedStruct() throws {
    let json = """
    {
      "types": {
        "Inner": [{"name": "value", "type": "uint256"}],
        "Outer": [{"name": "inner", "type": "Inner"}]
      },
      "primaryType": "Outer",
      "domain": {"name": "Test"},
      "message": {"inner": {"value": "0x2a"}}
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    guard case .struct(let outer) = typedData.message["inner"] else {
      XCTFail("Should be struct"); return
    }
    guard case .uint(let wei) = outer["value"] else {
      XCTFail("value should be uint"); return
    }
    XCTAssertEqual(wei.hexString, "0x2a")
  }

  // MARK: - Decode Decimal Wei

  func testDecodeWeiDecimalString() throws {
    let json = """
    {
      "types": {"Test": [{"name": "amount", "type": "uint256"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"amount": "1000000000000000000"}
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    guard case .uint(let wei) = typedData.message["amount"] else {
      XCTFail("Should be uint"); return
    }
    XCTAssertEqual(wei.hexString, "0xde0b6b3a7640000")
  }

  // MARK: - Decode Errors

  func testDecodeMissingField() throws {
    let json = """
    {
      "types": {"Person": [{"name": "name", "type": "string"}, {"name": "wallet", "type": "address"}]},
      "primaryType": "Person",
      "domain": {"name": "Test"},
      "message": {"name": "Alice"}
    }
    """

    let data = Data(json.utf8)

    do {
      _ = try JSONDecoder().decode(EIP712TypedData.self, from: data)
      XCTFail("Should throw missingField error")
    } catch {
      let nsError = error as NSError
      XCTAssertEqual(nsError.domain, NSCocoaErrorDomain)
    }
  }

  func testDecodeInvalidTypeMismatch() throws {
    let json = """
    {
      "types": {"Test": [{"name": "field", "type": "address"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"field": 123}
    }
    """

    let data = Data(json.utf8)

    do {
      _ = try JSONDecoder().decode(EIP712TypedData.self, from: data)
      XCTFail("Should throw typeMismatch error")
    } catch {
      // Expected
    }
  }

  func testDecodeInvalidAddress() throws {
    let json = """
    {
      "types": {"Test": [{"name": "addr", "type": "address"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"addr": "not-an-address"}
    }
    """

    let data = Data(json.utf8)

    do {
      _ = try JSONDecoder().decode(EIP712TypedData.self, from: data)
      XCTFail("Should throw invalidValue error")
    } catch {
      // Expected
    }
  }

  func testDecodeInvalidSaltWrongLength() throws {
    let json = """
    {
      "types": {"Test": [{"name": "field", "type": "string"}]},
      "primaryType": "Test",
      "domain": {
        "name": "Test",
        "salt": "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      },
      "message": {"field": "value"}
    }
    """

    let data = Data(json.utf8)

    do {
      _ = try JSONDecoder().decode(EIP712TypedData.self, from: data)
      XCTFail("Should throw salt length error")
    } catch {
      // Expected - salt should be exactly 32 bytes
    }
  }

  func testDecodeInvalidSaltOddHex() throws {
    let json = """
    {
      "types": {"Test": [{"name": "field", "type": "string"}]},
      "primaryType": "Test",
      "domain": {
        "name": "Test",
        "salt": "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      },
      "message": {"field": "value"}
    }
    """

    let data = Data(json.utf8)

    do {
      _ = try JSONDecoder().decode(EIP712TypedData.self, from: data)
      XCTFail("Should throw odd hex error")
    } catch {
      // Expected
    }
  }

  func testDecodeValidSalt() throws {
    let json = """
    {
      "types": {"Test": [{"name": "field", "type": "string"}]},
      "primaryType": "Test",
      "domain": {
        "name": "Test",
        "salt": "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      },
      "message": {"field": "value"}
    }
    """

    let data = Data(json.utf8)
    let typedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    XCTAssertNotNil(typedData.domain.salt)
    XCTAssertEqual(typedData.domain.salt?.count, 32)
  }

  func testDecodeInvalidChainIdStringThrows() throws {
    let json = """
    {
      "types": {"Test": [{"name": "field", "type": "string"}]},
      "primaryType": "Test",
      "domain": {"name": "Test", "chainId": "not-a-chain-id"},
      "message": {"field": "value"}
    }
    """

    XCTAssertThrowsError(try JSONDecoder().decode(EIP712TypedData.self, from: Data(json.utf8)))
  }

  func testDecodeInvalidChainIdNumberThrows() throws {
    let json = """
    {
      "types": {"Test": [{"name": "field", "type": "string"}]},
      "primaryType": "Test",
      "domain": {"name": "Test", "chainId": 1.5},
      "message": {"field": "value"}
    }
    """

    XCTAssertThrowsError(try JSONDecoder().decode(EIP712TypedData.self, from: Data(json.utf8)))
  }

  func testDecodeFixedBytesShortValueThrows() throws {
    let json = """
    {
      "types": {"Test": [{"name": "selector", "type": "bytes4"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"selector": "0x1234"}
    }
    """

    XCTAssertThrowsError(try JSONDecoder().decode(EIP712TypedData.self, from: Data(json.utf8)))
  }

  func testDecodeInvalidUintBitWidthThrows() throws {
    let json = """
    {
      "types": {"Test": [{"name": "amount", "type": "uint7"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"amount": "0x01"}
    }
    """

    XCTAssertThrowsError(try JSONDecoder().decode(EIP712TypedData.self, from: Data(json.utf8)))
  }

  func testDecodeFractionalNumberThrows() throws {
    let json = """
    {
      "types": {"Test": [{"name": "amount", "type": "uint256"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"amount": 1.5}
    }
    """

    XCTAssertThrowsError(try JSONDecoder().decode(EIP712TypedData.self, from: Data(json.utf8)))
  }

  func testDecodeFixedArrayWrongLengthThrows() throws {
    let json = """
    {
      "types": {"Test": [{"name": "values", "type": "uint256[2]"}]},
      "primaryType": "Test",
      "domain": {"name": "Test"},
      "message": {"values": ["0x01"]}
    }
    """

    XCTAssertThrowsError(try JSONDecoder().decode(EIP712TypedData.self, from: Data(json.utf8)))
  }

  // MARK: - Decode and Sign Hash Roundtrip

  func testDecodeAndSignHashRoundtrip() throws {
    let json = """
    {
      "types": {
        "EIP712Domain": [
          {"name": "name", "type": "string"},
          {"name": "version", "type": "string"},
          {"name": "chainId", "type": "uint256"},
          {"name": "verifyingContract", "type": "address"}
        ],
        "Person": [
          {"name": "name", "type": "string"},
          {"name": "wallet", "type": "address"}
        ],
        "Mail": [
          {"name": "from", "type": "Person"},
          {"name": "to", "type": "Person"},
          {"name": "contents", "type": "string"}
        ]
      },
      "primaryType": "Mail",
      "domain": {
        "name": "Ether Mail",
        "version": "1",
        "chainId": "1",
        "verifyingContract": "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
      },
      "message": {
        "from": {"name": "Cow", "wallet": "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},
        "to": {"name": "Bob", "wallet": "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"},
        "contents": "Hello, Bob!"
      }
    }
    """

    let data = Data(json.utf8)
    let decodedTypedData = try JSONDecoder().decode(EIP712TypedData.self, from: data)

    let signHash = try decodedTypedData.signHash()

    // Also create manually to compare
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

    let manuallyCreated = EIP712TypedData(
      types: types,
      primaryType: "Mail",
      domain: domain,
      message: message
    )

    let manualSignHash = try manuallyCreated.signHash()

    XCTAssertEqual(signHash, manualSignHash)
  }
}
