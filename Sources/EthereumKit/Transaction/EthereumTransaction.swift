//
//  EthereumTransaction.swift
//  EthereumKit
//
//  Supports Legacy (Type 0), EIP-2930 (Type 1), and EIP-1559 (Type 2) transactions
//

import Foundation
import MultiChainCore

// MARK: - TransactionType

public enum TransactionType: UInt8, Sendable, Equatable {
  case legacy = 0x00      // Type 0: Legacy transaction
  case accessList = 0x01  // Type 1: EIP-2930
  case eip1559 = 0x02     // Type 2: EIP-1559
}

// MARK: - AccessListEntry

public struct AccessListEntry: Sendable, Equatable, Codable {
  public let address: EthereumAddress
  public let storageKeys: [Data]

  public init(address: EthereumAddress, storageKeys: [Data]) {
    self.address = address
    self.storageKeys = storageKeys
  }
}

// MARK: - EthereumTransaction

public struct EthereumTransaction: ChainTransaction, Sendable {
  public typealias C = Ethereum

  // MARK: - Fields

  public let type: TransactionType
  public let chainId: UInt64
  public let nonce: UInt64

  // Legacy/EIP-2930 field
  public let gasPrice: Wei?

  // EIP-1559 fields
  public let maxPriorityFeePerGas: Wei?
  public let maxFeePerGas: Wei?

  // Common fields
  public let gasLimit: UInt64
  public let to: EthereumAddress?
  public let value: Wei
  public let data: Data
  public let accessList: [AccessListEntry]

  public var signature: EthereumSignature?

  // MARK: - EIP-1559 Init (Type 2)

  public init(
    chainId: UInt64,
    nonce: UInt64,
    maxPriorityFeePerGas: Wei,
    maxFeePerGas: Wei,
    gasLimit: UInt64,
    to: EthereumAddress?,
    value: Wei,
    data: Data,
    accessList: [AccessListEntry] = []
  ) {
    self.type = .eip1559
    self.chainId = chainId
    self.nonce = nonce
    self.gasPrice = nil
    self.maxPriorityFeePerGas = maxPriorityFeePerGas
    self.maxFeePerGas = maxFeePerGas
    self.gasLimit = gasLimit
    self.to = to
    self.value = value
    self.data = data
    self.accessList = accessList
  }

  // MARK: - Factory Methods

  /// Create a Legacy transaction (Type 0)
  public static func legacy(
    chainId: UInt64,
    nonce: UInt64,
    gasPrice: Wei,
    gasLimit: UInt64,
    to: EthereumAddress?,
    value: Wei,
    data: Data = Data()
  ) -> EthereumTransaction {
    EthereumTransaction(
      type: .legacy,
      chainId: chainId,
      nonce: nonce,
      gasPrice: gasPrice,
      maxPriorityFeePerGas: nil,
      maxFeePerGas: nil,
      gasLimit: gasLimit,
      to: to,
      value: value,
      data: data,
      accessList: []
    )
  }

  /// Create an EIP-2930 transaction (Type 1)
  public static func eip2930(
    chainId: UInt64,
    nonce: UInt64,
    gasPrice: Wei,
    gasLimit: UInt64,
    to: EthereumAddress?,
    value: Wei,
    data: Data = Data(),
    accessList: [AccessListEntry]
  ) -> EthereumTransaction {
    EthereumTransaction(
      type: .accessList,
      chainId: chainId,
      nonce: nonce,
      gasPrice: gasPrice,
      maxPriorityFeePerGas: nil,
      maxFeePerGas: nil,
      gasLimit: gasLimit,
      to: to,
      value: value,
      data: data,
      accessList: accessList
    )
  }

  /// Create an EIP-1559 transaction (Type 2)
  public static func eip1559(
    chainId: UInt64,
    nonce: UInt64,
    maxPriorityFeePerGas: Wei,
    maxFeePerGas: Wei,
    gasLimit: UInt64,
    to: EthereumAddress?,
    value: Wei,
    data: Data = Data(),
    accessList: [AccessListEntry] = []
  ) -> EthereumTransaction {
    EthereumTransaction(
      chainId: chainId,
      nonce: nonce,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      maxFeePerGas: maxFeePerGas,
      gasLimit: gasLimit,
      to: to,
      value: value,
      data: data,
      accessList: accessList
    )
  }

  // MARK: - Private Init

