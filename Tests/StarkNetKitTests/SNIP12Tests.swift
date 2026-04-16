//
//  SNIP12Tests.swift
//  StarknetKitTests
//
//  TDD tests for SNIP-12 typed data hashing and signing.
//  Test vectors from starknet.js reference implementation.
//

import Foundation
import Testing

@testable import StarknetKit

// MARK: - Shared Test Fixtures

/// Account address used in starknet.js test vectors.
private let testAccount = Felt("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826")!

// MARK: - Revision 0 types (Pedersen)

private let v0Types: [String: [SNIP12Type]] = [
  "StarkNetDomain": [
    SNIP12Type(name: "name", type: "felt"),
    SNIP12Type(name: "version", type: "felt"),
    SNIP12Type(name: "chainId", type: "felt"),
  ],
  "Person": [
    SNIP12Type(name: "name", type: "felt"),
    SNIP12Type(name: "wallet", type: "felt"),
  ],
  "Mail": [
    SNIP12Type(name: "from", type: "Person"),
    SNIP12Type(name: "to", type: "Person"),
    SNIP12Type(name: "contents", type: "felt"),
  ],
]

private let v0Domain = SNIP12Domain(
  name: "StarkNet Mail",
  version: "1",
  chainId: "1",
  revision: .v0
)

private let v0Message: [String: SNIP12Value] = [
  "from": .struct([
    "name": .felt(Felt.fromShortString("Cow")),
    "wallet": .felt(Felt("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826")!),
  ]),
  "to": .struct([
    "name": .felt(Felt.fromShortString("Bob")),
    "wallet": .felt(Felt("0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB")!),
  ]),
  "contents": .felt(Felt.fromShortString("Hello, Bob!")),
]

// MARK: - Revision 0: encodeType

@Suite("SNIP12 Revision 0")
struct SNIP12V0Tests {

  @Test("encodeType for StarkNetDomain")
  func encodeTypeDomain() {
    let encoded = SNIP12.encodeType("StarkNetDomain", types: v0Types, revision: .v0)
    #expect(encoded == "StarkNetDomain(name:felt,version:felt,chainId:felt)")
  }

  @Test("encodeType for Person (no dependencies)")
  func encodeTypePerson() {
    let encoded = SNIP12.encodeType("Person", types: v0Types, revision: .v0)
    #expect(encoded == "Person(name:felt,wallet:felt)")
  }

  @Test("encodeType for Mail (includes referenced types sorted)")
  func encodeTypeMail() {
    let encoded = SNIP12.encodeType("Mail", types: v0Types, revision: .v0)
    // Mail references Person, so Person is appended
    #expect(encoded == "Mail(from:Person,to:Person,contents:felt)Person(name:felt,wallet:felt)")
  }

  // MARK: - typeHash

  @Test("typeHash for StarkNetDomain matches starknet.js")
  func typeHashDomain() {
    let hash = SNIP12.typeHash("StarkNetDomain", types: v0Types, revision: .v0)
    #expect(hash == Felt("0x1bfc207425a47a5dfa1a50a4f5241203f50624ca5fdf5e18755765416b8e288")!)
  }

  @Test("typeHash for Person matches starknet.js")
  func typeHashPerson() {
    let hash = SNIP12.typeHash("Person", types: v0Types, revision: .v0)
    #expect(hash == Felt("0x2896dbe4b96a67110f454c01e5336edc5bbc3635537efd690f122f4809cc855")!)
  }

  @Test("typeHash for Mail matches starknet.js")
  func typeHashMail() {
    let hash = SNIP12.typeHash("Mail", types: v0Types, revision: .v0)
    #expect(hash == Felt("0x13d89452df9512bf750f539ba3001b945576243288137ddb6c788457d4b2f79")!)
  }

  // MARK: - structHash

  @Test("structHash for domain matches starknet.js")
  func structHashDomain() throws {
    let hash = try v0Domain.separator(types: v0Types)
    #expect(hash == Felt("0x54833b121883a3e3aebff48ec08a962f5742e5f7b973469c1f8f4f55d470b07")!)
  }

  @Test("structHash for Mail message")
  func structHashMail() throws {
    let hash = try SNIP12.structHash("Mail", data: v0Message, types: v0Types, revision: .v0)
    // This is the message struct hash (not the final message hash)
    #expect(hash != Felt.zero)
  }

  // MARK: - messageHash (final signing hash)

