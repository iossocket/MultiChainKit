# MultiChainKit Design

## Overview

Swift SDK for Ethereum and Starknet. One mnemonic, multiple chains, consistent API.

**Stack**: Swift 5.10+, iOS 14+/macOS 12+, async/await

**Not in scope (for now)**: hardware wallets, WebSocket subscriptions, ENS/Starknet ID, multisig

## Modules

```
MultiChainKit
├── MultiChainCore     → protocols, BIP39/32, errors, MockProvider
├── EthereumKit        → secp256k1, RLP, EIP-1559/2930/Legacy, ABI, contracts
├── StarknetKit        → STARK curve, Pedersen/Poseidon, account abstraction, Cairo ABI
└── MultiChainKit      → MultiChainWallet facade
```

Dependencies: BigInt, CryptoSwift, secp256k1.swift, StarknetCryptoSwift

## Core Protocols

### Chain

```swift
protocol Chain: Sendable, Identifiable {
    associatedtype Value: ChainValue      // Wei, Felt
    associatedtype Address: ChainAddress
    associatedtype Transaction: ChainTransaction
    associatedtype Signature: ChainSignature
    associatedtype Receipt: ChainReceipt

    var id: String { get }
    var name: String { get }
    var isTestnet: Bool { get }
}
```

Associated types let each chain define its own concrete types while keeping a unified interface.

### Account

```swift
protocol Account<C>: Sendable where C: Chain {
    var address: C.Address { get }
    func balanceRequest() -> ChainRequest<C, C.Value>
    func nonceRequest() -> ChainRequest<C, UInt64>
}

protocol SignableAccount<C>: Account<C> {
    var signer: S { get }
    func sign(transaction: inout C.Transaction) throws
    func signMessage(_ message: Data) throws -> C.Signature
}

protocol DeployableAccount<C>: SignableAccount<C> {
    var isDeployed: Bool { get async throws }
    func deployRequest() throws -> ChainRequest<C, C.Receipt>
}
```

Three levels:

- `Account` — read-only, for watch-only wallets
- `SignableAccount` — can sign
- `DeployableAccount` — for Starknet where accounts need deployment

### Signer

```swift
protocol Signer<C>: Sendable where C: Chain {
    var publicKey: Data { get }
    func sign(hash: Data) throws -> C.Signature
}
```

Separate from Account so you can swap implementations (hardware wallet, remote signer, mock for tests).

### Provider

```swift
struct ChainRequest<C: Chain, Result: Decodable>: Sendable {
    let method: String
    let params: [any Encodable & Sendable]
}

protocol Provider<C>: Sendable where C: Chain {
    var chain: C { get }
    func send<R: Decodable>(request: ChainRequest<C, R>) async throws -> R
    func send<R: Decodable>(requests: [ChainRequest<C, R>]) async throws -> [Result<R, ProviderError>]
}
```

Requests are value types — create them without executing, batch them, inspect them. Request building is separated into `EthereumRequestBuilder` and `StarknetRequestBuilder` (static enums), keeping Provider focused on transport.

## Ethereum

### Types

| Type                  | What it is                                              |
| --------------------- | ------------------------------------------------------- |
| `EvmChain`            | Chain definition (chainId, name, rpcURL, symbol, etc.)  |
| `Wei`                 | 256-bit value, converts to/from Gwei/Ether              |
| `EthereumAddress`     | 20 bytes, EIP-55 checksum                               |
| `EthereumTransaction` | Legacy (Type 0), EIP-2930 (Type 1), EIP-1559 (Type 2)  |
| `EthereumSignature`   | r, s, v                                                 |
| `EthereumReceipt`     | Transaction receipt with status, logs, gas used          |

### Predefined Chains

| Static property | Chain           | chainId    | Symbol |
| --------------- | --------------- | ---------- | ------ |
| `.mainnet`      | Ethereum        | 1          | ETH    |
| `.sepolia`      | Sepolia testnet | 11155111   | ETH    |
| `.anvil`        | Local Anvil     | 31337      | ETH    |
| `.bsc`          | BNB Smart Chain | 56         | BNB    |
| `.polygon`      | Polygon         | 137        | POL    |
| `.arbitrumOne`  | Arbitrum One    | 42161      | ETH    |
| `.base`         | Base            | 8453       | ETH    |

Custom chains: `EvmChain(chainId:name:rpcURL:isTestnet:symbol:decimals:explorerURL:)`.

