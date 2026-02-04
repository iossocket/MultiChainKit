//
//  EthereumTransaction.swift
//  EthereumKit
//
//  EIP-1559 Transaction (Type 2)
//

import Foundation
import MultiChainCore

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

  public let chainId: UInt64
  public let nonce: UInt64
  public let maxPriorityFeePerGas: Wei
  public let maxFeePerGas: Wei
  public let gasLimit: UInt64
  public let to: EthereumAddress?
  public let value: Wei
  public let data: Data
  public let accessList: [AccessListEntry]

  public var signature: EthereumSignature?

  // MARK: - Init

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
    self.chainId = chainId
    self.nonce = nonce
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

    var fields = baseFields()
    fields.append(RLP.encode(UInt64(sig.v % 27)))  // yParity: 0 or 1
    fields.append(RLP.encode(bigInt: sig.r))
    fields.append(RLP.encode(bigInt: sig.s))

    return Data([0x02]) + RLP.encode(list: fields)
  }

  // MARK: - Encoding

  public func encodeUnsigned() -> Data {
    Data([0x02]) + RLP.encode(list: baseFields())
  }

  // MARK: - Private

  private func baseFields() -> [Data] {
    [
      RLP.encode(chainId),
      RLP.encode(nonce),
      RLP.encode(bigInt: maxPriorityFeePerGas.bigEndianData),
      RLP.encode(bigInt: maxFeePerGas.bigEndianData),
      RLP.encode(gasLimit),
      to.map { RLP.encode($0.data) } ?? RLP.encode(Data()),
      RLP.encode(bigInt: value.bigEndianData),
      RLP.encode(data),
      encodeAccessList(),
    ]
  }

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