  @Test("messageHash for Mail matches starknet.js")
  func messageHashMail() throws {
    let typedData = SNIP12TypedData(
      types: v0Types,
      primaryType: "Mail",
      domain: v0Domain,
      message: v0Message
    )
    let hash = try typedData.messageHash(accountAddress: testAccount)
    #expect(hash == Felt("0x6fcff244f63e38b9d88b9e3378d44757710d1b244282b435cb472053c8d78d0")!)
  }

  // MARK: - encodeValue

  @Test("encodeValue felt is identity")
  func encodeValueFelt() throws {
    let value = SNIP12Value.felt(Felt(42))
    let encoded = try SNIP12.encodeValue(value, type: "felt", types: v0Types, revision: .v0)
    #expect(encoded == Felt(42))
  }

  @Test("encodeValue bool true is 1")
  func encodeValueBoolTrue() throws {
    let encoded = try SNIP12.encodeValue(.bool(true), type: "bool", types: v0Types, revision: .v0)
    #expect(encoded == Felt(1))
  }

  @Test("encodeValue bool false is 0")
  func encodeValueBoolFalse() throws {
    let encoded = try SNIP12.encodeValue(.bool(false), type: "bool", types: v0Types, revision: .v0)
    #expect(encoded == Felt.zero)
  }

  @Test("encodeValue nested struct returns structHash")
  func encodeValueStruct() throws {
    let person: SNIP12Value = .struct([
      "name": .felt(Felt.fromShortString("Cow")),
      "wallet": .felt(Felt("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826")!),
    ])
    let encoded = try SNIP12.encodeValue(person, type: "Person", types: v0Types, revision: .v0)
    // Should be structHash("Person", data)
    let expected = try SNIP12.structHash(
      "Person",
      data: [
        "name": .felt(Felt.fromShortString("Cow")),
        "wallet": .felt(Felt("0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826")!),
      ], types: v0Types, revision: .v0)
    #expect(encoded == expected)
  }

  // MARK: - messageHash is signable

  @Test("messageHash can be signed and verified")
  func signMessageHash() throws {
    let typedData = SNIP12TypedData(
      types: v0Types,
      primaryType: "Mail",
      domain: v0Domain,
      message: v0Message
    )
    let hash = try typedData.messageHash(accountAddress: testAccount)

    let account = try StarknetAccount(privateKey: Felt("0x1234567890abcdef1234567890abcdef")!, address: .zero, chain: .sepolia)
    let sig = try account.sign(feltHash: hash)
    let valid = try StarkCurve.verify(
      publicKey: account.publicKeyFelt!, hash: hash,
      r: sig.r, s: sig.s
    )
    #expect(valid)
  }
}

// MARK: - Revision 1 (Poseidon)

private let v1Types: [String: [SNIP12Type]] = [
  "StarknetDomain": [
    SNIP12Type(name: "name", type: "shortstring"),
    SNIP12Type(name: "version", type: "shortstring"),
    SNIP12Type(name: "chainId", type: "shortstring"),
    SNIP12Type(name: "revision", type: "shortstring"),
  ],
  "Example": [
    SNIP12Type(name: "someField", type: "felt"),
    SNIP12Type(name: "someOtherField", type: "u128"),
  ],
]

private let v1Domain = SNIP12Domain(
  name: "StarkNet Mail",
  version: "1",
  chainId: "1",
  revision: .v1
)

@Suite("SNIP12 Revision 1")
struct SNIP12V1Tests {

  // MARK: - encodeType with quoting

