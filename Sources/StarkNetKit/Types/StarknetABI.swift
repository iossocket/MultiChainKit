//
//  StarknetABI.swift
//  StarknetKit
//
//  Starknet contract ABI JSON types (Codable).
//  Matches the Starknet ABI specification.
//

import Foundation

// MARK: - StarknetABIItem

/// A single entry in a Starknet contract ABI JSON array.
public enum StarknetABIItem: Sendable, Equatable {
  case function(StarknetABIFunction)
  case constructor(StarknetABIConstructor)
  case l1Handler(StarknetABIL1Handler)
  case event(StarknetABIEvent)
  case structDef(StarknetABIStruct)
  case enumDef(StarknetABIEnum)
  case interface(StarknetABIInterface)
  case impl(StarknetABIImpl)
}

// MARK: - Function

public struct StarknetABIFunction: Codable, Sendable, Equatable {
  public let name: String
  public let inputs: [StarknetABIParam]
  public let outputs: [StarknetABIOutput]
  public let stateMutability: String

  enum CodingKeys: String, CodingKey {
    case name, inputs, outputs
    case stateMutability = "state_mutability"
  }
}

// MARK: - Constructor

public struct StarknetABIConstructor: Codable, Sendable, Equatable {
  public let name: String
  public let inputs: [StarknetABIParam]
}

// MARK: - L1 Handler

public struct StarknetABIL1Handler: Codable, Sendable, Equatable {
  public let name: String
  public let inputs: [StarknetABIParam]
  public let outputs: [StarknetABIOutput]
  public let stateMutability: String

  enum CodingKeys: String, CodingKey {
    case name, inputs, outputs
    case stateMutability = "state_mutability"
  }
}

// MARK: - Event

public struct StarknetABIEvent: Codable, Sendable, Equatable {
  public let name: String
  public let kind: String
  public let members: [StarknetABIEventMember]?
  public let variants: [StarknetABIEventVariant]?
}

public struct StarknetABIEventMember: Codable, Sendable, Equatable {
  public let name: String
  public let type: String
  public let kind: String
}

public struct StarknetABIEventVariant: Codable, Sendable, Equatable {
  public let name: String
  public let type: String
  public let kind: String
}

// MARK: - Struct

public struct StarknetABIStruct: Codable, Sendable, Equatable {
  public let name: String
  public let members: [StarknetABIStructMember]
}

public struct StarknetABIStructMember: Codable, Sendable, Equatable {
  public let name: String
  public let type: String
}

// MARK: - Enum

public struct StarknetABIEnum: Codable, Sendable, Equatable {
  public let name: String
  public let variants: [StarknetABIEnumVariant]
}

public struct StarknetABIEnumVariant: Codable, Sendable, Equatable {
  public let name: String
  public let type: String
}

// MARK: - Interface

public struct StarknetABIInterface: Sendable, Equatable {
  public let name: String
  public let items: [StarknetABIItem]
}

// MARK: - Impl

public struct StarknetABIImpl: Codable, Sendable, Equatable {
  public let name: String
  public let interfaceName: String

  enum CodingKeys: String, CodingKey {
    case name
    case interfaceName = "interface_name"
  }
}

// MARK: - Shared Parameter Types

public struct StarknetABIParam: Codable, Sendable, Equatable {
  public let name: String
  public let type: String
}

public struct StarknetABIOutput: Codable, Sendable, Equatable {
  public let type: String
}

// MARK: - StarknetABIItem Codable

extension StarknetABIItem: Codable {
  private enum TypeValue: String, Codable {
    case function
    case constructor
    case l1_handler
    case event
    case `struct`
    case `enum`
    case interface
    case impl
  }

  private enum CodingKeys: String, CodingKey {
    case type
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(TypeValue.self, forKey: .type)
    let single = try decoder.singleValueContainer()
    switch type {
    case .function:
      self = .function(try single.decode(StarknetABIFunction.self))
    case .constructor:
      self = .constructor(try single.decode(StarknetABIConstructor.self))
    case .l1_handler:
      self = .l1Handler(try single.decode(StarknetABIL1Handler.self))
    case .event:
      self = .event(try single.decode(StarknetABIEvent.self))
    case .struct:
      self = .structDef(try single.decode(StarknetABIStruct.self))
    case .enum:
      self = .enumDef(try single.decode(StarknetABIEnum.self))
    case .interface:
      self = .interface(try single.decode(StarknetABIInterface.self))
    case .impl:
      self = .impl(try single.decode(StarknetABIImpl.self))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .function(let f):
      try container.encode(TypeValue.function, forKey: .type)
      try f.encode(to: encoder)
    case .constructor(let c):
      try container.encode(TypeValue.constructor, forKey: .type)
      try c.encode(to: encoder)
    case .l1Handler(let h):
      try container.encode(TypeValue.l1_handler, forKey: .type)
      try h.encode(to: encoder)
    case .event(let e):
      try container.encode(TypeValue.event, forKey: .type)
      try e.encode(to: encoder)
    case .structDef(let s):
      try container.encode(TypeValue.struct, forKey: .type)
      try s.encode(to: encoder)
    case .enumDef(let e):
      try container.encode(TypeValue.enum, forKey: .type)
      try e.encode(to: encoder)
    case .interface(let i):
      try container.encode(TypeValue.interface, forKey: .type)
      try i.encode(to: encoder)
    case .impl(let i):
      try container.encode(TypeValue.impl, forKey: .type)
      try i.encode(to: encoder)
    }
  }
}

// MARK: - StarknetABIInterface Codable

extension StarknetABIInterface: Codable {
  enum CodingKeys: String, CodingKey {
    case name, items
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.name = try container.decode(String.self, forKey: .name)
    self.items = try container.decode([StarknetABIItem].self, forKey: .items)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(items, forKey: .items)
  }
}