### Crypto

- Curve: secp256k1
- Hash: Keccak-256
- Address: last 20 bytes of keccak256(pubkey)
- Encoding: RLP

### ABI System

- `ABIValue` — enum for all Solidity types (uint, int, address, bool, bytes, string, array, tuple)
- `ABIType` — type parsing from strings
- `ABIEvent` — event encoding/decoding with topic filtering
- Encoding/decoding follows Solidity ABI specification

### Contract

`EthereumContract` wraps an address + ABI + provider:

- `read` / `readSingle` — eth_call with decoded return values
- `encodeWrite` — encode function call data for manual transaction building
- `write` — encode + auto nonce/gas + sign + broadcast (convenience)
- `estimateGas` — eth_estimateGas for a function call
- `getLogs` — fetch and decode event logs

### Account Convenience Layer

`EthereumSignableAccount` accepts an optional `provider` at init. When attached:

- `prepareTransaction(to:value:data:)` — auto-fills nonce, gas limit, and EIP-1559 fee parameters
- `sendTransaction(to:value:data:)` — prepare + sign + broadcast, returns tx hash

### Transaction flow

```
Manual:
1. Build tx (to, value, data, nonce, gas)
2. RLP encode → keccak256 → ECDSA sign
3. RLP encode signed tx → eth_sendRawTransaction

Convenience:
1. sendTransaction(to:value:data:) — handles everything
2. waitForTransaction(hash:) — polls until confirmed
```

## Starknet

### Types

| Type                  | What it is                                                |
| --------------------- | --------------------------------------------------------- |
| `Starknet`            | Chain definition (chainId as Felt, name, rpcURL, etc.)    |
| `Felt`                | Field element (< 2^251 + 17*2^192 + 1)                   |
| `StarknetAddress`     | Contract address (felt), checksummed hex                  |
| `StarknetInvokeV1`    | Invoke transaction (Pedersen hash)                        |
| `StarknetInvokeV3`    | Invoke transaction (Poseidon hash, resource bounds)       |
| `StarknetSignature`   | [r, s] felts                                              |
| `StarknetReceipt`     | Receipt with status, events, fee, messages                |
| `CairoValue`          | Enum for all Cairo types with encode/decode               |
| `CairoType`           | Type parsing from ABI strings                             |

### Crypto

- Curve: STARK curve (via StarknetCryptoSwift Rust FFI)
- Hash: Pedersen (address, V1 tx), Poseidon (V3 tx, SNIP-12 v1)
- Address: pedersen(prefix, deployer, salt, classHash, pedersen(calldata)) mod 2^251
- FFI endianness: StarknetCryptoSwift uses little-endian 32-byte Data

### Account types

Starknet has native account abstraction — accounts are contracts.

```swift
protocol StarknetAccountType: Sendable {
    var classHash: Felt { get }
    func constructorCalldata(publicKey: Felt) -> [Felt]
    func computeAddress(publicKey: Felt, salt: Felt, deployerAddress: Felt) throws -> StarknetAddress
}
```

Implemented: `OpenZeppelinAccount`. Others (Argent, Braavos) can be added by conforming to the protocol.

### Cairo ABI System

- `StarknetABIItem` — Codable enum (function, constructor, l1Handler, event, structDef, enumDef, interface, impl)
- `StarknetContract` pre-indexes functions/events/structs/enums at init
- `CairoType.parse(_:structs:enums:)` — converts ABI type strings (e.g. "core::integer::u256") to CairoType
- `CairoValue.encode()` / `decode()` — fully implemented for all types
- `CairoByteArray` — 31-byte chunks, big-endian byte packing per word

### Contract

`StarknetContract` wraps an address + ABI + provider:

- `read` / `readRaw` — starknet_call with decoded CairoValue or raw Felt results
- `encodeCall` — build StarknetCall for manual transaction building
- `write` — encode + auto nonce/fee + sign + broadcast (convenience)
- `estimateFee` — fee estimation for a function call
- `getEvents` / `decodeEvent` — fetch and decode events

### Account Convenience Layer

`StarknetAccount` accepts an optional `provider` at init. When attached:

- `executeV3(calls:feeMultiplier:)` — auto nonce + fee estimation + sign + broadcast
- `estimateFee(calls:nonce:)` — fee estimation for a set of calls
- `execute(calls:resourceBounds:nonce:)` — sign + broadcast with explicit parameters