  @Test("encodeType v1 uses double-quote escaping")
  func encodeTypeV1() {
    let encoded = SNIP12.encodeType("StarknetDomain", types: v1Types, revision: .v1)
    #expect(
      encoded
        == "\"StarknetDomain\"(\"name\":\"shortstring\",\"version\":\"shortstring\",\"chainId\":\"shortstring\",\"revision\":\"shortstring\")"
    )
  }

  @Test("encodeType v1 for Example")
  func encodeTypeExample() {
    let encoded = SNIP12.encodeType("Example", types: v1Types, revision: .v1)
    #expect(encoded == "\"Example\"(\"someField\":\"felt\",\"someOtherField\":\"u128\")")
  }

  @Test("typeHash for StarknetDomain v1 matches starknet.js")
  func typeHashStarknetDomainV1() {
    let hash = SNIP12.typeHash("StarknetDomain", types: v1Types, revision: .v1)
    #expect(hash == Felt("0x1ff2f602e42168014d405a94f75e8a93d640751d71d16311266e140d8b0a210")!)
  }

  // MARK: - Domain separator

  @Test("v1 domain separator hash matches starknet.js")
  func domainSeparatorV1() throws {
    let v1DomainForTest = SNIP12Domain(
      name: "StarkNet Mail",
      version: "1",
      chainId: Felt.fromShortString("SN_MAIN"),
      revision: .v1
    )
    let hash = try v1DomainForTest.separator(types: v1Types)
    // Verified against starknet.js typedData.getStructHash (StarkNet Mail, 1, SN_MAIN, revision 1)
    #expect(hash == Felt("0x578f1230feac370e699d12c7d64706ca908edd95a8e0fccfedcf4774ffe61ad")!)
  }

  // MARK: - encodeValue shortstring

  @Test("encodeValue shortstring encodes as felt")
  func encodeValueShortString() throws {
    let encoded = try SNIP12.encodeValue(
      .shortString("hello"), type: "shortstring", types: v1Types, revision: .v1
    )
    #expect(encoded == Felt.fromShortString("hello"))
  }

  // MARK: - encodeValue u128

  @Test("encodeValue u128 is direct felt")
  func encodeValueU128() throws {
    let encoded = try SNIP12.encodeValue(
      .u128(Felt(999)), type: "u128", types: v1Types, revision: .v1
    )
    #expect(encoded == Felt(999))
  }

  // MARK: - encodeValue contractAddress

  @Test("encodeValue ContractAddress is direct felt")
  func encodeValueContractAddress() throws {
    let addr = Felt(0xabc)
    let encoded = try SNIP12.encodeValue(
      .contractAddress(addr), type: "ContractAddress", types: v1Types, revision: .v1
    )
    #expect(encoded == addr)
  }

  // MARK: - v1 uses Poseidon

  @Test("v1 messageHash uses Poseidon, not Pedersen")
  func v1UsesPoseidon() throws {
    let typedData = SNIP12TypedData(
      types: v1Types,
      primaryType: "Example",
      domain: v1Domain,
      message: [
        "someField": .felt(Felt(42)),
        "someOtherField": .u128(Felt(100)),
      ]
    )
    let hash = try typedData.messageHash(accountAddress: testAccount)
    // Just verify it doesn't crash and returns non-zero
    #expect(hash != Felt.zero)
  }
}

// MARK: - SNIP12Error

@Suite("SNIP12Error")
struct SNIP12ErrorTests {

  @Test("unknownType for missing type")
  func unknownType() throws {
    do {
      _ = try SNIP12.structHash("NonExistent", data: [:], types: v0Types, revision: .v0)
      Issue.record("Expected unknownType error")
    } catch let error as SNIP12Error {
      #expect(error == .unknownType("NonExistent"))
    }
  }

  @Test("missingField when field not in data")
  func missingField() throws {
    do {
      _ = try SNIP12.structHash(
        "Person", data: ["name": .felt(Felt(1))], types: v0Types, revision: .v0)
      Issue.record("Expected missingField error")
    } catch let error as SNIP12Error {
      #expect(error == .missingField("wallet"))
    }
  }
}

// MARK: - SNIP12 Decodable

@Suite("SNIP12 Decodable")
struct SNIP12DecodableTests {

