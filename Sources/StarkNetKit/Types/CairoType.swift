//
//  CairoType.swift
//  StarknetKit
//
//  Cairo ABI type system for Starknet calldata.
//  Cairo serialization is flat (no head/tail dynamic encoding like Solidity).
//  All values are serialized as a sequence of Felt elements.
//

import Foundation

// MARK: - CairoType

/// Represents a Cairo ABI type.
public indirect enum CairoType: Sendable, Equatable {
  /// felt252: single felt
  case felt252

  /// Boolean: 0 or 1
  case bool

  /// Unsigned integers: u8, u16, u32, u64 — single felt
  case u8
  case u16
  case u32
  case u64

  /// u128: single felt (up to 2^128 - 1)
  case u128

  /// u256: struct { low: u128, high: u128 } — 2 felts
  case u256

  /// ContractAddress: single felt
  case contractAddress

  /// ByteArray: [num_full_words, word0..., pending_word, pending_word_len]
  case byteArray

  /// Array<T> / Span<T>: [length, elem0..., elem1..., ...]
  case array(CairoType)

  /// Option<T>: [variant_index, ...value_if_some]
  case option(CairoType)

  /// Tuple / Struct: fields flattened in order
  case tuple([CairoType])

  /// Enum: [variant_index, ...variant_data]
  case `enum`([CairoType])
}

// MARK: - CairoABIError

public enum CairoABIError: Error, Sendable {
  case outOfBounds(expected: Int, available: Int)
  case invalidBool(Felt)
  case invalidByteArray
  case invalidOptionVariant(Felt)
  case typeMismatch(expected: CairoType, got: CairoValue)
  case unknownType(String)
}

// MARK: - CairoType Parsing

extension CairoType {

  private static let builtinTypes: [String: CairoType] = [
    "core::felt252": .felt252,
    "felt252": .felt252,
    "core::bool": .bool,
    "core::integer::u8": .u8,
    "core::integer::u16": .u16,
    "core::integer::u32": .u32,
    "core::integer::u64": .u64,
    "core::integer::u128": .u128,
    "core::integer::u256": .u256,
    "core::starknet::contract_address::ContractAddress": .contractAddress,
    "core::byte_array::ByteArray": .byteArray,
  ]

  /// Parse a Cairo type string from ABI JSON into a CairoType.
  public static func parse(
    _ typeString: String,
    structs: [String: StarknetABIStruct] = [:],
    enums: [String: StarknetABIEnum] = [:]
  ) throws -> CairoType {
    let s = typeString.trimmingCharacters(in: .whitespaces)

    // 1. Builtins
    if let builtin = builtinTypes[s] { return builtin }

    // 2. Unit type
    if s == "()" { return .tuple([]) }

    // 3. Tuple: (T1, T2, ...)
    if s.hasPrefix("(") && s.hasSuffix(")") {
      let inner = String(s.dropFirst().dropLast())
      if inner.isEmpty { return .tuple([]) }
      let components = splitTopLevelCommas(inner)
      let types = try components.map { try parse($0, structs: structs, enums: enums) }
      return .tuple(types)
    }

    // 4. Generic types: Array, Span, Option
    if let (base, typeArg) = parseGeneric(s) {
      switch base {
      case "core::array::Array", "core::array::Span":
        return .array(try parse(typeArg, structs: structs, enums: enums))
      case "core::option::Option":
        return .option(try parse(typeArg, structs: structs, enums: enums))
      default:
        break
      }
    }

    // 5. Struct registry
    if let structDef = structs[s] {
      let fieldTypes = try structDef.members.map {
        try parse($0.type, structs: structs, enums: enums)
      }
      return .tuple(fieldTypes)
    }

    // 6. Enum registry
    if let enumDef = enums[s] {
      let variantTypes = try enumDef.variants.map {
        try parse($0.type, structs: structs, enums: enums)
      }
      return .enum(variantTypes)
    }

    throw CairoABIError.unknownType(s)
  }

  /// Split "Foo::<Bar>" into ("Foo", "Bar"). Returns nil if not generic.
  private static func parseGeneric(_ s: String) -> (String, String)? {
    guard let range = s.range(of: "::<") else { return nil }
    let base = String(s[..<range.lowerBound])
    let rest = String(s[range.upperBound...])
    guard rest.hasSuffix(">") else { return nil }
    let typeArg = String(rest.dropLast())
    return (base, typeArg)
  }

  /// Split comma-separated types respecting nested angle brackets and parens.
  private static func splitTopLevelCommas(_ s: String) -> [String] {
    var components: [String] = []
    var current = ""
    var angleDepth = 0
    var parenDepth = 0

    for char in s {
      if char == "<" { angleDepth += 1 }
      else if char == ">" { angleDepth -= 1 }
      else if char == "(" { parenDepth += 1 }
      else if char == ")" { parenDepth -= 1 }
      else if char == "," && angleDepth == 0 && parenDepth == 0 {
        components.append(current.trimmingCharacters(in: .whitespaces))
        current = ""
        continue
      }
      current.append(char)
    }
    if !current.isEmpty {
      components.append(current.trimmingCharacters(in: .whitespaces))
    }
    return components
  }
}
