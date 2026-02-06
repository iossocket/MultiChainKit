# MultiChainKit

[![Tests](https://github.com/iossocket/MultiChainKit/actions/workflows/test.yml/badge.svg)](https://github.com/iossocket/MultiChainKit/actions/workflows/test.yml)

Swift SDK for Ethereum and Starknet.

## Why?

Most Swift blockchain SDKs focus on a single chain. If you're building a wallet or dApp that needs to support multiple chains, you end up juggling different libraries with inconsistent APIs. MultiChainKit provides a unified interface so you can work with Ethereum and Starknet using the same patterns.

## Install

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/iossocket/MultiChainKit.git", from: "0.1.0")
]

// Pick what you need
.target(name: "YourApp", dependencies: ["MultiChainKit"])  // everything
.target(name: "YourApp", dependencies: ["EthereumKit"])      // just Ethereum
.target(name: "YourApp", dependencies: ["MultiChainCore"])   // core only
```

Requires iOS 14+ / macOS 12+, Swift 5.10+.

## Usage

### Ethereum Account & Balance

```swift
import EthereumKit

// Account from address (read-only)
let account = EthereumAddress("0x742d35Cc6634C0532925a3b844Bc9e7595f...")!
let readOnly = EthereumAccount(address: account)

// Account from mnemonic or private key (for signing)
let signable = try EthereumSignableAccount(mnemonic: "abandon abandon ...", path: .ethereum)
let address = signable.address.checksummed

// Provider and balance
let provider = EthereumProvider(chain: .sepolia)
let balanceHex: String = try await provider.send(request: signable.balanceRequest())
let wei = Wei(balanceHex) ?? .zero
print("Balance: \(wei.toEtherDecimal()) ETH")
```

### Ethereum Transfer

```swift
import EthereumKit

let provider = EthereumProvider(chain: .sepolia)
let signable = try EthereumSignableAccount(privateKey: privateKeyData)

// Get nonce
let nonceHex: String = try await provider.send(
    request: provider.getTransactionCountRequest(address: signable.address, block: .pending)
)
let nonce = UInt64(nonceHex.dropFirst(2), radix: 16) ?? 0

// Build and sign transaction
var tx = signable.transferTransaction(
    to: EthereumAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")!,
    value: Wei.fromEther(1),
    nonce: nonce,
    maxPriorityFeePerGas: Wei.fromGwei(2),
    maxFeePerGas: Wei.fromGwei(30),
    chainId: 11155111
)
try signable.sign(transaction: &tx)

// Send
guard let rawTx = tx.rawTransaction else { return }
let txHash: String = try await provider.send(request: provider.sendRawTransactionRequest(rawTx))
```

### Message Signing (EIP-191)

```swift
let signature = try signable.signMessage("Hello, Ethereum")
// Recover signer
let recovered = try signable.recoverMessageSigner(message: "Hello, Ethereum", signature: signature)
```

### Contract Calls (ABI)

```swift
import EthereumKit

// Encode function call
let selector = ABIValue.functionSelector("transfer(address,uint256)")
let args: [ABIValue] = [
    .address(EthereumAddress("0x7099...")!),
    .uint256(Wei.fromEther(1))
]
let callData = ABIValue.encodeCall(signature: "transfer(address,uint256)", arguments: args)

// Use as transaction data or with eth_call
```

## Structure

```
MultiChainKit
├── MultiChainCore    # Protocols (Chain, Account, Provider, Signer), BIP39/BIP32
├── EthereumKit       # Ethereum implementation
│   ├── Account      # EthereumAccount, EthereumSignableAccount
│   ├── Contract    # ABI encoding, EthereumContract
│   ├── Crypto       # Keccak256, Secp256k1
│   ├── Extensions   # EIP-712 typed data
│   ├── Provider     # EthereumProvider, JSON-RPC
│   ├── Signer       # EthereumSigner, EthereumSignature
│   ├── Transaction  # EthereumTransaction (EIP-1559), RLP
│   └── Types        # Wei, EthereumAddress, BlockTag, ABI, Events, Receipt
├── StarknetKit      # Starknet (in progress)
└── MultiChainKit    # Unified entry (in progress)
```

## Status

| Chain    | Mainnet | Testnet     |
| -------- | ------- | ----------- |
| Ethereum | ✓       | ✓ (Sepolia) |
| Starknet | —       | —           |

**Ethereum (done):**

- BIP39/BIP32, accounts (read-only + signable)
- EIP-1559 transactions, RLP encoding, signing
- Provider (JSON-RPC), balance/nonce/call/sendRawTransaction
- ABI encode/decode, contract call encoding, events (ABIEvent)
- EIP-712 typed data signing
- EIP-191 personal message signing

**Planned:**

- Starknet implementation
- MultiChainWallet / ChainRegistry
- ERC20 helpers, hardware wallets

## Related

- [web3swift](https://github.com/web3swift-team/web3swift)
- [starknet.swift](https://github.com/software-mansion/starknet.swift)

## License

MIT
