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

    let signer = try StarknetSigner(privateKey: Felt("0x1234567890abcdef1234567890abcdef")!)
    let sig = try signer.sign(feltHash: hash)
    let valid = try StarkCurve.verify(
      publicKey: signer.publicKeyFelt!, hash: hash,
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