### SNIP-12 Typed Data

Starknet's equivalent of EIP-712. Two revisions:

- **v0**: Pedersen hash, domain type `StarkNetDomain`
- **v1**: Poseidon hash, domain type `StarknetDomain`

### Key differences from Ethereum

|                      | Ethereum         | Starknet                     |
| -------------------- | ---------------- | ---------------------------- |
| Account              | EOA              | Contract                     |
| Signature validation | Protocol         | Contract                     |
| Address              | From pubkey      | From deploy params           |
| Tx types             | Legacy/2930/1559 | Invoke/DeployAccount/Declare |
| Gas                  | Single           | L1 + L2 + L1 data           |
| Value                | uint256          | felt252                      |
| ABI                  | Solidity ABI     | Cairo ABI                    |

### Transaction flow

```
Manual:
1. Build tx (encode calls, get nonce, estimate fee, set resource bounds)
2. Poseidon hash → ECDSA sign on STARK curve
3. starknet_addInvokeTransaction

Convenience:
1. executeV3(calls:) — handles everything
2. waitForTransaction(hash:) — polls until accepted
```

## Shared: BIP39/BIP32

```swift
// Mnemonic
BIP39.generateMnemonic(strength: 128) // 12 words
BIP39.seed(from: mnemonic, password: "")
BIP39.validate(mnemonic)

// Derivation
DerivationPath.ethereum  // m/44'/60'/0'/0/0
DerivationPath.starknet  // m/44'/9004'/0'/0/0
BIP32.derive(seed: seed, path: path)
```

## Usage

### Direct (recommended for production)

```swift
// Ethereum — with provider for convenience methods
let provider = EthereumProvider(chain: .sepolia)
let signable = try EthereumSignableAccount(mnemonic: mnemonic, path: .ethereum, provider: provider)
let txHash = try await signable.sendTransaction(to: recipient, value: Wei.fromEther(1))
let receipt = try await provider.waitForTransaction(hash: txHash)

// Starknet — with provider for convenience methods
let provider = StarknetProvider(chain: .sepolia)
let signer = try StarknetSigner(mnemonic: mnemonic, path: .starknet)
let address = try OpenZeppelinAccount().computeAddress(publicKey: signer.publicKeyFelt!, salt: signer.publicKeyFelt!)
let account = StarknetAccount(signer: signer, address: address, chain: .sepolia, provider: provider)
let response = try await account.executeV3(calls: [call])
let receipt = try await provider.waitForTransaction(hash: response.transactionHashFelt)
```

### Convenience (for simple apps)

```swift
var wallet = try MultiChainWallet(mnemonic: mnemonic)
try wallet.connectEthereum(provider: EthereumProvider(chain: .sepolia))
wallet.connectStarknet(provider: StarknetProvider(chain: .sepolia))
```

## RequestBuilder Pattern

RPC request construction is separated from the Provider into static builder enums:

- `EthereumRequestBuilder` — all Ethereum JSON-RPC methods (eth_call, eth_getBalance, eth_sendRawTransaction, etc.)
- `StarknetRequestBuilder` — all Starknet JSON-RPC methods (starknet_call, starknet_getNonce, starknet_addInvokeTransaction, etc.)

This keeps Provider focused on transport (HTTP, URLSession) while request building is stateless and testable.

## Security

- Private keys in memory only, never persisted
- Signing happens locally
- HTTPS required for RPC
- Apps should use Keychain for mnemonic storage

## Testing

380+ tests across 4 test targets, using Swift Testing (`@Test`, `#expect`). Ethereum tests use XCTest.

Standard test vectors:

- BIP39: trezor/python-mnemonic
- BIP32: bitcoin/bips
- Ethereum: ethereum/tests
- Starknet: starkware-libs/starknet-specs

`MockProvider<C>` in MultiChainCore enables deterministic testing without network access.

## References

**Ethereum**: EIP-155, EIP-191, EIP-712, EIP-1559, EIP-2718, EIP-2930, BIP-32/39/44

**Starknet**: [docs.starknet.io](https://docs.starknet.io) — transactions, STARK curve, Pedersen hash, Poseidon hash, account abstraction, SNIP-12

**Libraries**: web3swift, starknet.swift, BigInt, CryptoSwift, secp256k1.swift, StarknetCryptoSwift