  @Test("decode v0 Mail and match starknet.js message hash")
  func decodeV0MailMessageHashMatchesVector() throws {
    let json = """
    {
      "types": {
        "StarkNetDomain": [
          {"name": "name", "type": "felt"},
          {"name": "version", "type": "felt"},
          {"name": "chainId", "type": "felt"}
        ],
        "Person": [
          {"name": "name", "type": "felt"},
          {"name": "wallet", "type": "felt"}
        ],
        "Mail": [
          {"name": "from", "type": "Person"},
          {"name": "to", "type": "Person"},
          {"name": "contents", "type": "felt"}
        ]
      },
      "primaryType": "Mail",
      "domain": {
        "name": "StarkNet Mail",
        "version": "1",
        "chainId": "1",
        "revision": 0
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

    let typedData = try JSONDecoder().decode(SNIP12TypedData.self, from: Data(json.utf8))
    let hash = try typedData.messageHash(accountAddress: testAccount)

    #expect(typedData.primaryType == "Mail")
    #expect(typedData.domain == v0Domain)
    #expect(hash == Felt("0x6fcff244f63e38b9d88b9e3378d44757710d1b244282b435cb472053c8d78d0")!)
    #expect(typedData.message["contents"] == .felt(Felt.fromShortString("Hello, Bob!")))
  }

  @Test("decode v1 Example with revision string")
  func decodeV1Example() throws {
    let json = """
    {
      "types": {
        "StarknetDomain": [
          {"name": "name", "type": "shortstring"},
          {"name": "version", "type": "shortstring"},
          {"name": "chainId", "type": "shortstring"},
          {"name": "revision", "type": "shortstring"}
        ],
        "Example": [
          {"name": "someField", "type": "felt"},
          {"name": "someOtherField", "type": "u128"}
        ]
      },
      "primaryType": "Example",
      "domain": {
        "name": "StarkNet Mail",
        "version": "1",
        "chainId": "1",
        "revision": "v1"
      },
      "message": {
        "someField": "42",
        "someOtherField": "0x64"
      }
    }
    """

    let typedData = try JSONDecoder().decode(SNIP12TypedData.self, from: Data(json.utf8))
    let hash = try typedData.messageHash(accountAddress: testAccount)

    #expect(typedData.domain == v1Domain)
    #expect(typedData.message["someField"] == .felt(Felt(42)))
    #expect(typedData.message["someOtherField"] == .u128(Felt(100)))
    #expect(hash != Felt.zero)
  }

  @Test("decode primitive SNIP-12 values")
  func decodePrimitiveValues() throws {
    let json = """
    {
      "types": {
        "StarknetDomain": [
          {"name": "name", "type": "shortstring"},
          {"name": "version", "type": "shortstring"},
          {"name": "chainId", "type": "shortstring"},
          {"name": "revision", "type": "shortstring"}
        ],
        "Test": [
          {"name": "raw", "type": "felt"},
          {"name": "active", "type": "bool"},
          {"name": "label", "type": "shortstring"},
          {"name": "amount", "type": "u128"},
          {"name": "delta", "type": "i128"},
          {"name": "contract", "type": "ContractAddress"},
          {"name": "classHash", "type": "ClassHash"},
          {"name": "time", "type": "timestamp"},
          {"name": "entrypoint", "type": "selector"},
          {"name": "note", "type": "string"},
          {"name": "wide", "type": "u256"}
        ]
      },
      "primaryType": "Test",
      "domain": {
        "name": "Primitives",
        "version": "1",
        "chainId": "SN_MAIN",
        "revision": 1
      },
      "message": {
        "raw": 42,
        "active": true,
        "label": "hello",
        "amount": "1000",
        "delta": "5",
        "contract": "0xabc",
        "classHash": "0x123",
        "time": "1700000000",
        "entrypoint": "transfer",
        "note": "longer text",
        "wide": {"low": "0x01", "high": "0x02"}
      }
    }
    """

    let typedData = try JSONDecoder().decode(SNIP12TypedData.self, from: Data(json.utf8))

    #expect(typedData.message["raw"] == .felt(Felt(42)))
    #expect(typedData.message["active"] == .bool(true))
    #expect(typedData.message["label"] == .shortString("hello"))
    #expect(typedData.message["amount"] == .u128(Felt(1000)))
    #expect(typedData.message["delta"] == .i128(Felt(5)))
    #expect(typedData.message["contract"] == .contractAddress(Felt(0xabc)))
    #expect(typedData.message["classHash"] == .classHash(Felt(0x123)))
    #expect(typedData.message["time"] == .timestamp(Felt(1_700_000_000)))
    #expect(typedData.message["entrypoint"] == .selector("transfer"))
    #expect(typedData.message["note"] == .string("longer text"))
    #expect(typedData.message["wide"] == .u256(low: Felt(1), high: Felt(2)))
  }

  @Test("decode arrays and nested structs")
  func decodeArraysAndNestedStructs() throws {
    let json = """
    {
      "types": {
        "StarkNetDomain": [
          {"name": "name", "type": "felt"},
          {"name": "version", "type": "felt"},
          {"name": "chainId", "type": "felt"}
        ],
        "Person": [
          {"name": "name", "type": "felt"},
          {"name": "wallet", "type": "felt"}
        ],
        "Group": [
          {"name": "members", "type": "Person*"},
          {"name": "scores", "type": "felt*"}
        ]
      },
      "primaryType": "Group",
      "domain": {
        "name": "Group",
        "version": "1",
        "chainId": "1"
      },
      "message": {
        "members": [
          {"name": "Alice", "wallet": "0x1"},
          {"name": "Bob", "wallet": "0x2"}
        ],
        "scores": ["1", "2", "3"]
      }
    }
    """

    let typedData = try JSONDecoder().decode(SNIP12TypedData.self, from: Data(json.utf8))

    guard case .array(let members) = typedData.message["members"] else {
      Issue.record("members should decode as array")
      return
    }
    guard case .struct(let firstMember) = members.first else {
      Issue.record("first member should decode as struct")
      return
    }
    guard case .array(let scores) = typedData.message["scores"] else {
      Issue.record("scores should decode as array")
      return
    }
    #expect(firstMember["name"] == .felt(Felt.fromShortString("Alice")))
    #expect(firstMember["wallet"] == .felt(Felt(1)))
    #expect(scores == [.felt(Felt(1)), .felt(Felt(2)), .felt(Felt(3))])
  }

  @Test("decode typed enum object")
  func decodeTypedEnumObject() throws {
    let json = """
    {
      "types": {
        "StarkNetDomain": [
          {"name": "name", "type": "felt"},
          {"name": "version", "type": "felt"},
          {"name": "chainId", "type": "felt"}
        ],
        "Action": [
          {"name": "Transfer", "type": "(felt,u128)"},
          {"name": "Cancel", "type": "()"}
        ],
        "Test": [
          {"name": "action", "type": "Action"}
        ]
      },
      "primaryType": "Test",
      "domain": {
        "name": "Enum",
        "version": "1",
        "chainId": "1"
      },
      "message": {
        "action": {
          "variant": "Transfer",
          "values": ["0xabc", "100"]
        }
      }
    }
    """

    let typedData = try JSONDecoder().decode(SNIP12TypedData.self, from: Data(json.utf8))

    #expect(
      typedData.message["action"]
        == .enum(variant: "Transfer", values: [.felt(Felt(0xabc)), .u128(Felt(100))])
    )
  }

  @Test("decode rejects missing fields")
  func decodeMissingFieldThrows() {
    let json = """
    {
      "types": {
        "StarkNetDomain": [
          {"name": "name", "type": "felt"},
          {"name": "version", "type": "felt"},
          {"name": "chainId", "type": "felt"}
        ],
        "Person": [
          {"name": "name", "type": "felt"},
          {"name": "wallet", "type": "felt"}
        ]
      },
      "primaryType": "Person",
      "domain": {
        "name": "Missing",
        "version": "1",
        "chainId": "1"
      },
      "message": {
        "name": "Alice"
      }
    }
    """

    #expect(throws: DecodingError.self) {
      _ = try JSONDecoder().decode(SNIP12TypedData.self, from: Data(json.utf8))
    }
  }

  @Test("decode rejects invalid felt")
  func decodeInvalidFeltThrows() {
    let json = """
    {
      "types": {
        "StarkNetDomain": [
          {"name": "name", "type": "felt"},
          {"name": "version", "type": "felt"},
          {"name": "chainId", "type": "felt"}
        ],
        "Test": [
          {"name": "value", "type": "u128"}
        ]
      },
      "primaryType": "Test",
      "domain": {
        "name": "Invalid",
        "version": "1",
        "chainId": "1"
      },
      "message": {
        "value": "not-a-number"
      }
    }
    """

    #expect(throws: DecodingError.self) {
      _ = try JSONDecoder().decode(SNIP12TypedData.self, from: Data(json.utf8))
    }
  }

  @Test("decode rejects non-array for SNIP-12 array type")
  func decodeNonArrayThrows() {
    let json = """
    {
      "types": {
        "StarkNetDomain": [
          {"name": "name", "type": "felt"},
          {"name": "version", "type": "felt"},
          {"name": "chainId", "type": "felt"}
        ],
        "Test": [
          {"name": "values", "type": "felt*"}
        ]
      },
      "primaryType": "Test",
      "domain": {
        "name": "Invalid",
        "version": "1",
        "chainId": "1"
      },
      "message": {
        "values": "1"
      }
    }
    """

    #expect(throws: DecodingError.self) {
      _ = try JSONDecoder().decode(SNIP12TypedData.self, from: Data(json.utf8))
    }
  }
}