  private init(
    type: TransactionType,
    chainId: UInt64,
    nonce: UInt64,
    gasPrice: Wei?,
    maxPriorityFeePerGas: Wei?,
    maxFeePerGas: Wei?,
    gasLimit: UInt64,
    to: EthereumAddress?,
    value: Wei,
    data: Data,
    accessList: [AccessListEntry]
  ) {
    self.type = type
    self.chainId = chainId
    self.nonce = nonce
    self.gasPrice = gasPrice
    self.maxPriorityFeePerGas = maxPriorityFeePerGas
    self.maxFeePerGas = maxFeePerGas
    self.gasLimit = gasLimit
    self.to = to
    self.value = value
    self.data = data
    self.accessList = accessList
  }

  // MARK: - ChainTransaction

  public var hash: Data? {
    guard signature != nil else { return nil }
    return Keccak256.hash(encode())
  }

  public func hashForSigning() -> Data {
    Keccak256.hash(encodeUnsigned())
  }

  public func encode() -> Data {
    guard let sig = signature else {
      return encodeUnsigned()
    }

    switch type {
    case .legacy:
      return encodeLegacySigned(sig)
    case .accessList:
      return encodeEIP2930Signed(sig)
    case .eip1559:
      return encodeEIP1559Signed(sig)
    }
  }

  public func encodeUnsigned() -> Data {
    switch type {
    case .legacy:
      return encodeLegacyUnsigned()
    case .accessList:
      return encodeEIP2930Unsigned()
    case .eip1559:
      return encodeEIP1559Unsigned()
    }
  }

  // MARK: - Legacy Encoding (Type 0)

  private func encodeLegacyUnsigned() -> Data {
    // EIP-155: [nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0]
    let fields: [Data] = [
      RLP.encode(nonce),
      RLP.encode(bigInt: (gasPrice ?? .zero).bigEndianData),
      RLP.encode(gasLimit),
      to.map { RLP.encode($0.data) } ?? RLP.encode(Data()),
      RLP.encode(bigInt: value.bigEndianData),
      RLP.encode(data),
      RLP.encode(chainId),
      RLP.encode(Data()),  // 0
      RLP.encode(Data()),  // 0
    ]
    return RLP.encode(list: fields)
  }

  private func encodeLegacySigned(_ sig: EthereumSignature) -> Data {
    // Legacy v = chainId * 2 + 35 + recoveryId
    let recoveryId = UInt64(sig.v % 27)
    let v = chainId * 2 + 35 + recoveryId

    let fields: [Data] = [
      RLP.encode(nonce),
      RLP.encode(bigInt: (gasPrice ?? .zero).bigEndianData),
      RLP.encode(gasLimit),
      to.map { RLP.encode($0.data) } ?? RLP.encode(Data()),
      RLP.encode(bigInt: value.bigEndianData),
      RLP.encode(data),
      RLP.encode(v),
      RLP.encode(bigInt: sig.r),
      RLP.encode(bigInt: sig.s),
    ]
    return RLP.encode(list: fields)
  }

  // MARK: - EIP-2930 Encoding (Type 1)

  private func encodeEIP2930Unsigned() -> Data {
    // [chainId, nonce, gasPrice, gasLimit, to, value, data, accessList]
    let fields: [Data] = [
      RLP.encode(chainId),
      RLP.encode(nonce),
      RLP.encode(bigInt: (gasPrice ?? .zero).bigEndianData),
      RLP.encode(gasLimit),
      to.map { RLP.encode($0.data) } ?? RLP.encode(Data()),
      RLP.encode(bigInt: value.bigEndianData),
      RLP.encode(data),
      encodeAccessList(),
    ]
    return Data([0x01]) + RLP.encode(list: fields)
  }

  private func encodeEIP2930Signed(_ sig: EthereumSignature) -> Data {
    // yParity for EIP-2930: 0 or 1
    let yParity = UInt64(sig.v % 27)

    let fields: [Data] = [
      RLP.encode(chainId),
      RLP.encode(nonce),
      RLP.encode(bigInt: (gasPrice ?? .zero).bigEndianData),
      RLP.encode(gasLimit),
      to.map { RLP.encode($0.data) } ?? RLP.encode(Data()),
      RLP.encode(bigInt: value.bigEndianData),
      RLP.encode(data),
      encodeAccessList(),
      RLP.encode(yParity),
      RLP.encode(bigInt: sig.r),
      RLP.encode(bigInt: sig.s),
    ]
    return Data([0x01]) + RLP.encode(list: fields)
  }

  // MARK: - EIP-1559 Encoding (Type 2)

  private func encodeEIP1559Unsigned() -> Data {
    Data([0x02]) + RLP.encode(list: eip1559BaseFields())
  }

  private func encodeEIP1559Signed(_ sig: EthereumSignature) -> Data {
    var fields = eip1559BaseFields()
    fields.append(RLP.encode(UInt64(sig.v % 27)))  // yParity: 0 or 1
    fields.append(RLP.encode(bigInt: sig.r))
    fields.append(RLP.encode(bigInt: sig.s))

    return Data([0x02]) + RLP.encode(list: fields)
  }

  private func eip1559BaseFields() -> [Data] {
    [
      RLP.encode(chainId),
      RLP.encode(nonce),
      RLP.encode(bigInt: (maxPriorityFeePerGas ?? .zero).bigEndianData),
      RLP.encode(bigInt: (maxFeePerGas ?? .zero).bigEndianData),
      RLP.encode(gasLimit),
      to.map { RLP.encode($0.data) } ?? RLP.encode(Data()),
      RLP.encode(bigInt: value.bigEndianData),
      RLP.encode(data),
      encodeAccessList(),
    ]
  }

  // MARK: - Access List Encoding

  private func encodeAccessList() -> Data {
    let entries = accessList.map { entry -> Data in
      let keys = entry.storageKeys.map { RLP.encode($0) }
      return RLP.encode(list: [
        RLP.encode(entry.address.data),
        RLP.encode(list: keys),
      ])
    }
    return RLP.encode(list: entries)
  }
}

// MARK: - Codable

extension EthereumTransaction: Codable {
  enum CodingKeys: String, CodingKey {
    case type, chainId, nonce, gasPrice
    case maxPriorityFeePerGas, maxFeePerGas
    case gasLimit = "gas"
    case to, value, data = "input", accessList
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Decode type (default to EIP-1559 if not present)
    if let typeHex = try container.decodeIfPresent(String.self, forKey: .type) {
      let typeValue = UInt8(typeHex.dropFirst(2), radix: 16) ?? 2
      self.type = TransactionType(rawValue: typeValue) ?? .eip1559
    } else {
      self.type = .eip1559
    }

    self.chainId = try container.decode(UInt64.self, forKey: .chainId)
    self.nonce = try container.decode(UInt64.self, forKey: .nonce)
    self.gasPrice = try container.decodeIfPresent(Wei.self, forKey: .gasPrice)
    self.maxPriorityFeePerGas = try container.decodeIfPresent(Wei.self, forKey: .maxPriorityFeePerGas)
    self.maxFeePerGas = try container.decodeIfPresent(Wei.self, forKey: .maxFeePerGas)
    self.gasLimit = try container.decode(UInt64.self, forKey: .gasLimit)
    self.to = try container.decodeIfPresent(EthereumAddress.self, forKey: .to)
    self.value = try container.decode(Wei.self, forKey: .value)

    // Decode data from hex string
    if let dataHex = try container.decodeIfPresent(String.self, forKey: .data) {
      self.data = Data(hex: String(dataHex.dropFirst(2)))
    } else {
      self.data = Data()
    }

    self.accessList = try container.decodeIfPresent([AccessListEntry].self, forKey: .accessList) ?? []
    self.signature = nil
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode("0x" + String(format: "%02x", type.rawValue), forKey: .type)
    try container.encode(chainId, forKey: .chainId)
    try container.encode(nonce, forKey: .nonce)

    if let gasPrice = gasPrice {
      try container.encode(gasPrice, forKey: .gasPrice)
    }
    if let maxPriorityFeePerGas = maxPriorityFeePerGas {
      try container.encode(maxPriorityFeePerGas, forKey: .maxPriorityFeePerGas)
    }
    if let maxFeePerGas = maxFeePerGas {
      try container.encode(maxFeePerGas, forKey: .maxFeePerGas)
    }

    try container.encode(gasLimit, forKey: .gasLimit)
    try container.encodeIfPresent(to, forKey: .to)
    try container.encode(value, forKey: .value)
    try container.encode("0x" + data.map { String(format: "%02x", $0) }.joined(), forKey: .data)

    if !accessList.isEmpty {
      try container.encode(accessList, forKey: .accessList)
    }
  }
}
